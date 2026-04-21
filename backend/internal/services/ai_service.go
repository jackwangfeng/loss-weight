package services

import (
	"bytes"
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

	// 先把本轮用户问题入库（messages 数组的最后一条 user 消息就是新问题）
	if last := req.Messages[len(req.Messages)-1]; last.Role == "user" && last.Content != "" {
		userMsg := &models.AIChatMessage{
			UserID:   req.UserID,
			Role:     "user",
			Content:  last.Content,
			ThreadID: req.ThreadID,
		}
		if err := s.db.Create(userMsg).Error; err != nil {
			s.logger.Error("failed to save user message", zap.Error(err))
			// 继续，不阻断聊天
		}
	}

	var assistantContent string
	if s.llmAPIKey == "" {
		if !s.allowMock {
			return nil, errLLMNotConfigured
		}
		s.logger.Warn("LLM API not configured — chat 返回 mock（debug 模式）")
		assistantContent = "你好！我是你的 AI 减肥助手。有什么我可以帮助你的吗？"
	} else {
		resp, err := s.callLLM(req.Messages)
		if err != nil {
			s.logger.Error("LLM API call failed", zap.Error(err))
			return nil, err
		}
		assistantContent = resp.Content
	}

	dbMessage := &models.AIChatMessage{
		UserID:   req.UserID,
		Role:     "assistant",
		Content:  assistantContent,
		ThreadID: req.ThreadID,
	}

	if err := s.db.Create(dbMessage).Error; err != nil {
		s.logger.Error("failed to save assistant message", zap.Error(err))
		return nil, err
	}

	return &ChatResponse{
		MessageID: dbMessage.ID,
		Role:      "assistant",
		Content:   dbMessage.Content,
		ThreadID:  req.ThreadID,
	}, nil
}

func (s *AIService) callLLM(messages []ChatMessage) (*ChatMessage, error) {
	apiURL := s.llmAPIURL
	if apiURL == "" {
		apiURL = defaultGeminiURL
	}

	// 构建请求内容
	var contents []map[string]interface{}
	for _, msg := range messages {
		role := "user"
		if msg.Role == "assistant" {
			role = "model"
		}
		contents = append(contents, map[string]interface{}{
			"role": role,
			"parts": []map[string]string{
				{"text": msg.Content},
			},
		})
	}

	payload := map[string]interface{}{
		"contents": contents,
		"generationConfig": map[string]interface{}{
			"temperature":     0.7,
			"maxOutputTokens": 4096,
		},
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
