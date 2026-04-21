package services

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

// Gemini 默认端点（gemini-pro 已被 Google 下线）。可通过 config 的
// gemini_api_url / vision_api_url 覆盖。
const defaultGeminiURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

// errLLMNotConfigured 当 debug=false 且 LLM key 缺失时返回。
var errLLMNotConfigured = errors.New("LLM 未配置：请设置 GEMINI_API_KEY 环境变量，或在 debug 模式下启动以使用 mock")

type AIService struct {
	db           *gorm.DB
	logger       *zap.Logger
	llmAPIKey    string
	llmAPIURL    string
	visionAPIKey string
	visionAPIURL string
	// allowMock 为 true 时，缺失 LLM key 会降级到写死的 mock 响应；
	// 为 false（生产）时 hard fail，避免静默兜底骗调用方。
	allowMock bool
}

func NewAIService(db *gorm.DB, logger *zap.Logger, llmAPIKey, llmAPIURL, visionAPIKey, visionAPIURL string, allowMock bool) *AIService {
	return &AIService{
		db:           db,
		logger:       logger,
		llmAPIKey:    llmAPIKey,
		llmAPIURL:    llmAPIURL,
		visionAPIKey: visionAPIKey,
		visionAPIURL: visionAPIURL,
		allowMock:    allowMock,
	}
}

type RecognizeFoodRequest struct {
	ImageURL string `json:"image_url" binding:"required"`
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
	Text string `json:"text" binding:"required"`
}

type GetEncouragementRequest struct {
	UserID        uint    `json:"user_id" binding:"required"`
	CurrentWeight float32 `json:"current_weight"`
	TargetWeight  float32 `json:"target_weight"`
	WeightLoss    float32 `json:"weight_loss"`
	DaysActive    int     `json:"days_active"`
	Achievements  []string `json:"achievements"`
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
	UserID     uint          `json:"user_id" binding:"required"`
	Messages   []ChatMessage `json:"messages" binding:"required"`
	ThreadID   string        `json:"thread_id"`
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
		s.logger.Warn("vision API not configured — 返回 mock（debug 模式）")
		return &RecognizeFoodResponse{
			FoodName:      "测试食物",
			Calories:      300,
			Protein:       15,
			Carbohydrates: 40,
			Fat:           10,
			Fiber:         5,
			Confidence:    0.95,
		}, nil
	}

	// 把 image URL / data URL 统一转成 base64 + mime，Gemini 只接 inline_data
	mimeType, b64, err := fetchImageAsBase64(req.ImageURL)
	if err != nil {
		s.logger.Error("failed to fetch image", zap.Error(err))
		return nil, fmt.Errorf("获取图片失败: %w", err)
	}

	prompt := `请分析这张食物图片，返回以下格式的信息（只返回 JSON，不要其他内容）：
{
  "food_name": "食物名称",
  "calories": 热量数值(每100克，千卡),
  "protein": 蛋白质含量(每100克，克),
  "carbohydrates": 碳水化合物(每100克，克),
  "fat": 脂肪含量(每100克，克),
  "fiber": 膳食纤维(每100克，克),
  "confidence": 识别置信度(0-1)
}

请只返回 JSON 格式，不要包含其他文字。`

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
			"temperature":     0.3,
			"maxOutputTokens": 500,
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

	if err := json.Unmarshal([]byte(responseText), &foodInfo); err != nil {
		s.logger.Error("failed to parse food info JSON", zap.Error(err))
		// 如果解析失败，返回默认结构
		return &RecognizeFoodResponse{
			FoodName:      "未知食物",
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
func (s *AIService) EstimateNutritionFromText(text string) (*RecognizeFoodResponse, error) {
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — estimate-nutrition 返回 mock（debug 模式）")
		return &RecognizeFoodResponse{
			FoodName: text, Calories: 300, Protein: 15,
			Carbohydrates: 40, Fat: 10, Fiber: 5, Confidence: 0.5,
		}, nil
	}

	prompt := fmt.Sprintf(`根据以下食物描述估算营养素。严格只返回 JSON，不要 markdown 代码块，不要其他文字。

描述：%s

JSON 格式：
{
  "food_name": "简洁的食物名",
  "calories": 总热量(千卡),
  "protein": 蛋白质(克),
  "carbohydrates": 碳水化合物(克),
  "fat": 脂肪(克),
  "fiber": 膳食纤维(克),
  "confidence": 估算置信度(0-1)
}

注意：
- 如果描述含具体分量（如 200g / 一碗），按分量算总量；否则按一个标准份估算
- 数字不要带单位
- confidence: 描述越具体越高，越模糊越低`, text)

	resp, err := s.callLLM([]ChatMessage{{Role: "user", Content: prompt}})
	if err != nil {
		return nil, err
	}
	jsonText := stripMarkdownCodeFence(resp.Content)
	var out RecognizeFoodResponse
	if err := json.Unmarshal([]byte(jsonText), &out); err != nil {
		return nil, fmt.Errorf("解析 LLM 返回失败: %w (原文: %s)", err, resp.Content)
	}
	return &out, nil
}

func (s *AIService) GetEncouragement(req *GetEncouragementRequest) (*GetEncouragementResponse, error) {
	prompt := fmt.Sprintf(`你是一位专业的减肥鼓励助手。请根据以下用户情况，用温暖、鼓励的语气给用户写一段鼓励的话：

用户情况：
- 当前体重：%.1f kg
- 目标体重：%.1f kg
- 已减重：%.1f kg
- 坚持天数：%d 天
- 成就：%v

请：
1. 写一段 100-200 字的鼓励话语
2. 给出 2-3 条实用的建议`,
		req.CurrentWeight,
		req.TargetWeight,
		req.WeightLoss,
		req.DaysActive,
		req.Achievements,
	)

	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — encouragement 返回 mock（debug 模式）")
		return &GetEncouragementResponse{
			Message: fmt.Sprintf("太棒了！你已经坚持了 %d 天，减重 %.1f kg！继续保持，你一定能达成目标！💪", req.DaysActive, req.WeightLoss),
			Suggestions: []string{
				"今天记得多喝水，保持身体水分",
				"晚餐可以选择清淡的蔬菜沙拉",
				"睡前做 10 分钟拉伸，帮助睡眠",
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
			"保持当前的饮食节奏",
			"适当增加运动量",
			"保证充足睡眠",
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

	// [2] mock 模式早退
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — chat 返回 mock（debug 模式）")
		return s.saveAssistantReply(req.UserID, req.ThreadID, "你好！我是你的 AI 减肥助手。有什么我可以帮助你的吗？")
	}

	// [3] 组装完整上下文
	messages, err := s.assembleChatMessages(req.UserID, req.ThreadID, last.Content)
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

// assembleChatMessages: 把记忆的各层拼成给 LLM 的 messages 数组。
func (s *AIService) assembleChatMessages(userID uint, threadID, query string) ([]ChatMessage, error) {
	messages := []ChatMessage{
		{Role: "system", Content: s.buildSystemPrompt(userID, threadID)},
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
		sb.WriteString("以下是从过往对话中检索到的相关片段，供参考：\n")
		for _, h := range hits {
			sb.WriteString(fmt.Sprintf("- [%s · 相似度 %.2f] %s: %s\n",
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

	payload := map[string]interface{}{
		"contents": contents,
		"generationConfig": map[string]interface{}{
			"temperature":     0.7,
			"maxOutputTokens": 4096,
		},
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
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	if len(result.Candidates) == 0 || len(result.Candidates[0].Content.Parts) == 0 {
		return nil, errors.New("no response from LLM")
	}

	return &ChatMessage{
		Role:    "assistant",
		Content: result.Candidates[0].Content.Parts[0].Text,
	}, nil
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

func (s *AIService) GetChatHistory(userID uint, threadID string, limit int) ([]models.AIChatMessage, error) {
	var messages []models.AIChatMessage
	query := s.db.Where("user_id = ? AND thread_id = ?", userID, threadID)

	if limit > 0 {
		query = query.Limit(limit)
	}

	if err := query.Order("created_at ASC").Find(&messages).Error; err != nil {
		s.logger.Error("failed to get chat history", zap.Error(err))
		return nil, err
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

func (s *AIService) GetUserThreads(userID uint) ([]models.AIChatThread, error) {
	var threads []models.AIChatThread
	if err := s.db.Where("user_id = ?", userID).Order("updated_at DESC").Find(&threads).Error; err != nil {
		s.logger.Error("failed to get user threads", zap.Error(err))
		return nil, err
	}

	return threads, nil
}
