package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"go.uber.org/zap"
)

// StreamTranscribeProxy bridges client traffic to DashScope's purpose-built
// streaming ASR (paraformer-realtime-v2). Two surfaces share one upstream
// connection model:
//
//   1. Handle(ctx, conn): proxies a phone-side WebSocket. Wire format
//      with the client is intentionally dumb so mobile code stays tiny:
//        client → server:
//          - binary frame: PCM 16kHz mono 16-bit audio bytes
//          - text  frame "finish": user released the mic; flush + finalize
//        server → client:
//          - text {"partial": "..."} : interim; replace previous
//          - text {"final":   "..."} : finalized
//          - text {"error":   "..."} : terminal; connection closes after
//   2. TranscribeBytes(ctx, audio, format): one-shot synchronous wrapper
//      used by the HTTP /v1/ai/transcribe endpoint — opens an internal WS,
//      streams the bytes in chunks, waits for task-finished, returns final
//      text. Same upstream model, same connection lifecycle, no separate
//      batch implementation. Replaces the old qwen-omni-flash path —
//      paraformer is the dedicated ASR (cheaper, faster, doesn't paraphrase).
//
// The proxy hides our DashScope API key from the phone — otherwise we'd
// need to ship it in the APK or run a token-minting endpoint.
type StreamTranscribeProxy struct {
	logger     *zap.Logger
	apiKey     string
	dashURL    string // override for tests; "" → official endpoint
	model      string // default "paraformer-realtime-v2"
	sampleRate int    // default 16000
}

func NewStreamTranscribeProxy(logger *zap.Logger, apiKey string) *StreamTranscribeProxy {
	return &StreamTranscribeProxy{
		logger:     logger,
		apiKey:     apiKey,
		dashURL:    "wss://dashscope.aliyuncs.com/api-ws/v1/inference",
		model:      "paraformer-realtime-v2",
		sampleRate: 16000,
	}
}

// dashEvent matches DashScope's WebSocket envelope. We only care about a
// few `event` types; the rest we ignore.
type dashEvent struct {
	Header struct {
		Action  string `json:"action"`
		Event   string `json:"event"` // task-started / result-generated / task-finished / task-failed
		TaskID  string `json:"task_id"`
		Code    string `json:"code,omitempty"`
		Message string `json:"message,omitempty"`
	} `json:"header"`
	Payload struct {
		Output struct {
			Sentence struct {
				Text      string `json:"text"`
				BeginTime *int64 `json:"begin_time,omitempty"`
				EndTime   *int64 `json:"end_time,omitempty"`
			} `json:"sentence"`
		} `json:"output"`
	} `json:"payload"`
}

// Handle runs one bridge for one upgraded client connection. It blocks until
// either side closes or errors, then returns.
func (p *StreamTranscribeProxy) Handle(ctx context.Context, client *websocket.Conn) {
	defer client.Close()

	if p.apiKey == "" {
		writeClientError(client, "transcribe stream not configured (no QWEN_API_KEY)")
		return
	}

	dialCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	upstream, _, err := websocket.DefaultDialer.DialContext(dialCtx, p.dashURL, http.Header{
		"Authorization": []string{"bearer " + p.apiKey},
	})
	if err != nil {
		p.logger.Warn("dashscope ws dial failed", zap.Error(err))
		writeClientError(client, "upstream dial failed")
		return
	}
	defer upstream.Close()

	taskID := uuid.NewString()
	if err := upstream.WriteJSON(map[string]any{
		"header": map[string]any{
			"action":    "run-task",
			"task_id":   taskID,
			"streaming": "duplex",
		},
		"payload": map[string]any{
			"task_group": "audio",
			"task":       "asr",
			"function":   "recognition",
			"model":      p.model,
			"parameters": map[string]any{
				"format":      "pcm",
				"sample_rate": p.sampleRate,
			},
			"input": map[string]any{},
		},
	}); err != nil {
		writeClientError(client, "run-task failed")
		return
	}

	// One goroutine pumps client→upstream (audio + finish). Another reads
	// upstream→client (transcription events). Either side closing tears
	// the other down via the context.
	bridgeCtx, bridgeCancel := context.WithCancel(ctx)
	defer bridgeCancel()
	var wg sync.WaitGroup
	wg.Add(2)

	// upstream → client
	go func() {
		defer wg.Done()
		defer bridgeCancel()
		var lastFinalText string
		for {
			if bridgeCtx.Err() != nil {
				return
			}
			_, msg, err := upstream.ReadMessage()
			if err != nil {
				if !isNormalClose(err) {
					p.logger.Warn("upstream read", zap.Error(err))
				}
				return
			}
			var ev dashEvent
			if err := json.Unmarshal(msg, &ev); err != nil {
				continue
			}
			switch ev.Header.Event {
			case "result-generated":
				text := ev.Payload.Output.Sentence.Text
				if text == "" {
					continue
				}
				// DashScope emits partials with end_time=null and finals
				// (per-sentence) with end_time set. We forward both as
				// "partial" so the UI can keep replacing the in-place
				// text; the truly-final result is sent on task-finished
				// using the last text we saw, since paraformer doesn't
				// always emit a separate "final" sentence.
				_ = client.WriteJSON(map[string]string{"partial": text})
				lastFinalText = text
			case "task-finished":
				_ = client.WriteJSON(map[string]string{"final": lastFinalText})
				return
			case "task-failed":
				p.logger.Warn("dashscope task-failed",
					zap.String("code", ev.Header.Code),
					zap.String("message", ev.Header.Message))
				_ = client.WriteJSON(map[string]string{"error": ev.Header.Message})
				return
			}
		}
	}()

	// client → upstream
	go func() {
		defer wg.Done()
		defer bridgeCancel()
		for {
			if bridgeCtx.Err() != nil {
				return
			}
			mt, msg, err := client.ReadMessage()
			if err != nil {
				if !isNormalClose(err) {
					p.logger.Debug("client read", zap.Error(err))
				}
				// Tell upstream we're done so it can flush the last
				// partial and emit task-finished.
				_ = upstream.WriteJSON(map[string]any{
					"header":  map[string]any{"action": "finish-task", "task_id": taskID, "streaming": "duplex"},
					"payload": map[string]any{"input": map[string]any{}},
				})
				return
			}
			switch mt {
			case websocket.BinaryMessage:
				if err := upstream.WriteMessage(websocket.BinaryMessage, msg); err != nil {
					return
				}
			case websocket.TextMessage:
				if string(msg) == "finish" {
					_ = upstream.WriteJSON(map[string]any{
						"header":  map[string]any{"action": "finish-task", "task_id": taskID, "streaming": "duplex"},
						"payload": map[string]any{"input": map[string]any{}},
					})
				}
			}
		}
	}()

	wg.Wait()
}

// TranscribeBytes is the synchronous wrapper. Used by the HTTP transcribe
// endpoint so we don't have to maintain two upstream-protocol implementations.
// Sends the audio in 100ms-ish PCM chunks; for non-PCM formats (aac/mp3/wav)
// upstream handles its own framing as long as `format` matches.
//
// `format` is a paraformer-recognised codec hint: pcm | wav | mp3 | aac |
// opus | speex | amr. Pass the codec, NOT the mime type.
func (p *StreamTranscribeProxy) TranscribeBytes(ctx context.Context, audio []byte, format string) (string, error) {
	if p.apiKey == "" {
		return "", errors.New("transcribe not configured (no QWEN_API_KEY)")
	}
	if format == "" {
		format = "pcm"
	}

	dialCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	upstream, _, err := websocket.DefaultDialer.DialContext(dialCtx, p.dashURL, http.Header{
		"Authorization": []string{"bearer " + p.apiKey},
	})
	if err != nil {
		return "", fmt.Errorf("upstream dial: %w", err)
	}
	defer upstream.Close()

	taskID := uuid.NewString()
	parameters := map[string]any{"format": format}
	// Paraformer needs sample_rate only when format is raw pcm/wav.
	if format == "pcm" || format == "wav" {
		parameters["sample_rate"] = p.sampleRate
	}
	if err := upstream.WriteJSON(map[string]any{
		"header": map[string]any{
			"action":    "run-task",
			"task_id":   taskID,
			"streaming": "duplex",
		},
		"payload": map[string]any{
			"task_group": "audio",
			"task":       "asr",
			"function":   "recognition",
			"model":      p.model,
			"parameters": parameters,
			"input":      map[string]any{},
		},
	}); err != nil {
		return "", err
	}

	// Wait for task-started before pushing audio (the protocol drops
	// frames received before the model is ready).
	if err := waitFor(upstream, "task-started", 5*time.Second); err != nil {
		return "", err
	}

	// Push audio in 100ms chunks for PCM (3200B per chunk @ 16kHz mono),
	// or just a single shot for compressed codecs where chunk boundaries
	// can mid-frame the decoder.
	var chunkSize int
	if format == "pcm" {
		chunkSize = p.sampleRate * 2 / 10
	} else {
		chunkSize = len(audio) // one shot for codec-framed inputs
	}
	for i := 0; i < len(audio); i += chunkSize {
		end := i + chunkSize
		if end > len(audio) {
			end = len(audio)
		}
		if err := upstream.WriteMessage(websocket.BinaryMessage, audio[i:end]); err != nil {
			return "", err
		}
	}
	if err := upstream.WriteJSON(map[string]any{
		"header":  map[string]any{"action": "finish-task", "task_id": taskID, "streaming": "duplex"},
		"payload": map[string]any{"input": map[string]any{}},
	}); err != nil {
		return "", err
	}

	// Drain events until task-finished, keeping the latest text.
	deadline := time.Now().Add(30 * time.Second)
	_ = upstream.SetReadDeadline(deadline)
	var lastText string
	for {
		_, msg, err := upstream.ReadMessage()
		if err != nil {
			return strings.TrimSpace(lastText), err
		}
		var ev dashEvent
		if err := json.Unmarshal(msg, &ev); err != nil {
			continue
		}
		switch ev.Header.Event {
		case "result-generated":
			if t := ev.Payload.Output.Sentence.Text; t != "" {
				lastText = t
			}
		case "task-finished":
			return strings.TrimSpace(lastText), nil
		case "task-failed":
			return "", fmt.Errorf("paraformer: %s", ev.Header.Message)
		}
	}
}

func waitFor(c *websocket.Conn, event string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	_ = c.SetReadDeadline(deadline)
	defer c.SetReadDeadline(time.Time{})
	for {
		_, msg, err := c.ReadMessage()
		if err != nil {
			return err
		}
		var ev dashEvent
		if err := json.Unmarshal(msg, &ev); err == nil && ev.Header.Event == event {
			return nil
		}
	}
}

func writeClientError(c *websocket.Conn, msg string) {
	_ = c.WriteJSON(map[string]string{"error": msg})
}

func isNormalClose(err error) bool {
	if err == nil {
		return true
	}
	var ce *websocket.CloseError
	if errors.As(err, &ce) {
		return ce.Code == websocket.CloseNormalClosure || ce.Code == websocket.CloseGoingAway
	}
	if errors.Is(err, context.Canceled) {
		return true
	}
	// Common transient transport hangups when client app backgrounds.
	return fmt.Sprintf("%T", err) == "*net.OpError"
}
