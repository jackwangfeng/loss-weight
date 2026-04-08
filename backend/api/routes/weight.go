package routes

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"go.uber.org/zap"
)

// AddWeightRecord godoc
// @Summary Add weight record
// @Tags weight
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/weight/records [post]
func AddWeightRecord(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}

// GetWeightRecords godoc
// @Summary Get weight records
// @Tags weight
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/weight/records [get]
func GetWeightRecords(db *gorm.DB, logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: Implement
		c.JSON(http.StatusOK, gin.H{
			"code":    200,
			"message": "Not implemented yet",
		})
	}
}
