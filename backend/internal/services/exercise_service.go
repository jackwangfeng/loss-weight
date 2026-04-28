package services

import (
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

type ExerciseService struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewExerciseService(db *gorm.DB, logger *zap.Logger) *ExerciseService {
	return &ExerciseService{db: db, logger: logger}
}

type CreateExerciseRecordRequest struct {
	UserID         uint      `json:"user_id" binding:"required"`
	Type           string    `json:"type" binding:"required"`
	DurationMin    int       `json:"duration_min" binding:"required"`
	Intensity      string    `json:"intensity"`
	CaloriesBurned float32   `json:"calories_burned"`
	Distance       float32   `json:"distance"`
	Notes          string    `json:"notes"`
	ExercisedAt    time.Time `json:"exercised_at"`
}

type UpdateExerciseRecordRequest struct {
	Type           string    `json:"type"`
	DurationMin    int       `json:"duration_min"`
	Intensity      string    `json:"intensity"`
	CaloriesBurned float32   `json:"calories_burned"`
	Distance       float32   `json:"distance"`
	Notes          string    `json:"notes"`
	ExercisedAt    time.Time `json:"exercised_at"`
}

func (s *ExerciseService) CreateRecord(req *CreateExerciseRecordRequest) (*models.ExerciseRecord, error) {
	r := &models.ExerciseRecord{
		UserID:         req.UserID,
		Type:           req.Type,
		DurationMin:    req.DurationMin,
		Intensity:      req.Intensity,
		CaloriesBurned: req.CaloriesBurned,
		Distance:       req.Distance,
		Notes:          req.Notes,
		ExercisedAt:    req.ExercisedAt,
	}
	if r.ExercisedAt.IsZero() {
		r.ExercisedAt = time.Now()
	}
	if err := s.db.Create(r).Error; err != nil {
		s.logger.Error("create exercise record failed", zap.Error(err))
		return nil, err
	}
	return r, nil
}

func (s *ExerciseService) GetRecordsByUser(userID uint, startDate, endDate time.Time) ([]models.ExerciseRecord, error) {
	var records []models.ExerciseRecord
	q := s.db.Where("user_id = ?", userID)
	if !startDate.IsZero() {
		q = q.Where("exercised_at >= ?", startDate)
	}
	if !endDate.IsZero() {
		// Half-open: endDate is exclusive. Handler converts the inclusive
		// client-supplied YYYY-MM-DD into next-day midnight (in client tz).
		q = q.Where("exercised_at < ?", endDate)
	}
	if err := q.Order("exercised_at DESC").Find(&records).Error; err != nil {
		return nil, err
	}
	return records, nil
}

func (s *ExerciseService) GetRecordByID(id uint) (*models.ExerciseRecord, error) {
	var r models.ExerciseRecord
	if err := s.db.First(&r, id).Error; err != nil {
		return nil, err
	}
	return &r, nil
}

func (s *ExerciseService) UpdateRecord(id uint, req *UpdateExerciseRecordRequest) (*models.ExerciseRecord, error) {
	var r models.ExerciseRecord
	if err := s.db.First(&r, id).Error; err != nil {
		return nil, err
	}
	updates := map[string]interface{}{}
	if req.Type != ""          { updates["type"] = req.Type }
	if req.DurationMin > 0     { updates["duration_min"] = req.DurationMin }
	if req.Intensity != ""     { updates["intensity"] = req.Intensity }
	if req.CaloriesBurned > 0  { updates["calories_burned"] = req.CaloriesBurned }
	if req.Distance > 0        { updates["distance"] = req.Distance }
	if req.Notes != ""         { updates["notes"] = req.Notes }
	if !req.ExercisedAt.IsZero() { updates["exercised_at"] = req.ExercisedAt }

	if err := s.db.Model(&r).Updates(updates).Error; err != nil {
		return nil, err
	}
	return &r, nil
}

func (s *ExerciseService) DeleteRecord(id uint) error {
	return s.db.Delete(&models.ExerciseRecord{}, id).Error
}

func (s *ExerciseService) GetDailySummary(userID uint, date time.Time, loc *time.Location) (map[string]interface{}, error) {
	start := StartOfDay(date, loc)
	end := start.Add(24 * time.Hour)
	var records []models.ExerciseRecord
	if err := s.db.Where("user_id = ? AND exercised_at >= ? AND exercised_at < ?", userID, start, end).
		Find(&records).Error; err != nil {
		return nil, err
	}
	var totalCal float32
	var totalMin int
	for _, r := range records {
		totalCal += r.CaloriesBurned
		totalMin += r.DurationMin
	}
	return map[string]interface{}{
		"date":                  date,
		"total_calories_burned": totalCal,
		"total_duration_min":    totalMin,
		"session_count":         len(records),
		"records":               records,
	}, nil
}
