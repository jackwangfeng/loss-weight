package models

import (
	"time"

	"github.com/pgvector/pgvector-go"
	"gorm.io/gorm"
)

type AIChatMessage struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`
	Role      string         `gorm:"size:16;not null" json:"role"`
	Content   string         `gorm:"type:text;not null" json:"content"`
	Tokens    int            `gorm:"type:int" json:"tokens"`
	ParentID  *uint          `gorm:"index" json:"parent_id"`
	ThreadID  string         `gorm:"size:64;index" json:"thread_id"`
	// 当 assistant 消息伴随一次 agent 工具调用（log_weight 等）时填充。
	// 重新加载历史时前端依据此渲染卡片（含撤销）。
	ActionKind    string `gorm:"size:32" json:"action_kind,omitempty"`
	ActionPayload string `gorm:"type:text" json:"action_payload,omitempty"`
	// Embedding: gemini-embedding-001 的 3072 维向量，fp16 存储。
	// 异步写入，后端 RAG 检索用 SQL 侧 cosine；前端不需要看，json tag "-"。
	// Postgres 专用：pgvector 的 halfvec + HNSW 索引（≤4000 维）。
	Embedding *pgvector.HalfVector `gorm:"type:halfvec(3072)" json:"-"`
	CreatedAt time.Time            `json:"created_at"`
	DeletedAt gorm.DeletedAt       `gorm:"index" json:"-"`
}

func (AIChatMessage) TableName() string {
	return "ai_chat_messages"
}

type AIChatThread struct {
	ID           uint           `gorm:"primaryKey" json:"id"`
	UserID       uint           `gorm:"not null;index" json:"user_id"`
	Title        string         `gorm:"size:128" json:"title"`
	// Summary: 旧消息被压缩后的滚动摘要。长对话里，只把这段 + 最近 N 条原文喂给 LLM。
	Summary      string         `gorm:"type:text" json:"summary,omitempty"`
	// MessageCount: 驱动异步事实抽取 / 摘要的触发器
	MessageCount int            `gorm:"default:0" json:"message_count"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

func (AIChatThread) TableName() string {
	return "ai_chat_threads"
}

// UserFact 长期记忆：LLM 从历史对话里抽出来的结构化事实，
// 每次请求前会按 category 组装进 system prompt。
type UserFact struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	UserID      uint      `gorm:"not null;index" json:"user_id"`
	Category    string    `gorm:"size:32;not null;index" json:"category"` // preference | constraint | goal | routine | history
	Fact        string    `gorm:"type:text;not null" json:"fact"`
	Confidence  float32   `gorm:"default:0.8" json:"confidence"`
	SourceMsgID *uint     `gorm:"index" json:"source_message_id,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (UserFact) TableName() string {
	return "user_facts"
}
