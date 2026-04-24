package services

import (
	"strings"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

type FeedbackService struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewFeedbackService(db *gorm.DB, logger *zap.Logger) *FeedbackService {
	return &FeedbackService{db: db, logger: logger}
}

type CreateFeedbackRequest struct {
	UserID     *uint  `json:"user_id,omitempty"`
	Content    string `json:"content" binding:"required,min=1,max=4000"`
	Contact    string `json:"contact,omitempty"`
	Platform   string `json:"platform,omitempty"`
	AppVersion string `json:"app_version,omitempty"`
	DeviceInfo string `json:"device_info,omitempty"`
}

func (s *FeedbackService) Create(req *CreateFeedbackRequest) (*models.Feedback, error) {
	fb := &models.Feedback{
		UserID:     req.UserID,
		Content:    strings.TrimSpace(req.Content),
		Contact:    strings.TrimSpace(req.Contact),
		Platform:   req.Platform,
		AppVersion: req.AppVersion,
		DeviceInfo: req.DeviceInfo,
	}
	if err := s.db.Create(fb).Error; err != nil {
		s.logger.Error("failed to create feedback", zap.Error(err))
		return nil, err
	}
	// Log inline at info level so the solo-dev can grep logs during early
	// phase; no notification fan-out yet.
	s.logger.Info("feedback received",
		zap.Uint("id", fb.ID),
		zap.Any("user_id", fb.UserID),
		zap.String("platform", fb.Platform),
		zap.Int("len", len(fb.Content)))
	return fb, nil
}
