package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
)

type UserHandler struct {
	service *services.UserService
	logger  *zap.Logger
}

func NewUserHandler(service *services.UserService, logger *zap.Logger) *UserHandler {
	return &UserHandler{
		service: service,
		logger:  logger,
	}
}

func (h *UserHandler) CreateProfile(c *gin.Context) {
	var req services.CreateUserProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	profile, err := h.service.CreateProfile(&req)
	if err != nil {
		h.logger.Error("failed to create profile", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建用户档案失败"})
		return
	}

	c.JSON(http.StatusCreated, profile)
}

func (h *UserHandler) GetProfile(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid user id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的用户 ID"})
		return
	}

	profile, err := h.service.GetProfileByID(uint(id))
	if err != nil {
		h.logger.Error("failed to get profile", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户档案失败"})
		return
	}

	if profile == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	c.JSON(http.StatusOK, profile)
}

func (h *UserHandler) GetProfileByOpenID(c *gin.Context) {
	openID := c.Param("openid")
	if openID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 openid 参数"})
		return
	}

	profile, err := h.service.GetProfileByOpenID(openID)
	if err != nil {
		h.logger.Error("failed to get profile by openid", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户档案失败"})
		return
	}

	if profile == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	c.JSON(http.StatusOK, profile)
}

func (h *UserHandler) UpdateProfile(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid user id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的用户 ID"})
		return
	}

	var req services.UpdateUserProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	profile, err := h.service.UpdateProfile(uint(id), &req)
	if err != nil {
		h.logger.Error("failed to update profile", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新用户档案失败"})
		return
	}

	if profile == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	c.JSON(http.StatusOK, profile)
}

func (h *UserHandler) DeleteProfile(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		h.logger.Error("invalid user id", zap.String("id", idStr))
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的用户 ID"})
		return
	}

	if err := h.service.DeleteProfile(uint(id)); err != nil {
		h.logger.Error("failed to delete profile", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除用户档案失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}
