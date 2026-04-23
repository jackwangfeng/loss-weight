package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/spf13/viper"
)

// Config holds application configuration
type Config struct {
	ProjectName    string
	Version        string
	APIPrefix      string
	Port           int
	Debug          bool
	DatabaseURL    string
	RedisURL       string
	SecretKey      string
	JWTExpireDays  int
	LLMAPIKey      string
	LLMAPIURL      string
	VisionAPIKey   string
	VisionAPIURL   string
	OpenAIKey       string
	BaiduCVKey      string
	ChromaURL          string
	GoogleClientID     string // OAuth 2.0 Web Client ID — audience for Google ID tokens (web/Android)
	GoogleIOSClientID  string // OAuth 2.0 iOS Client ID — iOS-native Google Sign-In returns tokens with this aud
}

// Load reads configuration from file and environment variables
func Load(configPath string) (*Config, error) {
	// Set default values
	viper.SetDefault("project_name", "Loss Weight AI")
	viper.SetDefault("version", "1.0.0")
	viper.SetDefault("api_prefix", "/v1")
	viper.SetDefault("port", 8000)
	viper.SetDefault("debug", true)
	viper.SetDefault("database_url", "postgresql://postgres:postgres@localhost:5432/lossweight")
	viper.SetDefault("redis_url", "redis://localhost:6379")
	viper.SetDefault("secret_key", "your-secret-key-change-in-production")
	viper.SetDefault("jwt_expire_days", 7)

	// Read config file
	viper.SetConfigName(configPath)
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")

	// Read environment variables
	viper.AutomaticEnv()

	// 显式绑定敏感 key 到环境变量（优先级高于 yaml）
	_ = viper.BindEnv("gemini_api_key", "GEMINI_API_KEY")
	_ = viper.BindEnv("gemini_api_url", "GEMINI_API_URL")
	_ = viper.BindEnv("vision_api_key", "VISION_API_KEY")
	_ = viper.BindEnv("vision_api_url", "VISION_API_URL")
	_ = viper.BindEnv("openai_api_key", "OPENAI_API_KEY")
	_ = viper.BindEnv("baidu_cv_api_key", "BAIDU_CV_API_KEY")
	_ = viper.BindEnv("secret_key", "SECRET_KEY")
	_ = viper.BindEnv("google_client_id", "GOOGLE_CLIENT_ID")
	_ = viper.BindEnv("google_ios_client_id", "GOOGLE_IOS_CLIENT_ID")

	// Try to read config file (optional)
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
	}

	// Build config from viper
	config := &Config{
		ProjectName:   viper.GetString("project_name"),
		Version:       viper.GetString("version"),
		APIPrefix:     viper.GetString("api_prefix"),
		Port:          viper.GetInt("port"),
		Debug:         viper.GetBool("debug"),
		DatabaseURL:   viper.GetString("database_url"),
		RedisURL:      viper.GetString("redis_url"),
		SecretKey:     viper.GetString("secret_key"),
		JWTExpireDays: viper.GetInt("jwt_expire_days"),
		LLMAPIKey:     viper.GetString("gemini_api_key"),
		LLMAPIURL:     viper.GetString("gemini_api_url"),
		VisionAPIKey:  viper.GetString("vision_api_key"),
		VisionAPIURL:  viper.GetString("vision_api_url"),
		OpenAIKey:      viper.GetString("openai_api_key"),
		BaiduCVKey:     viper.GetString("baidu_cv_api_key"),
		ChromaURL:      viper.GetString("chroma_url"),
		GoogleClientID:    viper.GetString("google_client_id"),
		GoogleIOSClientID: viper.GetString("google_ios_client_id"),
	}

	return config, nil
}

// GetEnv gets environment variable with default value
func GetEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// GetEnvInt gets environment variable as int with default value
func GetEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}
