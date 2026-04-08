package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
)

type AuthHandler struct {
	service *services.AuthService
	logger  *zap.Logger
}

func NewAuthHandler(service *services.AuthService, logger *zap.Logger) *AuthHandler {
	return &AuthHandler{
		service: service,
		logger:  logger,
	}
}

type SendSMSRequest struct {
	Phone   string `json:"phone" binding:"required"`
	Purpose string `json:"purpose" binding:"required"`
}

type VerifySMSRequest struct {
	Phone string `json:"phone" binding:"required"`
	Code  string `json:"code" binding:"required"`
}

type PhoneLoginRequest struct {
	Phone string `json:"phone" binding:"required"`
	Code  string `json:"code" binding:"required"`
}

// 发送短信验证码
func (h *AuthHandler) SendSMS(c *gin.Context) {
	var req services.SendSMSRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.SendSMSCode(&req); err != nil {
		h.logger.Error("failed to send sms code", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "验证码已发送",
		"phone":   req.Phone,
	})
}

// 手机号登录
func (h *AuthHandler) PhoneLogin(c *gin.Context) {
	var req struct {
		Phone string `json:"phone" binding:"required"`
		Code  string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Error("failed to bind request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ip := c.ClientIP()
	resp, err := h.service.PhoneLogin(req.Phone, req.Code, ip)
	if err != nil {
		h.logger.Error("failed to login", zap.Error(err))
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token":      resp.Token,
		"user_id":    resp.UserID,
		"is_new_user": resp.IsNewUser,
		"account":    resp.Account,
	})
}

// 获取当前用户信息
func (h *AuthHandler) GetCurrentUser(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未登录"})
		return
	}

	account, err := h.service.GetAccountByID(userID.(uint))
	if err != nil {
		h.logger.Error("failed to get account", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户信息失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"account": account,
	})
}

// 退出登录
func (h *AuthHandler) Logout(c *gin.Context) {
	// TODO: 如果是 JWT token，可以加入黑名单
	// 简单实现：直接返回成功
	c.JSON(http.StatusOK, gin.H{
		"message": "退出成功",
	})
}
