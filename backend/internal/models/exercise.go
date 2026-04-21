package models

import (
	"time"

	"gorm.io/gorm"
)

// ExerciseRecord 运动记录
type ExerciseRecord struct {
	ID              uint           `gorm:"primaryKey" json:"id"`
	UserID          uint           `gorm:"not null;index" json:"user_id"`
	Type            string         `gorm:"size:64;not null" json:"type"`         // 跑步 / 游泳 / 力量 / 瑜伽 / 骑行 / 走路 / ...
	DurationMin     int            `gorm:"not null" json:"duration_min"`         // 分钟
	Intensity       string         `gorm:"size:16" json:"intensity"`             // low / medium / high
	CaloriesBurned  float32        `gorm:"type:decimal(8,2)" json:"calories_burned"`
	Distance        float32        `gorm:"type:decimal(8,2)" json:"distance"` // km，仅对跑步/骑行/走路有意义
	Notes           string         `gorm:"size:255" json:"notes"`
	ExercisedAt     time.Time      `json:"exercised_at"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ExerciseRecord) TableName() string {
	return "exercise_records"
}
