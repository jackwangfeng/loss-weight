package main

import (
	"flag"
	"fmt"
	"log"
	"time"

	sentry "github.com/getsentry/sentry-go"
	sentrygin "github.com/getsentry/sentry-go/gin"
	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/auth"
	"github.com/your-org/loss-weight/backend/internal/config"
	"github.com/your-org/loss-weight/backend/internal/database"
	"github.com/your-org/loss-weight/backend/internal/middleware"
	"github.com/your-org/loss-weight/backend/internal/models"
	"github.com/your-org/loss-weight/backend/internal/routes"
	"go.uber.org/zap"
)

func main() {
	// Parse command line flags
	configPath := flag.String("config", "config", "config file path")
	flag.Parse()

	// Load configuration
	cfg, err := config.Load(*configPath)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize logger
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	// Initialize Sentry — only if DSN is present. Missing DSN means the
	// local dev workflow doesn't ping Sentry and doesn't need the account.
	if cfg.SentryDSN != "" {
		if err := sentry.Init(sentry.ClientOptions{
			Dsn:              cfg.SentryDSN,
			Environment:      cfg.Environment,
			Release:          cfg.Version,
			TracesSampleRate: 0.0, // off — errors only, perf tracing costs quota fast.
		}); err != nil {
			logger.Error("sentry init failed", zap.Error(err))
		} else {
			logger.Info("sentry enabled", zap.String("env", cfg.Environment))
			defer sentry.Flush(2 * time.Second)
		}
	}

	// Initialize database
	db, err := database.Initialize(cfg.DatabaseURL)
	if err != nil {
		logger.Fatal("Failed to initialize database", zap.Error(err))
	}

	// Auto migrate models
	if err := database.Migrate(db,
		&models.UserProfile{},
		&models.UserSettings{},
		&models.FoodRecord{},
		&models.WeightRecord{},
		&models.ExerciseRecord{},
		&models.AIChatMessage{},
		&models.AIChatThread{},
		&models.UserFact{},
		&models.DailySummary{},
		&models.SMSCode{},
		&models.UserAccount{},
		&models.Feedback{},
	); err != nil {
		logger.Fatal("Failed to migrate database", zap.Error(err))
	}

	// Set Gin mode
	if !cfg.Debug {
		gin.SetMode(gin.ReleaseMode)
	}

	// Create Gin router
	r := gin.Default()

	// Apply middleware
	r.Use(middleware.CORS())
	r.Use(middleware.Logger(logger))
	r.Use(middleware.Recovery(logger))
	if cfg.SentryDSN != "" {
		// Must sit AFTER Recovery so panics are caught by our logger first,
		// then Sentry's middleware captures the event. Repanic:true preserves
		// existing panic-logging behavior.
		r.Use(sentrygin.New(sentrygin.Options{Repanic: true}))
	}

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status": "healthy",
		})
	})

	// API v1 routes
	v1 := r.Group("/v1")
	{
		tokens := auth.NewTokenIssuer(cfg.SecretKey, cfg.JWTExpireDays)
		routes.SetupAuthRoutes(v1, db, logger, cfg.GoogleClientID, cfg.GoogleIOSClientID, tokens)
		routes.SetupUserRoutes(v1, db, logger)
		routes.SetupFoodRoutes(v1, db, logger)
		routes.SetupWeightRoutes(v1, db, logger)
		routes.SetupExerciseRoutes(v1, db, logger)
		routes.SetupAIRoutes(v1, db, logger, cfg)
		routes.SetupFeedbackRoutes(v1, db, logger)
	}

	// Start server
	addr := fmt.Sprintf(":%d", cfg.Port)
	logger.Info("Starting server", zap.String("address", addr))

	if err := r.Run(addr); err != nil {
		logger.Fatal("Failed to start server", zap.Error(err))
	}
}
