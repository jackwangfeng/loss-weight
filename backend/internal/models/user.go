package models

import (
	"time"

	"gorm.io/gorm"
)

type Gender string

const (
	GenderMale   Gender = "male"
	GenderFemale Gender = "female"
	GenderOther  Gender = "other"
)

type UserProfile struct {
	ID              uint           `gorm:"primaryKey" json:"id"`
	OpenID          string         `gorm:"uniqueIndex;not null;size:64" json:"openid"`
	UnionID         string         `gorm:"size:64" json:"unionid"`
	Nickname        string         `gorm:"size:64" json:"nickname"`
	Avatar          string         `gorm:"size:255" json:"avatar"`
	Gender          Gender         `gorm:"size:16" json:"gender"`
	Birthday        *time.Time     `json:"birthday"`
	Height          float32        `gorm:"type:decimal(5,2)" json:"height"`
	CurrentWeight   float32        `gorm:"type:decimal(5,2);not null" json:"current_weight"`
	TargetWeight    float32        `gorm:"type:decimal(5,2)" json:"target_weight"`
	ActivityLevel   int            `gorm:"type:int" json:"activity_level"`
	TargetCalorie   float32        `gorm:"type:decimal(8,2)" json:"target_calorie"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}

func (UserProfile) TableName() string {
	return "user_profiles"
}

type UserSettings struct {
	ID                uint           `gorm:"primaryKey" json:"id"`
	UserID            uint           `gorm:"not null;index" json:"user_id"`
	NotifyEnabled     bool           `gorm:"default:true" json:"notify_enabled"`
	NotifyTime        string         `gorm:"size:16" json:"notify_time"`
	Theme             string         `gorm:"size:32;default:'light'" json:"theme"`
	Language          string         `gorm:"size:16;default:'zh'" json:"language"`
	MeasurementUnit   string         `gorm:"size:16;default:'metric'" json:"measurement_unit"`
	CreatedAt         time.Time      `json:"created_at"`
	UpdatedAt         time.Time      `json:"updated_at"`
	DeletedAt         gorm.DeletedAt `gorm:"index" json:"-"`
}

func (UserSettings) TableName() string {
	return "user_settings"
}
