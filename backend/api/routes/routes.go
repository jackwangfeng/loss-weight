package routes

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"go.uber.org/zap"
)

// SetupUserRoutes sets up user-related routes
func SetupUserRoutes(rg *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	router := rg.Group("/users")
	{
		router.POST("/profile", CreateUserProfile(db, logger))
		router.GET("/profile", GetUserProfile(db, logger))
		router.PUT("/profile", UpdateUserProfile(db, logger))
	}
}

// SetupFoodRoutes sets up food-related routes
func SetupFoodRoutes(rg *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	router := rg.Group("/food")
	{
		router.POST("/recognize", RecognizeFood(db, logger))
		router.POST("/records", AddFoodRecord(db, logger))
		router.GET("/records/today", GetTodayFoodRecords(db, logger))
	}
}

// SetupWeightRoutes sets up weight-related routes
func SetupWeightRoutes(rg *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	router := rg.Group("/weight")
	{
		router.POST("/records", AddWeightRecord(db, logger))
		router.GET("/records", GetWeightRecords(db, logger))
	}
}

// SetupAIRoutes sets up AI-related routes
func SetupAIRoutes(rg *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	router := rg.Group("/ai")
	{
		router.POST("/encouragement", GetEncouragement(db, logger))
		router.POST("/chat", ChatWithAI(db, logger))
	}
}
