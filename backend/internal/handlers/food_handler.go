package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
)

type FoodHandler struct {
	service *services.FoodService
	logger  *zap.Logger
}

func NewFoodHandler(service *services.FoodService, logger *zap.Logger) *FoodHandler {
	return &FoodHandler{
		service: service,
		logger:  logger,
	}
}

func (h *FoodHandler) CreateRecord(c *gin.Context) {
	var req services.CreateFoodRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	record, err := h.service.CreateRecord(&req)
	if err != nil {
		h.logger.Error("failed to create food record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建食物记录失败"})
		return
	}

	c.JSON(http.StatusCreated, record)
}

func (h *FoodHandler) GetRecords(c *gin.Context) {
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

	var startDate, endDate time.Time
	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	if startDateStr != "" {
		startDate, _ = time.Parse("2006-01-02", startDateStr)
	}
	if endDateStr != "" {
		endDate, _ = time.Parse("2006-01-02", endDateStr)
	}

	records, err := h.service.GetRecordsByUser(uint(userID), startDate, endDate)
	if err != nil {
		h.logger.Error("failed to get food records", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取食物记录失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"records": records,
		"count":   len(records),
	})
}

func (h *FoodHandler) GetRecord(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid food record id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的食物记录 ID"})
		return
	}

	record, err := h.service.GetRecordByID(uint(id))
	if err != nil {
		h.logger.Error("failed to get food record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取食物记录失败"})
		return
	}

	c.JSON(http.StatusOK, record)
}

func (h *FoodHandler) UpdateRecord(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid food record id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的食物记录 ID"})
		return
	}

	var req services.UpdateFoodRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	record, err := h.service.UpdateRecord(uint(id), &req)
	if err != nil {
		h.logger.Error("failed to update food record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新食物记录失败"})
		return
	}

	c.JSON(http.StatusOK, record)
}

func (h *FoodHandler) DeleteRecord(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid food record id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的食物记录 ID"})
		return
	}

	if err := h.service.DeleteRecord(uint(id)); err != nil {
		h.logger.Error("failed to delete food record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除食物记录失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}

func (h *FoodHandler) GetDailySummary(c *gin.Context) {
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

	dateStr := c.Query("date")
	var date time.Time
	if dateStr != "" {
		date, _ = time.Parse("2006-01-02", dateStr)
	} else {
		date = time.Now()
	}

	summary, err := h.service.GetDailySummary(uint(userID), date)
	if err != nil {
		h.logger.Error("failed to get daily summary", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取每日总结失败"})
		return
	}

	c.JSON(http.StatusOK, summary)
}
