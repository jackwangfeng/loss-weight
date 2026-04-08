package models

import (
	"time"

	"gorm.io/gorm"
)

type AIChatMessage struct {
	ID         uint           `gorm:"primaryKey" json:"id"`
	UserID     uint           `gorm:"not null;index" json:"user_id"`
	Role       string         `gorm:"size:16;not null" json:"role"`
	Content    string         `gorm:"type:text;not null" json:"content"`
	Tokens     int            `gorm:"type:int" json:"tokens"`
	ParentID   *uint          `gorm:"index" json:"parent_id"`
	ThreadID   string         `gorm:"size:64;index" json:"thread_id"`
	CreatedAt  time.Time      `json:"created_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

func (AIChatMessage) TableName() string {
	return "ai_chat_messages"
}

type AIChatThread struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`
	Title     string         `gorm:"size:128" json:"title"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (AIChatThread) TableName() string {
	return "ai_chat_threads"
}
