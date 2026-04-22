package models

import (
	"time"

	"gorm.io/gorm"
)

type SMSCode struct {
	ID         uint           `gorm:"primaryKey" json:"id"`
	Phone      string         `gorm:"size:11;not null;index" json:"phone"`
	Code       string         `gorm:"size:6;not null" json:"-"`
	Purpose    string         `gorm:"size:32;not null" json:"purpose"` // login, register, reset_password
	IsUsed     bool           `gorm:"default:false" json:"is_used"`
	ExpiresAt  time.Time      `json:"expires_at"`
	CreatedAt  time.Time      `json:"created_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

func (SMSCode) TableName() string {
	return "sms_codes"
}

// UserAccount — one identity per row. Supports both SMS (Phone) and Google
// (Email + GoogleSub) sign-in. All three identifier columns are nullable so
// a row can be created via either path; unique indexes ignore NULL in Postgres,
// so multiple "Google-only" or "SMS-only" accounts coexist without collision.
type UserAccount struct {
	ID             uint           `gorm:"primaryKey" json:"id"`
	Phone          *string        `gorm:"size:16;uniqueIndex" json:"phone,omitempty"`
	Email          *string        `gorm:"size:255;uniqueIndex" json:"email,omitempty"`
	GoogleSub      *string        `gorm:"size:64;uniqueIndex" json:"google_sub,omitempty"` // Google's stable user id
	Password       string         `gorm:"size:255" json:"-"`                                // reserved for password login
	UserProfileID  *uint          `gorm:"index" json:"user_profile_id"`
	UserProfile    *UserProfile   `gorm:"foreignKey:UserProfileID" json:"user_profile,omitempty"`
	LastLoginAt    *time.Time     `json:"last_login_at"`
	LastLoginIP    string         `gorm:"size:64" json:"last_login_ip"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (UserAccount) TableName() string {
	return "user_accounts"
}
