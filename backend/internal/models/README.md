# 数据模型 (Models)

> GORM 数据模型定义

---

## 📁 文件结构

```
models/
├── README.md                 # 本文档
├── user.go                   # 用户模型
├── food_record.go            # 饮食记录模型
├── weight_record.go          # 体重记录模型
├── ai_conversation.go        # AI 对话模型
├── ai_memory.go              # AI 记忆模型
└── food_database.go          # 食物库模型
```

---

## 🗄️ 数据库表概览

| 表名 | 模型 | 说明 | 数据量级 |
|------|------|------|---------|
| `users` | User | 用户档案 | 万级 |
| `food_records` | FoodRecord | 饮食记录 | 百万级 |
| `weight_records` | WeightRecord | 体重记录 | 十万级 |
| `ai_conversations` | AIConversation | AI 对话 | 百万级 |
| `ai_memories` | AIMemory | AI 记忆 | 十万级 |
| `food_database` | FoodDatabase | 食物库 | 万级 |

---

## 📋 模型定义

### 1. User 模型

**文件：** `models/user.go`

```go
package models

import (
	"time"
	"gorm.io/gorm"
)

type User struct {
	ID             uint           `gorm:"primaryKey" json:"id"`
	Nickname       string         `gorm:"size:50;uniqueIndex;not null" json:"nickname" validate:"required,min=2,max=50"`
	Gender         string         `gorm:"size:10;not null" json:"gender" validate:"required,oneof=male female"`
	Age            int            `gorm:"not null" json:"age" validate:"required,min=10,max=100"`
	Height         float64        `gorm:"precision:5;scale:2;not null" json:"height" validate:"required,min=100,max=250"`
	CurrentWeight  float64        `gorm:"precision:5;scale:2;not null" json:"current_weight" validate:"required,min=30,max=300"`
	TargetWeight   float64        `gorm:"precision:5;scale:2;not null" json:"target_weight" validate:"required,min=30,max=300"`
	TargetDate     *time.Time     `json:"target_date"`
	
	// AI calculated fields
	BMI            float64        `gorm:"precision:4;scale:2" json:"bmi"`
	BMR            float64        `gorm:"precision:6;scale:2" json:"bmr"`
	TDEE           float64        `gorm:"precision:6;scale:2" json:"tdee"`
	DailyBudget    int            `gorm:"not null" json:"daily_budget"`
	
	// Statistics
	StreakDays     int            `gorm:"default:0" json:"streak_days"`
	TotalLoss      float64        `gorm:"precision:5;scale:2;default:0" json:"total_loss"`
	
	// Timestamps
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (User) TableName() string {
	return "users"
}
```

---

### 2. FoodRecord 模型

**文件：** `models/food_record.go`

```go
package models

import (
	"time"
	"gorm.io/gorm"
)

type FoodRecord struct {
	ID             uint           `gorm:"primaryKey" json:"id"`
	UserID         uint           `gorm:"not null;index:idx_user_date" json:"user_id"`
	User           User           `gorm:"foreignKey:UserID" json:"-"`
	
	// Food information
	FoodName       string         `gorm:"size:200;not null" json:"food_name"`
	Calories       int            `gorm:"not null" json:"calories"`
	Protein        *float64       `json:"protein"`
	Fat            *float64       `json:"fat"`
	Carbs          *float64       `json:"carbs"`
	
	// Portion information
	Portion        float64        `gorm:"precision:8;scale:2;not null" json:"portion"`
	Unit           string         `gorm:"size:20;default:'g'" json:"unit"`
	
	// Meal type
	MealType       string         `gorm:"size:20;not null;index:idx_user_meal" json:"meal_type" validate:"required,oneof=breakfast lunch dinner snack"`
	
	// Record type
	RecordType     string         `gorm:"size:20;not null" json:"record_type" validate:"required,oneof=photo search manual"`
	
	// Image (if photo)
	ImageURL       *string        `json:"image_url"`
	AIConfidence   *float64       `gorm:"precision:3;scale:2" json:"ai_confidence"`
	
	// Timestamps
	RecordedAt     time.Time      `gorm:"not null;index:idx_user_date" json:"recorded_at"`
	CreatedAt      time.Time      `json:"created_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (FoodRecord) TableName() string {
	return "food_records"
}
```

---

### 3. WeightRecord 模型

**文件：** `models/weight_record.go`

```go
package models

import (
	"time"
	"gorm.io/gorm"
)

type WeightRecord struct {
	ID             uint           `gorm:"primaryKey" json:"id"`
	UserID         uint           `gorm:"not null;index:idx_user_date" json:"user_id"`
	User           User           `gorm:"foreignKey:UserID" json:"-"`
	
	// Weight data
	Weight         float64        `gorm:"precision:5;scale:2;not null" json:"weight" validate:"required,min=30,max=300"`
	
	// Note
	Note           *string        `gorm:"size:200" json:"note"`
	
	// Timestamps
	RecordedAt     time.Time      `gorm:"not null;index:idx_user_date" json:"recorded_at"`
	CreatedAt      time.Time      `json:"created_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (WeightRecord) TableName() string {
	return "weight_records"
}
```

---

## 🔗 模型关系

```
User (1) ──→ (N) FoodRecord
   │
   ├──→ (N) WeightRecord
   │
   └──→ (N) AIConversation
              │
              └──→ (N) AIMemory
```

---

## 📝 使用示例

### 创建用户

```go
user := models.User{
	Nickname:      "小明",
	Gender:        "male",
	Age:           28,
	Height:        175,
	CurrentWeight: 75.0,
	TargetWeight:  65.0,
	DailyBudget:   1480,
}

db.Create(&user)
```

### 查询今日饮食

```go
var records []models.FoodRecord
db.Where("user_id = ? AND DATE(recorded_at) = ?", userID, time.Now().Date()).Find(&records)
```

---

## 🔗 相关链接

- [技术架构文档](../../docs/architecture.md)
- [后端首页](../README.md)
- [业务服务](../services/README.md)
- [项目首页](../../README.md)

---

**最后更新：** 2026-04-06
