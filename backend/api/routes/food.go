package routes

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"go.uber.org/zap"
)

// RecognizeFood godoc
// @Summary Recognize food from image
// @Tags food
// @Accept multipart/form-data
// @Produce json
// @Param image formData file true "Food image"
// @Success 200 {object} map[string]interface{}
// @Router /v1/food/recognize [post]
func RecognizeFood(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}

// AddFoodRecord godoc
// @Summary Add food record
// @Tags food
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/food/records [post]
func AddFoodRecord(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}

// GetTodayFoodRecords godoc
// @Summary Get today's food records
// @Tags food
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/food/records/today [get]
func GetTodayFoodRecords(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}
