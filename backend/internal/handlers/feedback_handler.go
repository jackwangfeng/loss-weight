package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
)

type FeedbackHandler struct {
	service *services.FeedbackService
	logger  *zap.Logger
}

func NewFeedbackHandler(s *services.FeedbackService, logger *zap.Logger) *FeedbackHandler {
	return &FeedbackHandler{service: s, logger: logger}
}

func (h *FeedbackHandler) Submit(c *gin.Context) {
	var req services.CreateFeedbackRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid feedback payload", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	// Capture the user-agent as a device-info fallback if the client didn't
	// pass one — early Android builds used to drop the field.
	if req.DeviceInfo == "" {
		req.DeviceInfo = c.GetHeader("User-Agent")
	}
	fb, err := h.service.Create(&req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "提交反馈失败"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": fb.ID, "created_at": fb.CreatedAt})
}
