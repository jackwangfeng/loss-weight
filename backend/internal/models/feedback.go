package models

import (
	"time"

	"gorm.io/gorm"
)

// Feedback captures one piece of user-reported feedback from the in-app
// "意见反馈" form. Kept intentionally minimal — the point is to read the
// content column directly during the early-user phase, not to build a
// triage system. Triage can come later if volume justifies it.
type Feedback struct {
	ID         uint           `gorm:"primaryKey" json:"id"`
	UserID     *uint          `gorm:"index" json:"user_id,omitempty"` // nullable: anonymous feedback allowed
	Content    string         `gorm:"type:text;not null" json:"content"`
	Contact    string         `gorm:"size:128" json:"contact,omitempty"` // optional email / wechat
	Platform   string         `gorm:"size:16" json:"platform"`           // ios / android / web / macos / windows
	AppVersion string         `gorm:"size:32" json:"app_version"`
	DeviceInfo string         `gorm:"size:255" json:"device_info"` // raw user-agent-ish string
	Resolved   bool           `gorm:"default:false" json:"resolved"`
	CreatedAt  time.Time      `json:"created_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Feedback) TableName() string {
	return "feedbacks"
}
