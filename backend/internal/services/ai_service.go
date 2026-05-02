package services

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

// StreamChunk 聊天流式输出的一帧。
//
// Action / ActionPayload: AI agent 自己决定调用工具（log_weight 等）后，
// 后端先执行落库，再把结果作为单独一帧推给前端，前端据此渲染可撤销卡片。
// ActionPayload 是 JSON-encoded string（用 string 而非 map 是为了 SSE 序列化稳定 +
// 前端按需解析）。
type StreamChunk struct {
	Delta         string `json:"delta,omitempty"`
	MessageID     uint   `json:"message_id,omitempty"`
	Error         string `json:"error,omitempty"`
	Done          bool   `json:"done,omitempty"`
	Action        string `json:"action,omitempty"`         // e.g. "log_weight"
	ActionPayload string `json:"action_payload,omitempty"` // JSON string
}

// Gemini 默认端点（gemini-pro 已被 Google 下线）。可通过 config 的
// gemini_api_url / vision_api_url 覆盖。
const defaultGeminiURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

// isThinkingOnlyModel 判断 URL 指向的 Gemini 模型是否强制 thinking
// （3.x Pro / Pro-preview 是 thinking-only，发 thinkingBudget=0 会 400）。
func isThinkingOnlyModel(apiURL string) bool {
	return strings.Contains(apiURL, "-pro")
}

// maxOutputTokensForChat 给 chat 路径选 maxOutputTokens。Flash 关 thinking
// 后 4096 足够；Pro 默认 dynamic thinking，thinking + 最终输出共享这个预算，
// 真实用户上下文（system + facts + RAG + 历史）下 4096 经常被 thinking
// 吃光，候选返回 0 part —— 后端识别成 "no response from LLM"。给 Pro 留
// 16384 让 thinking 花够还有空间出文字。
func maxOutputTokensForChat(apiURL string) int {
	if isThinkingOnlyModel(apiURL) {
		return 16384
	}
	return 4096
}

// errLLMNotConfigured 当 debug=false 且 LLM key 缺失时返回。
var errLLMNotConfigured = errors.New("LLM not configured: set GEMINI_API_KEY or run in debug mode to use mocks")

// Deepgram 中文转写偶尔把数字中间的小数点输出成全角"。"；这个正则只
// 在数字和数字之间换回半角 "."，不动句末真的句号。
var regexpDigitDot = regexp.MustCompile(`(\d)。(\d)`)

type AIService struct {
	db              *gorm.DB
	logger          *zap.Logger
	llmAPIKey       string
	llmAPIURL       string
	visionAPIKey    string
	visionAPIURL    string
	deepgramAPIKey string // legacy; only used as fallback now
	qwenAPIKey     string // DashScope key — STT goes through paraformer-realtime-v2
	streamProxy    *StreamTranscribeProxy
	// allowMock 为 true 时，缺失 LLM key 会降级到写死的 mock 响应；
	// 为 false（生产）时 hard fail，避免静默兜底骗调用方。
	allowMock bool
}

func NewAIService(db *gorm.DB, logger *zap.Logger, llmAPIKey, llmAPIURL, visionAPIKey, visionAPIURL, deepgramAPIKey, qwenAPIKey string, allowMock bool) *AIService {
	s := &AIService{
		db:             db,
		logger:         logger,
		llmAPIKey:      llmAPIKey,
		llmAPIURL:      llmAPIURL,
		visionAPIKey:   visionAPIKey,
		visionAPIURL:   visionAPIURL,
		deepgramAPIKey: deepgramAPIKey,
		qwenAPIKey:     qwenAPIKey,
		allowMock:      allowMock,
	}
	if qwenAPIKey != "" {
		s.streamProxy = NewStreamTranscribeProxy(logger, qwenAPIKey)
	}
	return s
}

// StreamProxy exposes the lazily-built stream transcribe proxy so the
// gin handler can register a WebSocket route on /v1/ai/transcribe/stream
// without needing yet another constructor parameter through routes.go.
func (s *AIService) StreamProxy() *StreamTranscribeProxy {
	return s.streamProxy
}

// languageName maps a locale code (en / zh / ...) to the full English
// language name we feed into LLM prompts. Keep it small and explicit;
// unknown codes fall back to English so the backend never refuses a request.
func languageName(locale string) string {
	switch locale {
	case "zh", "zh-CN", "zh-Hans":
		return "Simplified Chinese"
	case "zh-TW", "zh-Hant":
		return "Traditional Chinese"
	case "ja":
		return "Japanese"
	case "es":
		return "Spanish"
	case "", "en", "en-US", "en-GB":
		fallthrough
	default:
		return "English"
	}
}

type RecognizeFoodRequest struct {
	UserID   uint   `json:"user_id"` // for quota tracking; 0 means "anonymous" → shares one bucket
	ImageURL string `json:"image_url" binding:"required"`
	Locale   string `json:"locale"`
}

type RecognizeFoodResponse struct {
	FoodName      string  `json:"food_name"`
	Calories      float32 `json:"calories"`
	Protein       float32 `json:"protein"`
	Carbohydrates float32 `json:"carbohydrates"`
	Fat           float32 `json:"fat"`
	Fiber         float32 `json:"fiber"`
	Confidence    float32 `json:"confidence"`
}

type EstimateNutritionRequest struct {
	Text   string `json:"text" binding:"required"`
	Locale string `json:"locale"`
}

type ParseProfileRequest struct {
	Text   string `json:"text" binding:"required"`
	Locale string `json:"locale"`
}

// TranscribeRequest: 音频 base64 送 Gemini STT。mime 如 "audio/mp4"、
// "audio/aac"、"audio/wav"、"audio/ogg"、"audio/mpeg"；移动端推荐 m4a/AAC。
type TranscribeRequest struct {
	AudioBase64 string `json:"audio_base64" binding:"required"`
	MimeType    string `json:"mime_type"` // default: audio/mp4
	Locale      string `json:"locale"`
}

type TranscribeResponse struct {
	Text       string  `json:"text"`
	Confidence float32 `json:"confidence"`
}

// TranscribeAndParseProfileResponse: 音频 → 转写 + profile 字段。
// transcript 字段让前端能复核（确认识别对不对），其他字段跟
// ParseProfileResponse 对齐。
type TranscribeAndParseProfileResponse struct {
	Transcript    string  `json:"transcript"`
	Gender        string  `json:"gender"`
	Age           int     `json:"age"`
	Height        float32 `json:"height"`
	CurrentWeight float32 `json:"current_weight"`
	TargetWeight  float32 `json:"target_weight"`
	ActivityLevel int     `json:"activity_level"`
	Confidence    float32 `json:"confidence"`
}

// ParseProfileResponse: 结构化的 profile 字段。所有可选，LLM 没信息就留零值。
// 前端只填充 ParseProfileResponse 里非零 / 非空的字段。
type ParseProfileResponse struct {
	Gender        string  `json:"gender"`         // "male" / "female" / ""
	Age           int     `json:"age"`            // 0 = 未提及
	Height        float32 `json:"height"`         // cm, 0 = 未提及
	CurrentWeight float32 `json:"current_weight"` // kg, 0 = 未提及
	TargetWeight  float32 `json:"target_weight"`  // kg, 0 = 未提及
	ActivityLevel int     `json:"activity_level"` // 1-5, 0 = 未提及
	Confidence    float32 `json:"confidence"`
}

type ParseWeightRequest struct {
	Text   string `json:"text" binding:"required"`
	Locale string `json:"locale"`
}

type ParseWeightResponse struct {
	Weight     float32 `json:"weight"`
	BodyFat    float32 `json:"body_fat"`
	Muscle     float32 `json:"muscle"`
	Water      float32 `json:"water"`
	Note       string  `json:"note"`
	Confidence float32 `json:"confidence"`
}

type EstimateExerciseRequest struct {
	Text   string `json:"text" binding:"required"`
	Locale string `json:"locale"`
}

type EstimateExerciseResponse struct {
	Type           string  `json:"type"`
	DurationMin    int     `json:"duration_min"`
	Intensity      string  `json:"intensity"`
	CaloriesBurned float32 `json:"calories_burned"`
	Distance       float32 `json:"distance"`
	Confidence     float32 `json:"confidence"`
}

type DailyBriefRequest struct {
	UserID uint   `json:"user_id" binding:"required"`
	Locale string `json:"locale"`
	// Tz is an IANA timezone name (e.g. "Asia/Shanghai") used to draw the
	// "today" boundary. Empty falls back to UTC, which is wrong for most
	// users — clients should always send it.
	Tz string `json:"tz"`
}

type DailyBriefResponse struct {
	TargetCalories    float32 `json:"target_calories"`
	CaloriesEaten     float32 `json:"calories_eaten"`
	CaloriesBurned    float32 `json:"calories_burned"`
	CaloriesRemaining float32 `json:"calories_remaining"`
	MealsLogged       int     `json:"meals_logged"`
	ExercisesLogged   int     `json:"exercises_logged"`
	// Metabolism, Plan B expenditure model: CaloriesExpended = TDEE (activity
	// level already covers workouts; logged exercise is not added on top).
	// Deficit > 0 means net caloric deficit for the day (fat-loss direction).
	// Zeros mean "profile incomplete" — frontend should show a CTA instead.
	BMR              float32 `json:"bmr"`
	TDEE             float32 `json:"tdee"`
	CaloriesExpended float32 `json:"calories_expended"`
	CaloriesDeficit  float32 `json:"calories_deficit"`
	// Brief 一句话点评 + 下一步建议
	Brief string `json:"brief"`
}

type GetEncouragementRequest struct {
	UserID        uint     `json:"user_id" binding:"required"`
	CurrentWeight float32  `json:"current_weight"`
	TargetWeight  float32  `json:"target_weight"`
	WeightLoss    float32  `json:"weight_loss"`
	DaysActive    int      `json:"days_active"`
	Achievements  []string `json:"achievements"`
	Locale        string   `json:"locale"`
}

type GetEncouragementResponse struct {
	Message   string `json:"message"`
	Suggestions []string `json:"suggestions"`
}

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatRequest struct {
	UserID   uint          `json:"user_id" binding:"required"`
	Messages []ChatMessage `json:"messages" binding:"required"`
	ThreadID string        `json:"thread_id"`
	Locale   string        `json:"locale"`
	// Tz is an IANA timezone name; used so the system prompt's "today"
	// snapshot lines up with the user's local calendar day.
	Tz string `json:"tz"`
}

type ChatResponse struct {
	MessageID uint   `json:"message_id"`
	Role      string `json:"role"`
	Content   string `json:"content"`
	ThreadID  string `json:"thread_id"`
}

func (s *AIService) RecognizeFood(req *RecognizeFoodRequest) (*RecognizeFoodResponse, error) {
	apiURL := s.visionAPIURL
	if apiURL == "" {
		apiURL = defaultGeminiURL
	}

	apiKey := s.visionAPIKey
	if apiKey == "" {
		// 没单独配置 vision key 时，复用 LLM key
		apiKey = s.llmAPIKey
	}

	if apiKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("vision API not configured — returning mock (debug mode)")
		return &RecognizeFoodResponse{
			FoodName:      "Test food",
			Calories:      300,
			Protein:       15,
			Carbohydrates: 40,
			Fat:           10,
			Fiber:         5,
			Confidence:    0.95,
		}, nil
	}

	// Normalize image URL / data URL into base64 + mime for Gemini inline_data.
	mimeType, b64, err := fetchImageAsBase64(req.ImageURL)
	if err != nil {
		s.logger.Error("failed to fetch image", zap.Error(err))
		return nil, fmt.Errorf("failed to fetch image: %w", err)
	}

	lang := languageName(req.Locale)
	prompt := fmt.Sprintf(`Analyze this food photo and return the information below. JSON ONLY — no markdown fence, no prose.
{
  "food_name": "short name of the dish in %s",
  "calories": integer kcal per 100 g,
  "protein": grams of protein per 100 g,
  "carbohydrates": grams of carbs per 100 g,
  "fat": grams of fat per 100 g,
  "fiber": grams of fiber per 100 g,
  "confidence": 0.0-1.0
}`, lang)

	payload := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"role": "user",
				"parts": []map[string]interface{}{
					{"text": prompt},
					{"inline_data": map[string]string{
						"mime_type": mimeType,
						"data":      b64,
					}},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"temperature":      0.3,
			"maxOutputTokens":  500,
			// Force strict JSON output; stops Gemini from wrapping in
			// ```json ... ``` fences or prefacing with prose.
			"responseMimeType": "application/json",
		},
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		s.logger.Error("failed to marshal vision request", zap.Error(err))
		return nil, err
	}

	client := &http.Client{Timeout: 60 * time.Second}
	url := fmt.Sprintf("%s?key=%s", apiURL, apiKey)
	httpReq, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		s.logger.Error("failed to create vision request", zap.Error(err))
		return nil, err
	}

	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(httpReq)
	if err != nil {
		s.logger.Error("vision API request failed", zap.Error(err))
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		s.logger.Error("vision API returned error status",
			zap.Int("status", resp.StatusCode),
			zap.String("body", string(body)))
		return nil, fmt.Errorf("vision API error: %d, body: %s", resp.StatusCode, string(body))
	}

	var result struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		s.logger.Error("failed to decode vision response", zap.Error(err))
		return nil, err
	}

	if len(result.Candidates) == 0 || len(result.Candidates[0].Content.Parts) == 0 {
		return nil, errors.New("no response from vision API")
	}

	// 解析返回的 JSON 文本
	responseText := result.Candidates[0].Content.Parts[0].Text
	s.logger.Info("vision API response", zap.String("text", responseText))

	// 尝试解析 JSON
	var foodInfo struct {
		FoodName      string  `json:"food_name"`
		Calories      float32 `json:"calories"`
		Protein       float32 `json:"protein"`
		Carbohydrates float32 `json:"carbohydrates"`
		Fat           float32 `json:"fat"`
		Fiber         float32 `json:"fiber"`
		Confidence    float32 `json:"confidence"`
	}

	// responseMimeType=application/json 会让 Gemini 返回干净 JSON，但偶尔还是
	// 会出现截断或空串（例如安全过滤器触发）；再过一层 fence 清理作为兜底。
	cleanText := stripMarkdownCodeFence(responseText)
	if err := json.Unmarshal([]byte(cleanText), &foodInfo); err != nil {
		s.logger.Error("failed to parse food info JSON",
			zap.Error(err), zap.String("raw", responseText))
		// Parse failed — return default shape.
		return &RecognizeFoodResponse{
			FoodName:      "Unknown food",
			Calories:      0,
			Protein:       0,
			Carbohydrates: 0,
			Fat:           0,
			Fiber:         0,
			Confidence:    0,
		}, nil
	}

	return &RecognizeFoodResponse{
		FoodName:      foodInfo.FoodName,
		Calories:      foodInfo.Calories,
		Protein:       foodInfo.Protein,
		Carbohydrates: foodInfo.Carbohydrates,
		Fat:           foodInfo.Fat,
		Fiber:         foodInfo.Fiber,
		Confidence:    foodInfo.Confidence,
	}, nil
}

// EstimateNutritionFromText: 用 Gemini 根据纯文本描述估算营养素。
// 例：「一碗米饭 200g」「宫保鸡丁一份」「全麦面包两片配一杯豆浆」
func (s *AIService) EstimateNutritionFromText(text, locale string) (*RecognizeFoodResponse, error) {
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — estimate-nutrition returning mock (debug mode)")
		return &RecognizeFoodResponse{
			FoodName: text, Calories: 300, Protein: 15,
			Carbohydrates: 40, Fat: 10, Fiber: 5, Confidence: 0.5,
		}, nil
	}

	prompt := fmt.Sprintf(`Estimate nutrition from the food description below. JSON ONLY — no markdown fence, no prose.

Description: %s

JSON schema:
{
  "food_name": "short name of the dish in %s",
  "calories": total kcal,
  "protein": grams of protein,
  "carbohydrates": grams of carbs,
  "fat": grams of fat,
  "fiber": grams of fiber,
  "confidence": 0.0-1.0
}

Rules:
- If the description gives a concrete portion (e.g. "200g", "1 cup"), compute the total for that portion; otherwise estimate one standard serving.
- Numbers without units.
- Higher confidence when the description is concrete; lower when it's vague.`, text, languageName(locale))

	resp, err := s.callLLM([]ChatMessage{{Role: "user", Content: prompt}})
	if err != nil {
		return nil, err
	}
	jsonText := stripMarkdownCodeFence(resp.Content)
	var out RecognizeFoodResponse
	if err := json.Unmarshal([]byte(jsonText), &out); err != nil {
		return nil, fmt.Errorf("failed to parse LLM response: %w (raw: %s)", err, resp.Content)
	}
	return &out, nil
}

// ParseWeightFromText: 把自然语言（例："68.5kg 体脂 22%"、"今天 67.8"、"早 68 晚 67.5"）
// 解析出结构化体重信息。体重本身简单，但希望形态一致（都走 AI 解析）。
func (s *AIService) ParseWeightFromText(text, locale string) (*ParseWeightResponse, error) {
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — parse-weight returning mock (debug mode)")
		return &ParseWeightResponse{Weight: 70, Confidence: 0.5}, nil
	}

	prompt := fmt.Sprintf(`Parse weight data from the text below. JSON ONLY — no markdown fence, no prose.

Text: %s

JSON schema:
{
  "weight": weight in kg (required),
  "body_fat": body fat percentage (0 if none),
  "muscle": muscle mass in kg (0 if none),
  "water": water percentage (0 if none),
  "note": "short note in %s if the text mentions context (e.g. 'morning', 'post-workout'), max 20 chars; else empty",
  "confidence": 0.0-1.0
}

Rules:
- Numbers without units.
- If there's a single weight number, populate "weight".
- If multiple measurements appear, take the last/most recent one.`, text, languageName(locale))

	resp, err := s.callLLM([]ChatMessage{{Role: "user", Content: prompt}})
	if err != nil {
		return nil, err
	}
	jsonText := stripMarkdownCodeFence(resp.Content)
	var out ParseWeightResponse
	if err := json.Unmarshal([]byte(jsonText), &out); err != nil {
		return nil, fmt.Errorf("failed to parse LLM response: %w (raw: %s)", err, resp.Content)
	}
	return &out, nil
}

// ParseProfileFromText: 把一句话（文字或语音转写）解析成结构化 profile。
// 设计意图：onboarding 快速设置页放一个"用一句话描述自己"的输入，用户
// 随便说 "35 岁男，180cm 82kg 想减到 75"，后端分出字段，前端自动填表。
// 所有字段可选——LLM 没把握就返回零值，前端用零值过滤不覆盖已填字段。
func (s *AIService) ParseProfileFromText(text, locale string) (*ParseProfileResponse, error) {
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — parse-profile returning mock (debug mode)")
		return &ParseProfileResponse{Confidence: 0.5}, nil
	}

	prompt := fmt.Sprintf(`Parse body/profile fields from the text below. JSON ONLY — no markdown fence, no prose.

Text: %s

JSON schema (every field is optional; emit 0 / empty string when the text
doesn't mention that field — DO NOT guess):
{
  "gender": "male" | "female" | "",
  "age": integer years (0 if not mentioned),
  "height": integer cm (0 if not mentioned),
  "current_weight": kg as number (0 if not mentioned),
  "target_weight": kg as number (0 if not mentioned),
  "activity_level": 1..5 (0 if not mentioned; 1=sedentary, 2=light,
                    3=moderate, 4=active, 5=very active),
  "confidence": 0.0-1.0
}

Rules:
- Numbers WITHOUT units.
- Treat "男 / male / 哥们 / 老哥" as male; "女 / female / 妹子" as female.
- Height hints: "cm", "公分", "米" (convert 1.8米 → 180).
- Weight hints: "kg", "公斤", "斤" (斤 = 0.5kg — convert to kg).
- "Want to be X / 想减到 X / 目标 X" → target_weight.
- "Currently / 现在 / 目前" → current_weight.
- If only one weight number and no direction → current_weight.
- Training frequency hints: "每周 3 次 / 撸铁 / HIIT" → activity_level 4;
  "每天走路 / 偶尔动" → 2; "坐办公室不动" → 1. Don't guess if unclear.
- User's interface language is %s — these hints may also appear in that
  language.`, text, languageName(locale))

	resp, err := s.callLLM([]ChatMessage{{Role: "user", Content: prompt}})
	if err != nil {
		return nil, err
	}
	jsonText := stripMarkdownCodeFence(resp.Content)
	var out ParseProfileResponse
	if err := json.Unmarshal([]byte(jsonText), &out); err != nil {
		return nil, fmt.Errorf("failed to parse LLM response: %w (raw: %s)", err, resp.Content)
	}
	return &out, nil
}

// geminiAudioCall: 共用逻辑——base64 audio + prompt → Gemini text response。
// `forceJSON=true` 走 responseMimeType=application/json；false 时 Gemini
// 输出纯文本（用于转写）。返回原始 text（JSON 路径调用方再自己 unmarshal）。
func (s *AIService) geminiAudioCall(audioB64, mimeType, prompt string, forceJSON bool, maxOutputTokens int) (string, error) {
	if s.llmAPIKey == "" {
		return "", errLLMNotConfigured
	}
	apiURL := s.visionAPIURL
	if apiURL == "" {
		apiURL = defaultGeminiURL
	}
	if mimeType == "" {
		mimeType = "audio/mp4"
	}

	genConfig := map[string]interface{}{
		"temperature":     0.0, // 转写任务零温度，减少幻觉
		"maxOutputTokens": maxOutputTokens,
	}
	if forceJSON {
		genConfig["responseMimeType"] = "application/json"
	}

	payload := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"role": "user",
				"parts": []map[string]interface{}{
					{"text": prompt},
					{"inline_data": map[string]string{
						"mime_type": mimeType,
						"data":      audioB64,
					}},
				},
			},
		},
		"generationConfig": genConfig,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	client := &http.Client{Timeout: 60 * time.Second}
	url := fmt.Sprintf("%s?key=%s", apiURL, s.visionAPIKey)
	if s.visionAPIKey == "" {
		url = fmt.Sprintf("%s?key=%s", apiURL, s.llmAPIKey)
	}
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("audio API %d: %s", resp.StatusCode, string(b))
	}
	var result struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	if len(result.Candidates) == 0 || len(result.Candidates[0].Content.Parts) == 0 {
		return "", errors.New("no response from audio API")
	}
	return result.Candidates[0].Content.Parts[0].Text, nil
}

// transcribeDeepgram: 优选路径。nova-3 英文、nova-2 其他语言（中文
// nova-2 zh-CN 99.9% confidence，实测比 Gemini 快 3-4x）。
// 直接上传原始音频 bytes（Deepgram 不要 base64）。
func (s *AIService) transcribeDeepgram(audioBase64, mimeType, locale string) (*TranscribeResponse, error) {
	raw, err := base64.StdEncoding.DecodeString(audioBase64)
	if err != nil {
		return nil, fmt.Errorf("decode base64: %w", err)
	}
	// 英语用 nova-3（快、准）；其他用 nova-2（中文支持）。
	model := "nova-2"
	langParam := "multi"
	switch strings.ToLower(locale) {
	case "en", "en-us", "en-gb":
		model = "nova-3"
		langParam = "en"
	case "zh", "zh-cn", "zh-hans":
		model = "nova-2"
		langParam = "zh-CN"
	case "zh-tw", "zh-hant":
		model = "nova-2"
		langParam = "zh-TW"
	}
	url := fmt.Sprintf(
		"https://api.deepgram.com/v1/listen?model=%s&language=%s&smart_format=true",
		model, langParam)
	if mimeType == "" {
		mimeType = "audio/mp4"
	}
	client := &http.Client{Timeout: 60 * time.Second}
	req, err := http.NewRequest("POST", url, bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Token "+s.deepgramAPIKey)
	req.Header.Set("Content-Type", mimeType)
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("deepgram %d: %s", resp.StatusCode, string(body))
	}
	var result struct {
		Results struct {
			Channels []struct {
				Alternatives []struct {
					Transcript string  `json:"transcript"`
					Confidence float32 `json:"confidence"`
				} `json:"alternatives"`
			} `json:"channels"`
		} `json:"results"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	if len(result.Results.Channels) == 0 ||
		len(result.Results.Channels[0].Alternatives) == 0 {
		return nil, errors.New("deepgram: no alternatives")
	}
	alt := result.Results.Channels[0].Alternatives[0]
	// Deepgram 的中文输出偶尔用全角 "。" 代替小数点，折回来（"72。5" → "72.5"）。
	text := strings.ReplaceAll(alt.Transcript, "。", ".")
	// 但如果这段是末尾的句号，我们又不想改 —— 简化：只在数字之间换
	text = regexpDigitDot.ReplaceAllString(alt.Transcript, "$1.$2")
	return &TranscribeResponse{
		Text:       strings.TrimSpace(text),
		Confidence: alt.Confidence,
	}, nil
}

// transcribeParaformer: primary STT path. Hits DashScope's
// paraformer-realtime-v2 (purpose-built ASR) over WebSocket through the
// streamProxy, even for one-shot HTTP transcription — same upstream model
// for both the realtime mic flow and the legacy batch endpoint, no second
// implementation. Way cheaper + faster + more accurate than running an
// LLM (qwen-omni) for what's basically a transcoder problem.
func (s *AIService) transcribeParaformer(audioBase64, mimeType, locale string) (*TranscribeResponse, error) {
	if s.streamProxy == nil {
		return nil, errors.New("transcribe not configured")
	}
	raw, err := base64.StdEncoding.DecodeString(audioBase64)
	if err != nil {
		return nil, fmt.Errorf("decode base64: %w", err)
	}

	// Mime → paraformer codec hint. paraformer-realtime-v2 accepts:
	//   pcm | wav | mp3 | aac | opus | speex | amr
	// flutter_sound on Android records aacMP4 by default; we treat that as
	// "aac" (the encoded payload is AAC-LC even when wrapped in MP4 framing
	// — short clips frame-align cleanly).
	if mimeType == "" {
		mimeType = "audio/mp4"
	}
	format := strings.TrimPrefix(mimeType, "audio/")
	if i := strings.IndexByte(format, ';'); i > 0 {
		format = strings.TrimSpace(format[:i])
	}
	switch format {
	case "mp4", "x-m4a", "m4a":
		format = "aac"
	case "mpeg":
		format = "mp3"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	text, err := s.streamProxy.TranscribeBytes(ctx, raw, format)
	if err != nil {
		return nil, err
	}
	text = regexpDigitDot.ReplaceAllString(text, "$1.$2")
	return &TranscribeResponse{
		Text:       strings.TrimSpace(text),
		Confidence: 0, // paraformer doesn't return a per-utterance confidence
	}, nil
}

// TranscribeAudio: 语音转写优先级 — Paraformer（主路，dedicated ASR via
// WS) → Deepgram（兜底）→ Gemini（最后兜底）→ mock（dev only）。字对字，
// 不做结构化、不 paraphrase。
func (s *AIService) TranscribeAudio(req *TranscribeRequest) (*TranscribeResponse, error) {
	if s.qwenAPIKey != "" {
		r, err := s.transcribeParaformer(req.AudioBase64, req.MimeType, req.Locale)
		if err == nil {
			return r, nil
		}
		s.logger.Warn("paraformer transcribe failed, trying Deepgram fallback", zap.Error(err))
	}
	if s.deepgramAPIKey != "" {
		r, err := s.transcribeDeepgram(req.AudioBase64, req.MimeType, req.Locale)
		if err == nil {
			return r, nil
		}
		s.logger.Warn("deepgram transcribe failed, falling back to Gemini", zap.Error(err))
	}
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM not configured — transcribe returning mock")
		return &TranscribeResponse{Text: "(mock transcription)", Confidence: 0.5}, nil
	}
	lang := languageName(req.Locale)
	prompt := fmt.Sprintf(`Transcribe the attached audio verbatim into %s.
Output ONLY the transcription text — no prose, no quotes, no "Transcript:" prefix.
Preserve numbers and units as spoken (e.g. "82 公斤", "72.5kg").
If the audio contains no speech, output an empty line.`, lang)

	text, err := s.geminiAudioCall(req.AudioBase64, req.MimeType, prompt, false, 500)
	if err != nil {
		s.logger.Error("transcribe failed", zap.Error(err))
		return nil, err
	}
	return &TranscribeResponse{
		Text:       strings.TrimSpace(text),
		Confidence: 0.95,
	}, nil
}

// TranscribeAndParseProfile: 一次 Gemini 调用完成音频转写 + profile 结构化。
// 前端录音后直接拿到填好的表单字段，省一轮 round-trip。
func (s *AIService) TranscribeAndParseProfile(req *TranscribeRequest) (*TranscribeAndParseProfileResponse, error) {
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		return &TranscribeAndParseProfileResponse{Confidence: 0.5}, nil
	}
	lang := languageName(req.Locale)
	prompt := fmt.Sprintf(`Listen to the audio and extract body profile fields. JSON ONLY — no markdown fence.

JSON schema (every field optional; emit 0 / empty string when not mentioned
— DO NOT guess):
{
  "transcript": "verbatim transcription in %s",
  "gender": "male" | "female" | "",
  "age": integer years (0 if not mentioned),
  "height": integer cm (0 if not mentioned),
  "current_weight": kg number (0 if not mentioned),
  "target_weight": kg number (0 if not mentioned),
  "activity_level": 1..5 (0 if not mentioned; 1=sedentary, 2=light,
                    3=moderate, 4=active, 5=very active),
  "confidence": 0.0-1.0
}

Rules:
- Numbers WITHOUT units in the numeric fields.
- "男 / male" → male; "女 / female" → female.
- Convert 1.8米 → 180; convert 164斤 → 82kg (斤 = 0.5kg).
- "Want to be X / 想减到 X / 目标 X" → target_weight.
- Current weight if only one number given.
- "每周 3 次 / 撸铁 / HIIT" → activity_level 4; "坐办公室" → 1.`, lang)

	raw, err := s.geminiAudioCall(req.AudioBase64, req.MimeType, prompt, true, 600)
	if err != nil {
		s.logger.Error("transcribe-and-parse failed", zap.Error(err))
		return nil, err
	}
	var out TranscribeAndParseProfileResponse
	clean := stripMarkdownCodeFence(raw)
	if err := json.Unmarshal([]byte(clean), &out); err != nil {
		s.logger.Error("transcribe-and-parse JSON parse failed",
			zap.Error(err), zap.String("raw", raw))
		return nil, fmt.Errorf("parse failed: %w", err)
	}
	return &out, nil
}

// EstimateExerciseFromText: 用 Gemini 估算运动类型 + 时长 + 消耗
// 例："跑步 5 公里 30 分钟"、"力量训练 45 分钟"、"走路一小时"
func (s *AIService) EstimateExerciseFromText(text, locale string) (*EstimateExerciseResponse, error) {
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — estimate-exercise returning mock (debug mode)")
		return &EstimateExerciseResponse{
			Type: text, DurationMin: 30, Intensity: "medium",
			CaloriesBurned: 200, Confidence: 0.5,
		}, nil
	}
	prompt := fmt.Sprintf(`Estimate the workout described below. Return JSON ONLY — no markdown fence, no prose.

Description: %s

JSON schema:
{
  "type": "short activity name in %s (running / cycling / lifting / yoga / swimming / walking / HIIT / tennis / ...)",
  "duration_min": integer minutes,
  "intensity": "low | medium | high",
  "calories_burned": integer kcal,
  "distance": km (0 if not applicable),
  "confidence": 0.0-1.0
}

Rules:
- Assume a 70 kg adult man for baseline burn.
- "walk / light / stretch" → low; standard cardio / moderate lifting → medium; "HIIT / sprint / heavy lifting" → high.
- Keep "type" short and canonical (single word or short phrase).`, text, languageName(locale))

	resp, err := s.callLLM([]ChatMessage{{Role: "user", Content: prompt}})
	if err != nil {
		return nil, err
	}
	jsonText := stripMarkdownCodeFence(resp.Content)
	var out EstimateExerciseResponse
	if err := json.Unmarshal([]byte(jsonText), &out); err != nil {
		return nil, fmt.Errorf("failed to parse LLM response: %w (raw: %s)", err, resp.Content)
	}
	return &out, nil
}

// macroTargets mirrors the frontend's deriveMacroTargets: explicit targets
// on profile win; otherwise fall back to recomp defaults keyed off weight.
// Kept in lock-step with lib/utils/macros.dart so the brief prompt and the
// dashboard widget see the same numbers.
type macroTargets struct {
	calorie float32
	protein float32
	carbs   float32
	fat     float32
}

func deriveMacroTargetsBackend(profile *models.UserProfile) macroTargets {
	weight := float32(70)
	calorie := float32(2000)
	if profile != nil {
		if profile.CurrentWeight > 0 {
			weight = profile.CurrentWeight
		}
		if profile.TargetCalorie > 0 {
			calorie = profile.TargetCalorie
		}
	}
	protein := weight * 1.8
	if profile != nil && profile.TargetProteinG > 0 {
		protein = profile.TargetProteinG
	}
	fat := weight * 0.8
	if profile != nil && profile.TargetFatG > 0 {
		fat = profile.TargetFatG
	}
	carbs := float32(0)
	if profile != nil && profile.TargetCarbsG > 0 {
		carbs = profile.TargetCarbsG
	}
	if carbs == 0 {
		remaining := calorie - protein*4 - fat*9
		if remaining > 0 {
			carbs = remaining / 4
		}
	}
	return macroTargets{calorie: calorie, protein: protein, carbs: carbs, fat: fat}
}

// GetDailyBrief: 组合 profile + 今日饮食 + 今日运动，让 LLM 写一句话今日简报。
// 这是首页卡片的数据源——让 AI "在场"。
// `tz` 是 IANA 时区名（"Asia/Shanghai" 等），决定"今天"的边界——空字符串
// 退回 UTC 是为了向后兼容老客户端，但会算错日界，新客户端必须传。
func (s *AIService) GetDailyBrief(userID uint, locale, tz string) (*DailyBriefResponse, error) {
	loc := ResolveLocation(tz)
	now := time.Now().In(loc)

	// 1. 拉数据
	profile := s.loadUserProfile(userID)
	targets := deriveMacroTargetsBackend(profile)
	target := targets.calorie

	// 今日饮食
	foods := s.loadTodayFood(userID, loc)
	var eaten, eatenProtein, eatenCarbs, eatenFat float32
	for _, f := range foods {
		eaten += f.calories
		eatenProtein += f.protein
		eatenCarbs += f.carbs
		eatenFat += f.fat
	}

	// 今日运动
	start := StartOfDay(now, loc)
	end := start.Add(24 * time.Hour)
	var exercises []models.ExerciseRecord
	s.db.Where("user_id = ? AND exercised_at >= ? AND exercised_at < ?",
		userID, start, end).Find(&exercises)
	var burned float32
	for _, e := range exercises {
		burned += e.CaloriesBurned
	}

	remaining := target - eaten + burned
	metab := computeMetabolism(profile)
	out := &DailyBriefResponse{
		TargetCalories:    target,
		CaloriesEaten:     eaten,
		CaloriesBurned:    burned,
		CaloriesRemaining: remaining,
		MealsLogged:       len(foods),
		ExercisesLogged:   len(exercises),
		BMR:               float32(metab.BMR),
		TDEE:              float32(metab.TDEE),
	}
	if metab.HasTDEE {
		// Plan B: expenditure = TDEE, no exercise add-on.
		out.CaloriesExpended = float32(metab.TDEE)
		out.CaloriesDeficit = out.CaloriesExpended - eaten
	}

	// 2. 让 LLM 写一句话
	if s.llmAPIKey == "" {
		if !s.allowMock {
			out.Brief = ""
			return out, nil
		}
		out.Brief = fmt.Sprintf("Today: in %.0f kcal, out %.0f kcal, %.0f kcal left.",
			eaten, burned, remaining)
		return out, nil
	}

	hour := now.Hour()
	mealHint := ""
	switch {
	case hour < 10:
		mealHint = "pre-breakfast / breakfast window"
	case hour < 14:
		mealHint = "lunch window"
	case hour < 17:
		mealHint = "afternoon — a while before dinner"
	case hour < 21:
		mealHint = "dinner window"
	default:
		mealHint = "close to bedtime"
	}

	// 用户长期事实（从记忆里取 top-10）
	facts := s.loadUserFacts(userID, 10)
	var factLines []string
	for _, f := range facts {
		factLines = append(factLines, fmt.Sprintf("- [%s] %s", f.Category, f.Fact))
	}

	foodLines := make([]string, 0, len(foods))
	for _, f := range foods {
		foodLines = append(foodLines, fmt.Sprintf("%s (%.0f kcal)", f.name, f.calories))
	}
	exerciseLines := make([]string, 0, len(exercises))
	for _, e := range exercises {
		exerciseLines = append(exerciseLines, fmt.Sprintf("%s %d min (%.0f kcal)",
			e.Type, e.DurationMin, e.CaloriesBurned))
	}

	prompt := fmt.Sprintf(`You are RecompDaily, an AI recomp coach for men who lift. Write today's short home-screen brief for this user.

## Current state
- Time: %s (%s)
- Calorie target: %.0f kcal
- Eaten today: %.0f kcal
- Burned today: %.0f kcal
- Remaining: %.0f kcal

## Macros today (eaten / target, grams)
- Protein: %.0f / %.0f g   (hero metric — protein is non-negotiable for recomp)
- Carbs:   %.0f / %.0f g
- Fat:     %.0f / %.0f g

## Food today
%s

## Training today
%s

## Long-term user facts
%s

## Writing requirements
- ONE short paragraph in %s, 40-80 words (or ~120 characters for Chinese).
- Open with a quick read of where they stand (on pace / over / under), then ONE concrete next step — prioritize protein gap if they're under 80%% of target.
- When suggesting food, name a specific item + grams (e.g. "200g chicken breast = 46g protein"), not vague advice.
- Respect user constraints and preferences (no dairy if they're lactose intolerant; no running if they hate cardio).
- No lists, no emoji, no blank lines, no "Hi" / "Hello" opener. Get to the point.`,
		now.Format("15:04"), mealHint,
		target, eaten, burned, remaining,
		eatenProtein, targets.protein,
		eatenCarbs, targets.carbs,
		eatenFat, targets.fat,
		strings.Join(append([]string{"(none)"}, foodLines...), "\n"),
		strings.Join(append([]string{"(none)"}, exerciseLines...), "\n"),
		strings.Join(append([]string{"(none recorded yet)"}, factLines...), "\n"),
		languageName(locale),
	)

	resp, err := s.callLLM([]ChatMessage{{Role: "user", Content: prompt}})
	if err != nil {
		s.logger.Warn("daily-brief LLM failed", zap.Error(err))
		out.Brief = fmt.Sprintf("In %.0f kcal, out %.0f kcal, %.0f kcal left.",
			eaten, burned, remaining)
		return out, nil
	}
	out.Brief = strings.TrimSpace(resp.Content)
	return out, nil
}

func (s *AIService) GetEncouragement(req *GetEncouragementRequest) (*GetEncouragementResponse, error) {
	prompt := fmt.Sprintf(`You are RecompDaily, a direct AI recomp coach. Write a short progress message for the user below. Data-driven tone, no pep-talk clichés, no emoji.

Status:
- Weight: %.1f kg
- Target: %.1f kg
- Lost so far: %.1f kg
- Days active: %d
- Milestones: %v

Write ONE paragraph in %s, 40-80 words (or ~120 characters for Chinese). Name the numbers, acknowledge the delta, point forward. No bullet list, no preamble.`,
		req.CurrentWeight,
		req.TargetWeight,
		req.WeightLoss,
		req.DaysActive,
		req.Achievements,
		languageName(req.Locale),
	)

	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — encouragement returns mock (debug mode)")
		return &GetEncouragementResponse{
			Message: fmt.Sprintf("Day %d in, down %.1f kg. Pace looks sustainable — keep compounding.", req.DaysActive, req.WeightLoss),
			Suggestions: []string{
				"Hit 2.5 L water today to blunt hunger.",
				"Swap rice for extra greens at dinner to save ~200 kcal.",
				"10 min of mobility before bed to keep sleep quality up.",
			},
		}, nil
	}

	messages := []ChatMessage{
		{Role: "user", Content: prompt},
	}

	resp, err := s.callLLM(messages)
	if err != nil {
		s.logger.Error("LLM API call failed", zap.Error(err))
		return nil, err
	}

	return &GetEncouragementResponse{
		Message: resp.Content,
		Suggestions: []string{
			"Keep your current calorie deficit steady; don't cut deeper this week.",
			"Add one extra training session if sleep and recovery allow.",
			"Protect 7-8h sleep — recovery is half the cut.",
		},
	}, nil
}

func (s *AIService) Chat(req *ChatRequest) (*ChatResponse, error) {
	if len(req.Messages) == 0 {
		return nil, errors.New("messages cannot be empty")
	}
	// 只关心本轮的 user message（客户端可能重复发全量历史，但后端自己从 DB 拼更可靠）
	last := req.Messages[len(req.Messages)-1]
	if last.Role != "user" || last.Content == "" {
		return nil, errors.New("last message must be non-empty user message")
	}

	// [1] 存入用户消息
	userMsg := &models.AIChatMessage{
		UserID:   req.UserID,
		Role:     "user",
		Content:  last.Content,
		ThreadID: req.ThreadID,
	}
	if err := s.db.Create(userMsg).Error; err != nil {
		s.logger.Error("failed to save user message", zap.Error(err))
	} else {
		s.embedMessageAsync(userMsg.ID, userMsg.Content)
	}

	// 自动设标题：如果 thread 标题是空或默认值，用第一条消息当标题（截 20 字）
	s.maybeAutoTitleThread(req.ThreadID, last.Content)

	// [2] mock 模式早退
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — chat returning mock (debug mode)")
		return s.saveAssistantReply(req.UserID, req.ThreadID, "Hey, I'm your RecompDaily coach. What's the plan today — track food, review training, or sort out your macros?")
	}

	// [3] 组装完整上下文
	messages, err := s.assembleChatMessages(req.UserID, req.ThreadID, last.Content, languageName(req.Locale), ResolveLocation(req.Tz))
	if err != nil {
		s.logger.Error("assemble chat context failed", zap.Error(err))
		return nil, err
	}

	// [4] 调 LLM
	resp, err := s.callLLM(messages)
	if err != nil {
		s.logger.Error("LLM API call failed", zap.Error(err))
		return nil, err
	}

	// [5] 存 assistant 回复 + 触发后台任务
	out, err := s.saveAssistantReply(req.UserID, req.ThreadID, resp.Content)
	if err != nil {
		return nil, err
	}
	go s.maybeTriggerBackgroundTasks(req.UserID, req.ThreadID)
	return out, nil
}

// saveAssistantReply: 持久化助手消息，异步写 embedding，返回 response。
func (s *AIService) saveAssistantReply(userID uint, threadID, content string) (*ChatResponse, error) {
	m := &models.AIChatMessage{
		UserID:   userID,
		Role:     "assistant",
		Content:  content,
		ThreadID: threadID,
	}
	if err := s.db.Create(m).Error; err != nil {
		s.logger.Error("failed to save assistant message", zap.Error(err))
		return nil, err
	}
	s.embedMessageAsync(m.ID, m.Content)
	return &ChatResponse{
		MessageID: m.ID,
		Role:      "assistant",
		Content:   m.Content,
		ThreadID:  threadID,
	}, nil
}

// assembleChatMessages: assembles the layered memory context into the
// messages array sent to the LLM. `lang` is the target language name
// (English / Simplified Chinese / ...) that the system prompt forces.
// `loc` decides the day boundary for the "eaten today / yesterday at a
// glance" lines — pass the client's IANA tz, or time.UTC for back-compat.
func (s *AIService) assembleChatMessages(userID uint, threadID, query, lang string, loc *time.Location) ([]ChatMessage, error) {
	messages := []ChatMessage{
		{Role: "system", Content: s.buildSystemPrompt(userID, threadID, lang, loc)},
	}

	// 滑窗（含刚插入的 user 消息，要剔除——我们自己会把 query 放在末尾）
	recent := s.loadRecentMessages(userID, threadID, recentWindowSize+1) // +1 留给末尾 user
	// 丢掉末尾刚保存的那条（已经在 query 里）
	if n := len(recent); n > 0 && recent[n-1].Role == "user" && recent[n-1].Content == query {
		recent = recent[:n-1]
	}

	// RAG 检索：排除掉滑窗里已有的 msg id，避免双份
	excludeIDs := make([]uint, 0, len(recent))
	for _, m := range recent {
		excludeIDs = append(excludeIDs, m.ID)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	hits, err := s.searchRelevantMessages(ctx, userID, query, excludeIDs, retrievalTopK)
	if err != nil {
		// 检索失败不致命，只打日志
		s.logger.Warn("RAG search failed", zap.Error(err))
	}
	if len(hits) > 0 {
		var sb strings.Builder
		sb.WriteString("Relevant snippets retrieved from prior conversations (for your reference):\n")
		for _, h := range hits {
			sb.WriteString(fmt.Sprintf("- [%s · similarity %.2f] %s: %s\n",
				h.Msg.CreatedAt.Format("2006-01-02"),
				h.Similarity,
				h.Msg.Role, truncate(h.Msg.Content, 120)))
		}
		messages = append(messages, ChatMessage{Role: "system", Content: sb.String()})
	}

	// 最近原文
	for _, m := range recent {
		messages = append(messages, ChatMessage{Role: m.Role, Content: m.Content})
	}

	// 当前问题
	messages = append(messages, ChatMessage{Role: "user", Content: query})
	return messages, nil
}

func truncate(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n]) + "…"
}

func (s *AIService) callLLM(messages []ChatMessage) (*ChatMessage, error) {
	apiURL := s.llmAPIURL
	if apiURL == "" {
		apiURL = defaultGeminiURL
	}

	// 构建请求内容：Gemini 的 system 通过专门的 systemInstruction 字段传入，
	// contents 里 role 只能是 "user" / "model"。
	var contents []map[string]interface{}
	var systemTexts []string
	for _, msg := range messages {
		if msg.Role == "system" {
			systemTexts = append(systemTexts, msg.Content)
			continue
		}
		role := "user"
		if msg.Role == "assistant" {
			role = "model"
		}
		contents = append(contents, map[string]interface{}{
			"role":  role,
			"parts": []map[string]string{{"text": msg.Content}},
		})
	}

	genConfig := map[string]interface{}{
		"temperature":     0.7,
		"maxOutputTokens": maxOutputTokensForChat(apiURL),
	}
	// 关 thinking — Flash 默认开 thinking 会多花 3-5s，短任务（parse / estimate /
	// encourage）和普通 chat 不需要。Pro 是 thinking-only 模型，budget 0 会被拒，
	// 所以只对 Flash/Lite 显式关 thinking，Pro 走默认（dynamic）。
	if !isThinkingOnlyModel(apiURL) {
		genConfig["thinkingConfig"] = map[string]interface{}{"thinkingBudget": 0}
	}
	payload := map[string]interface{}{
		"contents":         contents,
		"generationConfig": genConfig,
	}
	if len(systemTexts) > 0 {
		payload["systemInstruction"] = map[string]interface{}{
			"parts": []map[string]string{{"text": strings.Join(systemTexts, "\n\n")}},
		}
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	client := &http.Client{Timeout: 60 * time.Second}
	url := fmt.Sprintf("%s?key=%s", apiURL, s.llmAPIKey)
	httpReq, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("failed to call LLM API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("LLM API error: %d, body: %s", resp.StatusCode, string(body))
	}

	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	var result struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
			FinishReason string `json:"finishReason"`
		} `json:"candidates"`
		PromptFeedback map[string]interface{} `json:"promptFeedback,omitempty"`
		UsageMetadata  map[string]interface{} `json:"usageMetadata,omitempty"`
	}

	if err := json.Unmarshal(rawBody, &result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// 拼所有 part 的 text（Pro thinking 可能拆多个 part，比如先 thought-only
	// 后真文本；只取 Parts[0].Text 会漏字）。
	if len(result.Candidates) > 0 {
		var sb strings.Builder
		for _, p := range result.Candidates[0].Content.Parts {
			sb.WriteString(p.Text)
		}
		if sb.Len() > 0 {
			return &ChatMessage{Role: "assistant", Content: sb.String()}, nil
		}
	}

	// 走到这里 = Gemini 返了 200 但没文字内容。把元信息记下来，便于
	// 区分 MAX_TOKENS / SAFETY / RECITATION / 全 thinking 没出文字 等情况。
	finishReason := ""
	if len(result.Candidates) > 0 {
		finishReason = result.Candidates[0].FinishReason
	}
	s.logger.Warn("LLM returned no text",
		zap.Int("candidates", len(result.Candidates)),
		zap.String("finishReason", finishReason),
		zap.Any("promptFeedback", result.PromptFeedback),
		zap.Any("usage", result.UsageMetadata),
		zap.String("rawBody", truncate(string(rawBody), 1500)))
	return nil, errors.New("no response from LLM")
}

// callLLMStream: 调 Gemini streamGenerateContent?alt=sse，按增量文本往 channel 里喂。
// channel 关闭意味着 stream 结束（正常或错误，Err 字段里带信息）。
//
// Tool calling 循环：每一轮 streamGenerate 出来的 functionCall 集中收齐，
// 后端本地执行（落库、emit action chunk），然后把 model 的 functionCall +
// 我们的 functionResponse 拼回 contents，再发下一轮，直到 model 不再调工具
// 或达到 maxToolIterations 上限。
func (s *AIService) callLLMStream(ctx context.Context, userID uint, tz string, messages []ChatMessage) (<-chan StreamChunk, error) {
	apiURL := s.llmAPIURL
	if apiURL == "" {
		apiURL = defaultGeminiURL
	}
	streamURL := strings.Replace(apiURL, ":generateContent", ":streamGenerateContent", 1)

	var contents []map[string]interface{}
	var systemTexts []string
	for _, msg := range messages {
		if msg.Role == "system" {
			systemTexts = append(systemTexts, msg.Content)
			continue
		}
		role := "user"
		if msg.Role == "assistant" {
			role = "model"
		}
		contents = append(contents, map[string]interface{}{
			"role":  role,
			"parts": []map[string]interface{}{{"text": msg.Content}},
		})
	}

	out := make(chan StreamChunk, 16)
	go func() {
		defer close(out)
		for iter := 0; iter < maxToolIterations; iter++ {
			calls, err := s.streamOneTurn(ctx, streamURL, contents, systemTexts, out)
			if err != nil {
				select {
				case out <- StreamChunk{Error: err.Error()}:
				case <-ctx.Done():
				}
				return
			}
			if len(calls) == 0 {
				return
			}
			// 把 model 的 functionCall part 拼成一条 model 消息。
			// Pro thinking 模型要求 thoughtSignature 原样回传，否则 400。
			modelParts := make([]map[string]interface{}, 0, len(calls))
			for _, c := range calls {
				part := map[string]interface{}{
					"functionCall": map[string]interface{}{
						"name": c.Name,
						"args": c.Args,
					},
				}
				if c.Signature != "" {
					part["thoughtSignature"] = c.Signature
				}
				modelParts = append(modelParts, part)
			}
			contents = append(contents, map[string]interface{}{
				"role":  "model",
				"parts": modelParts,
			})

			// 逐个执行 + 把结果拼成一条 user 消息（functionResponse parts）
			respParts := make([]map[string]interface{}, 0, len(calls))
			for _, c := range calls {
				result, actionChunk, err := s.executeTool(userID, tz, c)
				if err != nil {
					s.logger.Warn("tool execution failed",
						zap.String("tool", c.Name), zap.Error(err))
				}
				if actionChunk != nil {
					select {
					case out <- *actionChunk:
					case <-ctx.Done():
						return
					}
				}
				respParts = append(respParts, map[string]interface{}{
					"functionResponse": map[string]interface{}{
						"name":     c.Name,
						"response": result,
					},
				})
			}
			contents = append(contents, map[string]interface{}{
				"role":  "user",
				"parts": respParts,
			})
		}
		// 兜底：到达迭代上限还在调工具，强制收尾。
		s.logger.Warn("tool loop hit max iterations", zap.Int("max", maxToolIterations))
	}()
	return out, nil
}

// streamOneTurn 发一次 streamGenerateContent 请求。文本 delta 直接转发到 out，
// 收到的 functionCall 不转发，而是聚合返回给调用方决定下一步。
func (s *AIService) streamOneTurn(
	ctx context.Context,
	streamURL string,
	contents []map[string]interface{},
	systemTexts []string,
	out chan<- StreamChunk,
) ([]toolCall, error) {
	genConfig := map[string]interface{}{
		"temperature":     0.7,
		"maxOutputTokens": maxOutputTokensForChat(streamURL),
	}
	// 关 thinking：Flash 默认开 thinking 要多花 3-5s 才出首字。Pro 是 thinking-only
	// 模型，budget 0 会 400，所以只对非 Pro 模型显式关 thinking。
	if !isThinkingOnlyModel(streamURL) {
		genConfig["thinkingConfig"] = map[string]interface{}{"thinkingBudget": 0}
	}
	payload := map[string]interface{}{
		"contents": contents,
		"tools": []map[string]interface{}{
			{"function_declarations": s.toolDeclarations()},
		},
		"generationConfig": genConfig,
	}
	if len(systemTexts) > 0 {
		payload["systemInstruction"] = map[string]interface{}{
			"parts": []map[string]string{{"text": strings.Join(systemTexts, "\n\n")}},
		}
	}
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	url := fmt.Sprintf("%s?key=%s&alt=sse", streamURL, s.llmAPIKey)
	httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("stream request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("LLM stream API %d: %s", resp.StatusCode, string(body))
	}

	var calls []toolCall
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		data := strings.TrimPrefix(line, "data: ")
		if data == "" || data == "[DONE]" {
			continue
		}
		var parsed struct {
			Candidates []struct {
				Content struct {
					Parts []struct {
						Text             string `json:"text,omitempty"`
						ThoughtSignature string `json:"thoughtSignature,omitempty"`
						FunctionCall     *struct {
							Name string                 `json:"name"`
							Args map[string]interface{} `json:"args"`
						} `json:"functionCall,omitempty"`
					} `json:"parts"`
				} `json:"content"`
			} `json:"candidates"`
		}
		if err := json.Unmarshal([]byte(data), &parsed); err != nil {
			s.logger.Warn("stream chunk parse", zap.Error(err))
			continue
		}
		for _, cand := range parsed.Candidates {
			for _, part := range cand.Content.Parts {
				if part.FunctionCall != nil && part.FunctionCall.Name != "" {
					calls = append(calls, toolCall{
						Name:      part.FunctionCall.Name,
						Args:      part.FunctionCall.Args,
						Signature: part.ThoughtSignature,
					})
					continue
				}
				if part.Text == "" {
					continue
				}
				select {
				case out <- StreamChunk{Delta: part.Text}:
				case <-ctx.Done():
					return calls, ctx.Err()
				}
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return calls, err
	}
	return calls, nil
}

// ChatStream: 流式版 Chat。客户端收到的 chunks:
//   - 多个 {delta: "片段"}
//   - 最后一个 {done: true, message_id: N}
//
// 出错时最后一帧带 error 字段。
func (s *AIService) ChatStream(ctx context.Context, req *ChatRequest) (<-chan StreamChunk, error) {
	if len(req.Messages) == 0 {
		return nil, errors.New("messages cannot be empty")
	}
	last := req.Messages[len(req.Messages)-1]
	if last.Role != "user" || last.Content == "" {
		return nil, errors.New("last message must be non-empty user message")
	}

	// 存用户消息（和 Chat 一致）
	userMsg := &models.AIChatMessage{
		UserID:   req.UserID,
		Role:     "user",
		Content:  last.Content,
		ThreadID: req.ThreadID,
	}
	if err := s.db.Create(userMsg).Error; err != nil {
		s.logger.Error("save user message failed", zap.Error(err))
	} else {
		s.embedMessageAsync(userMsg.ID, userMsg.Content)
	}
	s.maybeAutoTitleThread(req.ThreadID, last.Content)

	// mock 降级
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		out := make(chan StreamChunk, 2)
		go func() {
			defer close(out)
			text := "Hey, I'm your RecompDaily coach. What's the plan today — track food, review training, or sort out your macros?"
			out <- StreamChunk{Delta: text}
			m := &models.AIChatMessage{
				UserID: req.UserID, Role: "assistant",
				Content: text, ThreadID: req.ThreadID,
			}
			_ = s.db.Create(m).Error
			out <- StreamChunk{Done: true, MessageID: m.ID}
		}()
		return out, nil
	}

	messages, err := s.assembleChatMessages(req.UserID, req.ThreadID, last.Content, languageName(req.Locale), ResolveLocation(req.Tz))
	if err != nil {
		return nil, err
	}

	upstream, err := s.callLLMStream(ctx, req.UserID, req.Tz, messages)
	if err != nil {
		return nil, err
	}

	out := make(chan StreamChunk, 16)
	go func() {
		defer close(out)
		var sb strings.Builder
		// 捕捉最后一次 action 贴到落库消息上。MVP 只做单工具，
		// 多工具同回合极少见，先取最后一次。
		var lastActionKind, lastActionPayload string
		for chunk := range upstream {
			if chunk.Error != "" {
				select {
				case out <- chunk:
				case <-ctx.Done():
				}
				return
			}
			if chunk.Action != "" {
				lastActionKind = chunk.Action
				lastActionPayload = chunk.ActionPayload
				select {
				case out <- chunk:
				case <-ctx.Done():
					return
				}
				continue
			}
			if chunk.Delta != "" {
				sb.WriteString(chunk.Delta)
				select {
				case out <- chunk:
				case <-ctx.Done():
					return
				}
			}
		}
		full := sb.String()
		// 即便 model 没产生任何文本（罕见：只调工具直接结束），
		// 仍要落库一条 assistant 占位，以便历史能渲染卡片。
		if full == "" && lastActionKind == "" {
			select {
			case out <- StreamChunk{Done: true, Error: "LLM returned empty response"}:
			case <-ctx.Done():
			}
			return
		}
		m := &models.AIChatMessage{
			UserID: req.UserID, Role: "assistant",
			Content: full, ThreadID: req.ThreadID,
			ActionKind:    lastActionKind,
			ActionPayload: lastActionPayload,
		}
		if err := s.db.Create(m).Error; err != nil {
			s.logger.Error("save assistant message failed", zap.Error(err))
			select {
			case out <- StreamChunk{Done: true, Error: "failed to save assistant message"}:
			case <-ctx.Done():
			}
			return
		}
		s.embedMessageAsync(m.ID, m.Content)
		go s.maybeTriggerBackgroundTasks(req.UserID, req.ThreadID)
		select {
		case out <- StreamChunk{Done: true, MessageID: m.ID}:
		case <-ctx.Done():
		}
	}()
	return out, nil
}

// fetchImageAsBase64 支持两种输入：
//   - data URL：data:image/jpeg;base64,<payload>  → 直接拆出来
//   - http(s) URL：用 HTTP GET 抓下来，探测/取 Content-Type 后 base64
func fetchImageAsBase64(imageURL string) (mimeType string, b64 string, err error) {
	if strings.HasPrefix(imageURL, "data:") {
		// data:<mime>;base64,<data>
		comma := strings.Index(imageURL, ",")
		if comma < 0 {
			return "", "", errors.New("invalid data URL: 没有逗号")
		}
		header := imageURL[5:comma]
		data := imageURL[comma+1:]
		// header 形如 "image/jpeg;base64"
		mime := header
		if idx := strings.Index(header, ";"); idx >= 0 {
			mime = header[:idx]
		}
		if mime == "" {
			mime = "image/jpeg"
		}
		return mime, data, nil
	}
	// 走 HTTP 抓
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(imageURL)
	if err != nil {
		return "", "", fmt.Errorf("fetch image: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("fetch image: HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", "", fmt.Errorf("read image body: %w", err)
	}
	mime := resp.Header.Get("Content-Type")
	if mime == "" {
		mime = http.DetectContentType(body)
	}
	return mime, base64.StdEncoding.EncodeToString(body), nil
}

func (s *AIService) SaveUserMessage(userID uint, content, threadID string) (*models.AIChatMessage, error) {
	msg := &models.AIChatMessage{
		UserID:   userID,
		Role:     "user",
		Content:  content,
		ThreadID: threadID,
	}

	if err := s.db.Create(msg).Error; err != nil {
		s.logger.Error("failed to save user message", zap.Error(err))
		return nil, err
	}

	return msg, nil
}

// ListUserFacts 返回某用户在 user_facts 表里的全部事实（AI 长期记忆）
func (s *AIService) ListUserFacts(userID uint) ([]models.UserFact, error) {
	var facts []models.UserFact
	if err := s.db.Where("user_id = ?", userID).
		Order("confidence DESC, updated_at DESC").
		Find(&facts).Error; err != nil {
		return nil, err
	}
	return facts, nil
}

// DeleteUserFact 删除单条事实（用户手动管理记忆）
func (s *AIService) DeleteUserFact(id uint) error {
	return s.db.Delete(&models.UserFact{}, id).Error
}

// GetChatHistory returns messages in chronological (ASC) order.
//
// Two query shapes:
//   - sinceID > 0 : delta fetch. "Messages newer than the caller's cursor."
//     ORDER BY created_at ASC, natural limit — the caller just wants the gap
//     filled in.
//   - sinceID == 0 : initial fetch. "Give me the tail of the conversation."
//     We want the LAST N messages, not the first N — otherwise a fresh
//     client (e.g. brand-new install) on a long thread would open to the
//     oldest 50 messages and miss the whole recent context. We query
//     ORDER BY id DESC LIMIT N and then reverse the slice before returning,
//     so the caller still receives ASC order (the API contract clients rely
//     on for rendering + for computing their own since_id cursor).
func (s *AIService) GetChatHistory(userID uint, threadID string, limit int, sinceID uint) ([]models.AIChatMessage, error) {
	var messages []models.AIChatMessage
	query := s.db.Where("user_id = ? AND thread_id = ?", userID, threadID)

	if sinceID > 0 {
		query = query.Where("id > ?", sinceID).Order("created_at ASC")
	} else {
		query = query.Order("id DESC")
	}

	if limit > 0 {
		query = query.Limit(limit)
	}

	if err := query.Find(&messages).Error; err != nil {
		s.logger.Error("failed to get chat history", zap.Error(err))
		return nil, err
	}

	if sinceID == 0 {
		for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
			messages[i], messages[j] = messages[j], messages[i]
		}
	}

	return messages, nil
}

func (s *AIService) CreateChatThread(userID uint, title string) (*models.AIChatThread, error) {
	thread := &models.AIChatThread{
		UserID: userID,
		Title:  title,
	}

	if err := s.db.Create(thread).Error; err != nil {
		s.logger.Error("failed to create chat thread", zap.Error(err))
		return nil, err
	}

	return thread, nil
}

// UpdateChatThreadTitle 允许客户端重命名线程
func (s *AIService) UpdateChatThreadTitle(id uint, title string) error {
	return s.db.Model(&models.AIChatThread{}).Where("id = ?", id).
		Update("title", title).Error
}

// DeleteChatThread 删除线程 + 其下所有消息
func (s *AIService) DeleteChatThread(id uint) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		threadIDStr := fmt.Sprintf("%d", id)
		if err := tx.Where("thread_id = ?", threadIDStr).
			Delete(&models.AIChatMessage{}).Error; err != nil {
			return err
		}
		return tx.Delete(&models.AIChatThread{}, id).Error
	})
}

// maybeAutoTitleThread: derive a title from the first user message.
// Only replaces the title if it's empty or the client's default placeholder
// ("New chat" / legacy "新对话").
func (s *AIService) maybeAutoTitleThread(threadID, firstUserMsg string) {
	if threadID == "" || firstUserMsg == "" {
		return
	}
	var t models.AIChatThread
	if err := s.db.Where("id = ? OR title = ?", threadID, threadID).
		First(&t).Error; err != nil {
		return
	}
	if t.Title != "" && t.Title != "New chat" && t.Title != "新对话" {
		return
	}
	title := strings.ReplaceAll(firstUserMsg, "\n", " ")
	r := []rune(title)
	if len(r) > 40 {
		title = string(r[:40]) + "…"
	}
	s.db.Model(&t).Update("title", title)
}

func (s *AIService) GetUserThreads(userID uint) ([]models.AIChatThread, error) {
	var threads []models.AIChatThread
	if err := s.db.Where("user_id = ?", userID).Order("updated_at DESC").Find(&threads).Error; err != nil {
		s.logger.Error("failed to get user threads", zap.Error(err))
		return nil, err
	}

	return threads, nil
}
