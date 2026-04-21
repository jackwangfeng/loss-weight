package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
)

type ExerciseHandler struct {
	service *services.ExerciseService
	logger  *zap.Logger
}

func NewExerciseHandler(service *services.ExerciseService, logger *zap.Logger) *ExerciseHandler {
	return &ExerciseHandler{service: service, logger: logger}
}

func (h *ExerciseHandler) CreateRecord(c *gin.Context) {
	var req services.CreateExerciseRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	r, err := h.service.CreateRecord(&req)
	if err != nil {
		h.logger.Error("create exercise failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建运动记录失败"})
		return
	}
	c.JSON(http.StatusCreated, r)
}

func (h *ExerciseHandler) GetRecords(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 user_id"})
		return
	}
	var startDate, endDate time.Time
	if s := c.Query("start_date"); s != "" {
		startDate, _ = time.Parse("2006-01-02", s)
	}
	if s := c.Query("end_date"); s != "" {
		endDate, _ = time.Parse("2006-01-02", s)
		if !endDate.IsZero() {
			endDate = endDate.Add(24 * time.Hour)
		}
	}
	records, err := h.service.GetRecordsByUser(uint(userID), startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取运动记录失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"records": records, "count": len(records)})
}

func (h *ExerciseHandler) GetRecord(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 id"})
		return
	}
	r, err := h.service.GetRecordByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "记录不存在"})
		return
	}
	c.JSON(http.StatusOK, r)
}

func (h *ExerciseHandler) UpdateRecord(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 id"})
		return
	}
	var req services.UpdateExerciseRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	r, err := h.service.UpdateRecord(uint(id), &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新失败"})
		return
	}
	c.JSON(http.StatusOK, r)
}

func (h *ExerciseHandler) DeleteRecord(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 id"})
		return
	}
	if err := h.service.DeleteRecord(uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}

func (h *ExerciseHandler) GetDailySummary(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 user_id"})
		return
	}
	date := time.Now()
	if s := c.Query("date"); s != "" {
		if d, err := time.Parse("2006-01-02", s); err == nil {
			date = d
		}
	}
	summary, err := h.service.GetDailySummary(uint(userID), date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取汇总失败"})
		return
	}
	c.JSON(http.StatusOK, summary)
}
