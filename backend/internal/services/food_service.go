package services

import (
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

type FoodService struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewFoodService(db *gorm.DB, logger *zap.Logger) *FoodService {
	return &FoodService{
		db:     db,
		logger: logger,
	}
}

type CreateFoodRecordRequest struct {
	UserID        uint      `json:"user_id" binding:"required"`
	PhotoURL      string    `json:"photo_url"`
	FoodName      string    `json:"food_name" binding:"required"`
	Calories      float32   `json:"calories" binding:"required"`
	Protein       float32   `json:"protein"`
	Carbohydrates float32   `json:"carbohydrates"`
	Fat           float32   `json:"fat"`
	Fiber         float32   `json:"fiber"`
	Portion       float32   `json:"portion"`
	Unit          string    `json:"unit"`
	MealType      string    `json:"meal_type" binding:"required"`
	EatenAt       time.Time `json:"eaten_at"`
}

type UpdateFoodRecordRequest struct {
	FoodName      string  `json:"food_name"`
	Calories      float32 `json:"calories"`
	Protein       float32 `json:"protein"`
	Carbohydrates float32 `json:"carbohydrates"`
	Fat           float32 `json:"fat"`
	Fiber         float32 `json:"fiber"`
	MealType      string  `json:"meal_type"`
	EatenAt       time.Time `json:"eaten_at"`
}

func (s *FoodService) CreateRecord(req *CreateFoodRecordRequest) (*models.FoodRecord, error) {
	record := &models.FoodRecord{
		UserID:        req.UserID,
		PhotoURL:      req.PhotoURL,
		FoodName:      req.FoodName,
		Calories:      req.Calories,
		Protein:       req.Protein,
		Carbohydrates: req.Carbohydrates,
		Fat:           req.Fat,
		Fiber:         req.Fiber,
		Portion:       req.Portion,
		Unit:          req.Unit,
		MealType:      req.MealType,
		EatenAt:       req.EatenAt,
	}

	if req.EatenAt.IsZero() {
		record.EatenAt = time.Now()
	}

	if err := s.db.Create(record).Error; err != nil {
		s.logger.Error("failed to create food record", zap.Error(err))
		return nil, err
	}

	return record, nil
}

func (s *FoodService) GetRecordsByUser(userID uint, startDate, endDate time.Time) ([]models.FoodRecord, error) {
	var records []models.FoodRecord
	query := s.db.Where("user_id = ?", userID)
	
	if !startDate.IsZero() {
		query = query.Where("eaten_at >= ?", startDate)
	}
	if !endDate.IsZero() {
		// Half-open: endDate is exclusive. Handler converts the inclusive
		// client-supplied YYYY-MM-DD into next-day midnight (in client tz).
		query = query.Where("eaten_at < ?", endDate)
	}

	if err := query.Order("eaten_at DESC").Find(&records).Error; err != nil {
		s.logger.Error("failed to get food records", zap.Error(err))
		return nil, err
	}

	return records, nil
}

func (s *FoodService) GetRecordByID(id uint) (*models.FoodRecord, error) {
	var record models.FoodRecord
	if err := s.db.First(&record, id).Error; err != nil {
		s.logger.Error("failed to get food record", zap.Error(err))
		return nil, err
	}
	return &record, nil
}

func (s *FoodService) UpdateRecord(id uint, req *UpdateFoodRecordRequest) (*models.FoodRecord, error) {
	var record models.FoodRecord
	if err := s.db.First(&record, id).Error; err != nil {
		s.logger.Error("failed to get food record", zap.Error(err))
		return nil, err
	}

	updates := make(map[string]interface{})
	if req.FoodName != "" {
		updates["food_name"] = req.FoodName
	}
	if req.Calories > 0 {
		updates["calories"] = req.Calories
	}
	if req.Protein > 0 {
		updates["protein"] = req.Protein
	}
	if req.Carbohydrates > 0 {
		updates["carbohydrates"] = req.Carbohydrates
	}
	if req.Fat > 0 {
		updates["fat"] = req.Fat
	}
	if req.Fiber > 0 {
		updates["fiber"] = req.Fiber
	}
	if req.MealType != "" {
		updates["meal_type"] = req.MealType
	}
	if !req.EatenAt.IsZero() {
		updates["eaten_at"] = req.EatenAt
	}

	if err := s.db.Model(&record).Updates(updates).Error; err != nil {
		s.logger.Error("failed to update food record", zap.Error(err))
		return nil, err
	}

	return &record, nil
}

func (s *FoodService) DeleteRecord(id uint) error {
	if err := s.db.Delete(&models.FoodRecord{}, id).Error; err != nil {
		s.logger.Error("failed to delete food record", zap.Error(err))
		return err
	}
	return nil
}

func (s *FoodService) GetDailySummary(userID uint, date time.Time, loc *time.Location) (map[string]interface{}, error) {
	startOfDay := StartOfDay(date, loc)
	endOfDay := startOfDay.Add(24 * time.Hour)

	var records []models.FoodRecord
	if err := s.db.Where("user_id = ? AND eaten_at >= ? AND eaten_at < ?", userID, startOfDay, endOfDay).
		Find(&records).Error; err != nil {
		s.logger.Error("failed to get daily food records", zap.Error(err))
		return nil, err
	}

	var totalCalories, totalProtein, totalCarbs, totalFat float32
	for _, record := range records {
		totalCalories += record.Calories
		totalProtein += record.Protein
		totalCarbs += record.Carbohydrates
		totalFat += record.Fat
	}

	return map[string]interface{}{
		"date":            date,
		"total_calories":  totalCalories,
		"total_protein":   totalProtein,
		"total_carbs":     totalCarbs,
		"total_fat":       totalFat,
		"meal_count":      len(records),
		"records":         records,
	}, nil
}
