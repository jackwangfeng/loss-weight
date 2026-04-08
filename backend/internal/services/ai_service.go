package services

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

type AIService struct {
	db           *gorm.DB
	logger       *zap.Logger
	llmAPIKey    string
	llmAPIURL    string
	visionAPIKey string
	visionAPIURL string
}

func NewAIService(db *gorm.DB, logger *zap.Logger, llmAPIKey, llmAPIURL, visionAPIKey, visionAPIURL string) *AIService {
	return &AIService{
		db:           db,
		logger:       logger,
		llmAPIKey:    llmAPIKey,
		llmAPIURL:    llmAPIURL,
		visionAPIKey: visionAPIKey,
		visionAPIURL: visionAPIURL,
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
	// 使用 Gemini Pro Vision 进行食物识别
	apiURL := s.visionAPIURL
	if apiURL == "" {
		// 默认使用 Gemini Pro Vision API
		apiURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent"
	}

	apiKey := s.visionAPIKey
	if apiKey == "" {
		// 如果没有单独配置，使用 LLM API Key
		apiKey = s.llmAPIKey
	}

	if apiKey == "" {
		s.logger.Warn("vision API not configured, using mock response")
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

	// 构建 Gemini Vision 请求
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
					{
						"text": prompt,
					},
					{
						"image_url": map[string]string{
							"url": req.ImageURL,
						},
					},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"temperature":  0.3,
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

	if s.llmAPIURL == "" || s.llmAPIKey == "" {
		s.logger.Warn("LLM API not configured, using mock response")
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

	if s.llmAPIURL == "" || s.llmAPIKey == "" {
		s.logger.Warn("LLM API not configured, using mock response")
		mockMsg := &models.AIChatMessage{
			UserID:   req.UserID,
			Role:     "assistant",
			Content:  "你好！我是你的 AI 减肥助手。有什么我可以帮助你的吗？",
			ThreadID: req.ThreadID,
		}
		if err := s.db.Create(mockMsg).Error; err != nil {
			s.logger.Error("failed to save chat message", zap.Error(err))
		}
		return &ChatResponse{
			MessageID: mockMsg.ID,
			Role:      "assistant",
			Content:   mockMsg.Content,
			ThreadID:  req.ThreadID,
		}, nil
	}

	assistantMsg, err := s.callLLM(req.Messages)
	if err != nil {
		s.logger.Error("LLM API call failed", zap.Error(err))
		return nil, err
	}

	dbMessage := &models.AIChatMessage{
		UserID:   req.UserID,
		Role:     "assistant",
		Content:  assistantMsg.Content,
		ThreadID: req.ThreadID,
	}

	if err := s.db.Create(dbMessage).Error; err != nil {
		s.logger.Error("failed to save chat message", zap.Error(err))
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
	// 构建 Gemini API 请求
	// Gemini API URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent
	apiURL := s.llmAPIURL
	if apiURL == "" {
		apiURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
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
			"maxOutputTokens":  1000,
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
