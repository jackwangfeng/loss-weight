package handlers

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
)

// Mobile 客户端用任意 origin，beta 阶段 allow all。
var wsUpgrader = websocket.Upgrader{
	ReadBufferSize:  2048,
	WriteBufferSize: 2048,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

// bindAudioRequest accepts either:
//   - application/json with {audio_base64, mime_type, locale}
//   - multipart/form-data with "audio" file + optional "mime_type" / "locale"
//
// multipart 省掉客户端 base64 编码 + 33% 线上字节。Gemini 侧还是要
// base64（inline_data 要求），但那是 AWS→Google 的快网段。
func bindAudioRequest(c *gin.Context) (*services.TranscribeRequest, error) {
	ct := c.ContentType()
	if strings.HasPrefix(ct, "multipart/") {
		fh, err := c.FormFile("audio")
		if err != nil {
			return nil, fmt.Errorf("missing 'audio' file: %w", err)
		}
		f, err := fh.Open()
		if err != nil {
			return nil, fmt.Errorf("open audio: %w", err)
		}
		defer f.Close()
		raw, err := io.ReadAll(f)
		if err != nil {
			return nil, fmt.Errorf("read audio: %w", err)
		}
		req := &services.TranscribeRequest{
			AudioBase64: base64.StdEncoding.EncodeToString(raw),
			MimeType:    c.PostForm("mime_type"),
			Locale:      c.PostForm("locale"),
		}
		if req.MimeType == "" {
			req.MimeType = "audio/mp4"
		}
		return req, nil
	}
	var req services.TranscribeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		return nil, err
	}
	return &req, nil
}

type AIHandler struct {
	service *services.AIService
	quota   *services.QuotaTracker
	logger  *zap.Logger
}

func NewAIHandler(service *services.AIService, quota *services.QuotaTracker, logger *zap.Logger) *AIHandler {
	return &AIHandler{
		service: service,
		quota:   quota,
		logger:  logger,
	}
}

// quota429 writes a 429 with a small JSON shape clients can branch on.
// Returns true if quota was exceeded (caller should return immediately).
func (h *AIHandler) quota429(c *gin.Context, userID uint, bucket string) bool {
	if err := h.quota.Check(userID, bucket); err != nil {
		if err == services.ErrQuotaExceeded {
			used, limit := h.quota.Used(userID, bucket)
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":  "今日 AI 额度已用完",
				"bucket": bucket,
				"used":   used,
				"limit":  limit,
			})
			return true
		}
		// Misconfig (unknown bucket) — log and let through; failing closed
		// here would be worse than over-counting one request.
		h.logger.Error("quota check failed", zap.Error(err))
	}
	return false
}

// TranscribeStream upgrades the request to WebSocket and forwards audio to
// DashScope paraformer-realtime-v2 via StreamTranscribeProxy. Latency
// (perceived by phone): ~0.5s after speech end vs ~3.7s with the batch
// path; partials stream in <1s of speaking, so the input box fills as the
// user is still talking.
func (h *AIHandler) TranscribeStream(c *gin.Context) {
	proxy := h.service.StreamProxy()
	if proxy == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "stream transcribe not configured"})
		return
	}
	conn, err := wsUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		h.logger.Warn("ws upgrade failed", zap.Error(err))
		return
	}
	proxy.Handle(c.Request.Context(), conn)
}

func (h *AIHandler) RecognizeFood(c *gin.Context) {
	var req services.RecognizeFoodRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if h.quota429(c, req.UserID, services.QuotaBucketExpensive) {
		return
	}

	result, err := h.service.RecognizeFood(&req)
	if err != nil {
		h.logger.Error("failed to recognize food", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "食物识别失败"})
		return
	}

	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) ParseWeight(c *gin.Context) {
	var req services.ParseWeightRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.service.ParseWeightFromText(req.Text, req.Locale)
	if err != nil {
		h.logger.Error("parse weight failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "体重解析失败"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) ParseProfile(c *gin.Context) {
	var req services.ParseProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.service.ParseProfileFromText(req.Text, req.Locale)
	if err != nil {
		h.logger.Error("parse profile failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "个人信息解析失败"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) Transcribe(c *gin.Context) {
	req, err := bindAudioRequest(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.service.TranscribeAudio(req)
	if err != nil {
		h.logger.Error("transcribe failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "语音转写失败"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) TranscribeAndParseProfile(c *gin.Context) {
	req, err := bindAudioRequest(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.service.TranscribeAndParseProfile(req)
	if err != nil {
		h.logger.Error("transcribe-and-parse failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "语音解析失败"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) EstimateExercise(c *gin.Context) {
	var req services.EstimateExerciseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.service.EstimateExerciseFromText(req.Text, req.Locale)
	if err != nil {
		h.logger.Error("estimate exercise failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "运动消耗估算失败"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) GetDailyBrief(c *gin.Context) {
	var req services.DailyBriefRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if h.quota429(c, req.UserID, services.QuotaBucketText) {
		return
	}
	result, err := h.service.GetDailyBrief(req.UserID, req.Locale, req.Tz)
	if err != nil {
		h.logger.Error("daily brief failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "生成简报失败"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) EstimateNutrition(c *gin.Context) {
	var req services.EstimateNutritionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.service.EstimateNutritionFromText(req.Text, req.Locale)
	if err != nil {
		h.logger.Error("estimate nutrition failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "营养素估算失败"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) GetEncouragement(c *gin.Context) {
	var req services.GetEncouragementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if h.quota429(c, req.UserID, services.QuotaBucketText) {
		return
	}

	result, err := h.service.GetEncouragement(&req)
	if err != nil {
		h.logger.Error("failed to get encouragement", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取鼓励信息失败"})
		return
	}

	c.JSON(http.StatusOK, result)
}

func (h *AIHandler) Chat(c *gin.Context) {
	var req services.ChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if h.quota429(c, req.UserID, services.QuotaBucketText) {
		return
	}

	result, err := h.service.Chat(&req)
	if err != nil {
		h.logger.Error("failed to chat", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "AI 对话失败"})
		return
	}

	c.JSON(http.StatusOK, result)
}

// ChatStream SSE 端点，按片段推送 Gemini 的增量响应。
// 前端 EventSource / fetch stream 消费。每帧是 JSON:
//   - {"delta": "片段文本"}
//   - {"done": true, "message_id": 123}
//   - 错误时：{"done": true, "error": "消息"}
func (h *AIHandler) ChatStream(c *gin.Context) {
	var req services.ChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if h.quota429(c, req.UserID, services.QuotaBucketText) {
		return
	}

	stream, err := h.service.ChatStream(c.Request.Context(), &req)
	if err != nil {
		h.logger.Error("chat stream init failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.Writer.Header().Set("Content-Type", "text/event-stream")
	c.Writer.Header().Set("Cache-Control", "no-cache")
	c.Writer.Header().Set("Connection", "keep-alive")
	c.Writer.Header().Set("X-Accel-Buffering", "no") // 绕过 nginx 缓冲

	c.Stream(func(w io.Writer) bool {
		chunk, ok := <-stream
		if !ok {
			return false
		}
		data, _ := json.Marshal(chunk)
		fmt.Fprintf(w, "data: %s\n\n", data)
		if chunk.Done {
			return false
		}
		return true
	})
}

func (h *AIHandler) ListFacts(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 user_id"})
		return
	}
	facts, err := h.service.ListUserFacts(uint(userID))
	if err != nil {
		h.logger.Error("list facts failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取事实失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"facts": facts, "count": len(facts)})
}

func (h *AIHandler) DeleteFact(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 id"})
		return
	}
	if err := h.service.DeleteUserFact(uint(id)); err != nil {
		h.logger.Error("delete fact failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "已删除"})
}

func (h *AIHandler) GetChatHistory(c *gin.Context) {
	userIDStr := c.Query("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 user_id 参数"})
		return
	}

	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid user id", zap.String("user_id", userIDStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 user_id"})
		return
	}

	threadID := c.Query("thread_id")
	if threadID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 thread_id 参数"})
		return
	}

	limitStr := c.DefaultQuery("limit", "50")
	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		h.logger.Error("invalid limit parameter", zap.String("limit", limitStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 limit 参数"})
		return
	}

	// Optional delta cursor. Client passes the id of its last known message;
	// server returns only messages with a larger id. 0 / missing = full history.
	var sinceID uint
	if s := c.Query("since_id"); s != "" {
		n, parseErr := strconv.ParseUint(s, 10, 32)
		if parseErr != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 since_id 参数"})
			return
		}
		sinceID = uint(n)
	}

	messages, err := h.service.GetChatHistory(uint(userID), threadID, limit, sinceID)
	if err != nil {
		h.logger.Error("failed to get chat history", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取聊天记录失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"messages": messages,
		"count":    len(messages),
	})
}

func (h *AIHandler) CreateThread(c *gin.Context) {
	userIDStr := c.Query("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 user_id 参数"})
		return
	}

	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid user id", zap.String("user_id", userIDStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 user_id"})
		return
	}

	var req struct {
		Title string `json:"title"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	thread, err := h.service.CreateChatThread(uint(userID), req.Title)
	if err != nil {
		h.logger.Error("failed to create chat thread", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建对话线程失败"})
		return
	}

	c.JSON(http.StatusCreated, thread)
}

func (h *AIHandler) UpdateThread(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 id"})
		return
	}
	var req struct {
		Title string `json:"title"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.service.UpdateChatThreadTitle(uint(id), req.Title); err != nil {
		h.logger.Error("update thread failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "已更新"})
}

func (h *AIHandler) DeleteThread(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 id"})
		return
	}
	if err := h.service.DeleteChatThread(uint(id)); err != nil {
		h.logger.Error("delete thread failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "已删除"})
}

func (h *AIHandler) GetUserThreads(c *gin.Context) {
	userIDStr := c.Query("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 user_id 参数"})
		return
	}

	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid user id", zap.String("user_id", userIDStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 user_id"})
		return
	}

	threads, err := h.service.GetUserThreads(uint(userID))
	if err != nil {
		h.logger.Error("failed to get user threads", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取对话线程列表失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"threads": threads,
		"count":   len(threads),
	})
}
