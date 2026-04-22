package services

import (
	"errors"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

type UserService struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewUserService(db *gorm.DB, logger *zap.Logger) *UserService {
	return &UserService{
		db:     db,
		logger: logger,
	}
}

type CreateUserProfileRequest struct {
	OpenID        string     `json:"openid" binding:"required"`
	UnionID       string     `json:"unionid"`
	Nickname      string     `json:"nickname"`
	Avatar        string     `json:"avatar"`
	Gender        models.Gender `json:"gender"`
	Birthday      *time.Time `json:"birthday"`
	Height        float32    `json:"height"`
	CurrentWeight float32    `json:"current_weight" binding:"required"`
	TargetWeight  float32    `json:"target_weight"`
	ActivityLevel int        `json:"activity_level"`
	TargetCalorie float32    `json:"target_calorie"`
}

type UpdateUserProfileRequest struct {
	Nickname       string        `json:"nickname"`
	Avatar         string        `json:"avatar"`
	Gender         models.Gender `json:"gender"`
	Birthday       *time.Time    `json:"birthday"`
	Height         float32       `json:"height"`
	CurrentWeight  float32       `json:"current_weight"`
	TargetWeight   float32       `json:"target_weight"`
	ActivityLevel  int           `json:"activity_level"`
	TargetCalorie  float32       `json:"target_calorie"`
	TargetProteinG float32       `json:"target_protein_g"`
	TargetCarbsG   float32       `json:"target_carbs_g"`
	TargetFatG     float32       `json:"target_fat_g"`
}

func (s *UserService) CreateProfile(req *CreateUserProfileRequest) (*models.UserProfile, error) {
	profile := &models.UserProfile{
		OpenID:        req.OpenID,
		UnionID:       req.UnionID,
		Nickname:      req.Nickname,
		Avatar:        req.Avatar,
		Gender:        req.Gender,
		Birthday:      req.Birthday,
		Height:        req.Height,
		CurrentWeight: req.CurrentWeight,
		TargetWeight:  req.TargetWeight,
		ActivityLevel: req.ActivityLevel,
		TargetCalorie: req.TargetCalorie,
	}

	if err := s.db.Create(profile).Error; err != nil {
		s.logger.Error("failed to create user profile", zap.Error(err))
		return nil, err
	}

	return profile, nil
}

func (s *UserService) GetProfileByOpenID(openID string) (*models.UserProfile, error) {
	var profile models.UserProfile
	if err := s.db.Where("openid = ?", openID).First(&profile).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		s.logger.Error("failed to get user profile", zap.Error(err))
		return nil, err
	}
	return &profile, nil
}

func (s *UserService) GetProfileByID(id uint) (*models.UserProfile, error) {
	var profile models.UserProfile
	if err := s.db.First(&profile, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		s.logger.Error("failed to get user profile", zap.Error(err))
		return nil, err
	}
	return &profile, nil
}

func (s *UserService) UpdateProfile(id uint, req *UpdateUserProfileRequest) (*models.UserProfile, error) {
	var profile models.UserProfile
	if err := s.db.First(&profile, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		s.logger.Error("failed to get user profile", zap.Error(err))
		return nil, err
	}

	updates := make(map[string]interface{})
	if req.Nickname != "" {
		updates["nickname"] = req.Nickname
	}
	if req.Avatar != "" {
		updates["avatar"] = req.Avatar
	}
	if req.Gender != "" {
		updates["gender"] = req.Gender
	}
	if req.Birthday != nil {
		updates["birthday"] = req.Birthday
	}
	if req.Height > 0 {
		updates["height"] = req.Height
	}
	if req.CurrentWeight > 0 {
		updates["current_weight"] = req.CurrentWeight
	}
	if req.TargetWeight > 0 {
		updates["target_weight"] = req.TargetWeight
	}
	if req.ActivityLevel > 0 {
		updates["activity_level"] = req.ActivityLevel
	}
	if req.TargetCalorie > 0 {
		updates["target_calorie"] = req.TargetCalorie
	}
	if req.TargetProteinG > 0 {
		updates["target_protein_g"] = req.TargetProteinG
	}
	if req.TargetCarbsG > 0 {
		updates["target_carbs_g"] = req.TargetCarbsG
	}
	if req.TargetFatG > 0 {
		updates["target_fat_g"] = req.TargetFatG
	}

	if err := s.db.Model(&profile).Updates(updates).Error; err != nil {
		s.logger.Error("failed to update user profile", zap.Error(err))
		return nil, err
	}

	return &profile, nil
}

func (s *UserService) DeleteProfile(id uint) error {
	if err := s.db.Delete(&models.UserProfile{}, id).Error; err != nil {
		s.logger.Error("failed to delete user profile", zap.Error(err))
		return err
	}
	return nil
}
