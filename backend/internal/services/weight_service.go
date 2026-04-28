package services

import (
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

type WeightService struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewWeightService(db *gorm.DB, logger *zap.Logger) *WeightService {
	return &WeightService{
		db:     db,
		logger: logger,
	}
}

type CreateWeightRecordRequest struct {
	UserID     uint      `json:"user_id" binding:"required"`
	Weight     float32   `json:"weight" binding:"required"`
	BodyFat    float32   `json:"body_fat"`
	Muscle     float32   `json:"muscle"`
	Water      float32   `json:"water"`
	BMI        float32   `json:"bmi"`
	Note       string    `json:"note"`
	MeasuredAt time.Time `json:"measured_at"`
}

type UpdateWeightRecordRequest struct {
	Weight     float32   `json:"weight"`
	BodyFat    float32   `json:"body_fat"`
	Muscle     float32   `json:"muscle"`
	Water      float32   `json:"water"`
	BMI        float32   `json:"bmi"`
	Note       string    `json:"note"`
	MeasuredAt time.Time `json:"measured_at"`
}

func (s *WeightService) CreateRecord(req *CreateWeightRecordRequest) (*models.WeightRecord, error) {
	record := &models.WeightRecord{
		UserID:     req.UserID,
		Weight:     req.Weight,
		BodyFat:    req.BodyFat,
		Muscle:     req.Muscle,
		Water:      req.Water,
		BMI:        req.BMI,
		Note:       req.Note,
		MeasuredAt: req.MeasuredAt,
	}

	if req.MeasuredAt.IsZero() {
		record.MeasuredAt = time.Now()
	}

	if err := s.db.Create(record).Error; err != nil {
		s.logger.Error("failed to create weight record", zap.Error(err))
		return nil, err
	}

	return record, nil
}

func (s *WeightService) GetRecordsByUser(userID uint, startDate, endDate time.Time) ([]models.WeightRecord, error) {
	var records []models.WeightRecord
	query := s.db.Where("user_id = ?", userID)

	if !startDate.IsZero() {
		query = query.Where("measured_at >= ?", startDate)
	}
	if !endDate.IsZero() {
		// Half-open: endDate is exclusive. Handler converts the inclusive
		// client-supplied YYYY-MM-DD into next-day midnight (in client tz).
		query = query.Where("measured_at < ?", endDate)
	}

	if err := query.Order("measured_at DESC").Find(&records).Error; err != nil {
		s.logger.Error("failed to get weight records", zap.Error(err))
		return nil, err
	}

	return records, nil
}

func (s *WeightService) GetRecordByID(id uint) (*models.WeightRecord, error) {
	var record models.WeightRecord
	if err := s.db.First(&record, id).Error; err != nil {
		s.logger.Error("failed to get weight record", zap.Error(err))
		return nil, err
	}
	return &record, nil
}

func (s *WeightService) UpdateRecord(id uint, req *UpdateWeightRecordRequest) (*models.WeightRecord, error) {
	var record models.WeightRecord
	if err := s.db.First(&record, id).Error; err != nil {
		s.logger.Error("failed to get weight record", zap.Error(err))
		return nil, err
	}

	updates := make(map[string]interface{})
	if req.Weight > 0 {
		updates["weight"] = req.Weight
	}
	if req.BodyFat > 0 {
		updates["body_fat"] = req.BodyFat
	}
	if req.Muscle > 0 {
		updates["muscle"] = req.Muscle
	}
	if req.Water > 0 {
		updates["water"] = req.Water
	}
	if req.BMI > 0 {
		updates["bmi"] = req.BMI
	}
	if req.Note != "" {
		updates["note"] = req.Note
	}
	if !req.MeasuredAt.IsZero() {
		updates["measured_at"] = req.MeasuredAt
	}

	if err := s.db.Model(&record).Updates(updates).Error; err != nil {
		s.logger.Error("failed to update weight record", zap.Error(err))
		return nil, err
	}

	return &record, nil
}

func (s *WeightService) DeleteRecord(id uint) error {
	if err := s.db.Delete(&models.WeightRecord{}, id).Error; err != nil {
		s.logger.Error("failed to delete weight record", zap.Error(err))
		return err
	}
	return nil
}

func (s *WeightService) GetWeightTrend(userID uint, days int) ([]models.WeightRecord, error) {
	startDate := time.Now().AddDate(0, 0, -days)
	var records []models.WeightRecord

	if err := s.db.Where("user_id = ? AND measured_at >= ?", userID, startDate).
		Order("measured_at ASC").
		Find(&records).Error; err != nil {
		s.logger.Error("failed to get weight trend", zap.Error(err))
		return nil, err
	}

	return records, nil
}
