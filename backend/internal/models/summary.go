package models

import "time"

type DailySummary struct {
	ID              uint      `gorm:"primaryKey" json:"id"`
	UserID          uint      `gorm:"not null;index;uniqueIndex:idx_user_date" json:"user_id"`
	Date            time.Time `gorm:"type:date;uniqueIndex:idx_user_date;not null" json:"date"`
	TotalCalories   float32   `gorm:"type:decimal(8,2);default:0" json:"total_calories"`
	TotalProtein    float32   `gorm:"type:decimal(6,2);default:0" json:"total_protein"`
	TotalCarbs      float32   `gorm:"type:decimal(6,2);default:0" json:"total_carbs"`
	TotalFat        float32   `gorm:"type:decimal(6,2);default:0" json:"total_fat"`
	MealCount       int       `gorm:"type:int;default:0" json:"meal_count"`
	WeightChange    float32   `gorm:"type:decimal(5,2)" json:"weight_change"`
	MoodScore       int       `gorm:"type:int" json:"mood_score"`
	EnergyLevel     int       `gorm:"type:int" json:"energy_level"`
	SleepHours      float32   `gorm:"type:decimal(4,2)" json:"sleep_hours"`
	ExerciseMinutes int       `gorm:"type:int" json:"exercise_minutes"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

func (DailySummary) TableName() string {
	return "daily_summaries"
}
