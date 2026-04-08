package routes

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"go.uber.org/zap"
)

// GetEncouragement godoc
// @Summary Get AI encouragement
// @Tags ai
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/ai/encouragement [post]
func GetEncouragement(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}

// ChatWithAI godoc
// @Summary Chat with AI assistant
// @Tags ai
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/ai/chat [post]
func ChatWithAI(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}
