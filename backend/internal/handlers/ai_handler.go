package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
)

type AIHandler struct {
	service *services.AIService
	logger  *zap.Logger
}

func NewAIHandler(service *services.AIService, logger *zap.Logger) *AIHandler {
	return &AIHandler{
		service: service,
		logger:  logger,
	}
}

func (h *AIHandler) RecognizeFood(c *gin.Context) {
	var req services.RecognizeFoodRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
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

func (h *AIHandler) EstimateExercise(c *gin.Context) {
	var req services.EstimateExerciseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.service.EstimateExerciseFromText(req.Text)
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
	result, err := h.service.GetDailyBrief(req.UserID)
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
	result, err := h.service.EstimateNutritionFromText(req.Text)
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

	result, err := h.service.Chat(&req)
	if err != nil {
		h.logger.Error("failed to chat", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "AI 对话失败"})
		return
	}

	c.JSON(http.StatusOK, result)
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

	messages, err := h.service.GetChatHistory(uint(userID), threadID, limit)
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
