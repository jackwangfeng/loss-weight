package models

import (
	"time"

	"gorm.io/gorm"
)

type WeightRecord struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`
	Weight    float32        `gorm:"type:decimal(5,2);not null" json:"weight"`
	BodyFat   float32        `gorm:"type:decimal(5,2)" json:"body_fat"`
	Muscle    float32        `gorm:"type:decimal(5,2)" json:"muscle"`
	Water     float32        `gorm:"type:decimal(5,2)" json:"water"`
	BMI       float32        `gorm:"type:decimal(5,2)" json:"bmi"`
	Note      string         `gorm:"size:255" json:"note"`
	MeasuredAt time.Time     `json:"measured_at"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (WeightRecord) TableName() string {
	return "weight_records"
}
