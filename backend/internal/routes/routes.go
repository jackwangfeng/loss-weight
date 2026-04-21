package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/config"
	"github.com/your-org/loss-weight/backend/internal/handlers"
	"github.com/your-org/loss-weight/backend/internal/middleware"
	"github.com/your-org/loss-weight/backend/internal/services"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

func SetupUserRoutes(v1 *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	userService := services.NewUserService(db, logger)
	userHandler := handlers.NewUserHandler(userService, logger)

	users := v1.Group("/users")
	{
		users.POST("/profile", userHandler.CreateProfile)
		users.GET("/profile/:id", userHandler.GetProfile)
		users.GET("/profile/openid/:openid", userHandler.GetProfileByOpenID)
		users.PUT("/profile/:id", userHandler.UpdateProfile)
		users.DELETE("/profile/:id", userHandler.DeleteProfile)
	}
}

func SetupFoodRoutes(v1 *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	foodService := services.NewFoodService(db, logger)
	foodHandler := handlers.NewFoodHandler(foodService, logger)

	food := v1.Group("/food")
	{
		food.POST("/record", foodHandler.CreateRecord)
		food.GET("/records", foodHandler.GetRecords)
		food.GET("/record/:id", foodHandler.GetRecord)
		food.PUT("/record/:id", foodHandler.UpdateRecord)
		food.DELETE("/record/:id", foodHandler.DeleteRecord)
		food.GET("/daily-summary", foodHandler.GetDailySummary)
	}
}

func SetupWeightRoutes(v1 *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	weightService := services.NewWeightService(db, logger)
	weightHandler := handlers.NewWeightHandler(weightService, logger)

	weight := v1.Group("/weight")
	{
		weight.POST("/record", weightHandler.CreateRecord)
		weight.GET("/records", weightHandler.GetRecords)
		weight.GET("/record/:id", weightHandler.GetRecord)
		weight.PUT("/record/:id", weightHandler.UpdateRecord)
		weight.DELETE("/record/:id", weightHandler.DeleteRecord)
		weight.GET("/trend", weightHandler.GetTrend)
	}
}

func SetupAIRoutes(v1 *gin.RouterGroup, db *gorm.DB, logger *zap.Logger, cfg *config.Config) {
	llmAPIKey := cfg.LLMAPIKey
	llmAPIURL := cfg.LLMAPIURL
	visionAPIKey := cfg.VisionAPIKey
	visionAPIURL := cfg.VisionAPIURL

	aiService := services.NewAIService(db, logger, llmAPIKey, llmAPIURL, visionAPIKey, visionAPIURL)
	aiHandler := handlers.NewAIHandler(aiService, logger)

	ai := v1.Group("/ai")
	{
		ai.POST("/recognize", aiHandler.RecognizeFood)
		ai.POST("/encouragement", aiHandler.GetEncouragement)
		ai.POST("/chat", aiHandler.Chat)
		ai.GET("/chat/history", aiHandler.GetChatHistory)
		ai.POST("/chat/thread", aiHandler.CreateThread)
		ai.GET("/chat/threads", aiHandler.GetUserThreads)
	}
}

func SetupAuthRoutes(v1 *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	authService := services.NewAuthService(db, logger)
	authHandler := handlers.NewAuthHandler(authService, logger)

	auth := v1.Group("/auth")
	{
		// 公开
		auth.POST("/sms/send", authHandler.SendSMS)
		auth.POST("/sms/login", authHandler.PhoneLogin)

		// 需鉴权
		protected := auth.Group("")
		protected.Use(middleware.AuthRequired())
		protected.GET("/me", authHandler.GetCurrentUser)
		protected.POST("/logout", authHandler.Logout)
	}
}
