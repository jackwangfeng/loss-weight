package models

import (
	"time"

	"gorm.io/gorm"
)

type FoodRecord struct {
	ID            uint           `gorm:"primaryKey" json:"id"`
	UserID        uint           `gorm:"not null;index" json:"user_id"`
	PhotoURL      string         `gorm:"size:255" json:"photo_url"`
	FoodName      string         `gorm:"size:128;not null" json:"food_name"`
	Calories      float32        `gorm:"type:decimal(8,2);not null" json:"calories"`
	Protein       float32        `gorm:"type:decimal(6,2)" json:"protein"`
	Carbohydrates float32        `gorm:"type:decimal(6,2)" json:"carbohydrates"`
	Fat           float32        `gorm:"type:decimal(6,2)" json:"fat"`
	Fiber         float32        `gorm:"type:decimal(6,2)" json:"fiber"`
	MealType      string         `gorm:"size:16;not null" json:"meal_type"`
	EatenAt       time.Time      `json:"eaten_at"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (FoodRecord) TableName() string {
	return "food_records"
}

type MealType string

const (
	MealBreakfast MealType = "breakfast"
	MealLunch     MealType = "lunch"
	MealDinner    MealType = "dinner"
	MealSnack     MealType = "snack"
)
