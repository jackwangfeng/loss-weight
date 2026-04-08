package routes

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"go.uber.org/zap"
)

// CreateUserProfile godoc
// @Summary Create user profile
// @Tags users
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/users/profile [post]
func CreateUserProfile(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}

// GetUserProfile godoc
// @Summary Get user profile
// @Tags users
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/users/profile [get]
func GetUserProfile(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}

// UpdateUserProfile godoc
// @Summary Update user profile
// @Tags users
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/users/profile [put]
func UpdateUserProfile(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}
