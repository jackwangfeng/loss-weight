package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
)

type WeightHandler struct {
	service *services.WeightService
	logger  *zap.Logger
}

func NewWeightHandler(service *services.WeightService, logger *zap.Logger) *WeightHandler {
	return &WeightHandler{
		service: service,
		logger:  logger,
	}
}

func (h *WeightHandler) CreateRecord(c *gin.Context) {
	var req services.CreateWeightRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	record, err := h.service.CreateRecord(&req)
	if err != nil {
		h.logger.Error("failed to create weight record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建体重记录失败"})
		return
	}

	c.JSON(http.StatusCreated, record)
}

func (h *WeightHandler) GetRecords(c *gin.Context) {
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

	loc := services.ResolveLocation(c.Query("tz"))
	var startDate, endDate time.Time
	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	if startDateStr != "" {
		startDate, _ = time.ParseInLocation("2006-01-02", startDateStr, loc)
	}
	if endDateStr != "" {
		// Inclusive end-date in client tz → next-day midnight for half-open
		// query at the service layer.
		if d, err := time.ParseInLocation("2006-01-02", endDateStr, loc); err == nil {
			endDate = d.AddDate(0, 0, 1)
		}
	}

	records, err := h.service.GetRecordsByUser(uint(userID), startDate, endDate)
	if err != nil {
		h.logger.Error("failed to get weight records", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取体重记录失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"records": records,
		"count":   len(records),
	})
}

func (h *WeightHandler) GetRecord(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid weight record id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的体重记录 ID"})
		return
	}

	record, err := h.service.GetRecordByID(uint(id))
	if err != nil {
		h.logger.Error("failed to get weight record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取体重记录失败"})
		return
	}

	c.JSON(http.StatusOK, record)
}

func (h *WeightHandler) UpdateRecord(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid weight record id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的体重记录 ID"})
		return
	}

	var req services.UpdateWeightRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	record, err := h.service.UpdateRecord(uint(id), &req)
	if err != nil {
		h.logger.Error("failed to update weight record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新体重记录失败"})
		return
	}

	c.JSON(http.StatusOK, record)
}

func (h *WeightHandler) DeleteRecord(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid weight record id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的体重记录 ID"})
		return
	}

	if err := h.service.DeleteRecord(uint(id)); err != nil {
		h.logger.Error("failed to delete weight record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除体重记录失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}

func (h *WeightHandler) GetTrend(c *gin.Context) {
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

	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		h.logger.Error("invalid days parameter", zap.String("days", daysStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 days 参数"})
		return
	}

	records, err := h.service.GetWeightTrend(uint(userID), days)
	if err != nil {
		h.logger.Error("failed to get weight trend", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取体重趋势失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"records": records,
		"count":   len(records),
		"days":    days,
	})
}
