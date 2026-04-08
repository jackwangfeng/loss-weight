# 业务服务 (Services)

> 核心业务逻辑实现

---

## 📁 文件结构

```
services/
├── README.md                 # 本文档
├── user.go                   # 用户服务
├── food.go                   # 饮食服务
├── weight.go                 # 体重服务
├── ai_encouragement.go       # AI 鼓励服务
├── ai_chat.go                # AI 对话服务
├── calculator.go             # 热量计算服务
└── food_recognition.go       # 食物识别服务
```

---

## 📋 服务设计

### 服务层职责

- 实现核心业务逻辑
- 调用第三方 API（AI 服务）
- 数据计算和验证
- 事务管理

---

### 1. 用户服务

**文件：** `services/user.go`

**功能：**
- 创建用户档案
- 计算 BMI/BMR/TDEE
- 更新用户信息

**示例：**
```go
package services

type UserService struct {
	db *gorm.DB
}

func NewUserService(db *gorm.DB) *UserService {
	return &UserService{db: db}
}

func (s *UserService) CreateProfile(profile *models.User) error {
	// Calculate BMI
	profile.BMI = calculateBMI(profile.CurrentWeight, profile.Height)
	
	// Calculate BMR
	profile.BMR = calculateBMR(profile.Gender, profile.CurrentWeight, profile.Height, profile.Age)
	
	// Calculate TDEE
	profile.TDEE = calculateTDEE(profile.BMR)
	
	// Calculate daily budget
	profile.DailyBudget = int(profile.TDEE) - 500
	
	return s.db.Create(profile).Error
}
```

---

### 2. 饮食服务

**文件：** `services/food.go`

**功能：**
- 添加饮食记录
- 获取今日饮食汇总
- 更新/删除记录

**示例：**
```go
package services

type FoodService struct {
	db *gorm.DB
}

func (s *FoodService) AddRecord(record *models.FoodRecord) error {
	return s.db.Create(record).Error
}

func (s *FoodService) GetTodaySummary(userID uint) (*FoodSummary, error) {
	// Get today's records
	var records []models.FoodRecord
	s.db.Where("user_id = ? AND DATE(recorded_at) = ?", userID, time.Now()).Find(&records)
	
	// Calculate totals
	totalCalories := 0
	totalProtein := 0.0
	for _, r := range records {
		totalCalories += r.Calories
		if r.Protein != nil {
			totalProtein += *r.Protein
		}
	}
	
	return &FoodSummary{
		TotalCalories: totalCalories,
		TotalProtein:  totalProtein,
		RecordsCount:  len(records),
	}, nil
}
```

---

### 3. 热量计算服务

**文件：** `services/calculator.go`

**功能：**
- 计算 BMR
- 计算 TDEE
- 计算 BMI

**示例：**
```go
package services

func calculateBMR(gender string, weight, height float64, age int) float64 {
	if gender == "male" {
		return 66 + (13.7 * weight) + (5 * height) - (6.8 * float64(age))
	}
	return 655 + (9.6 * weight) + (1.8 * height) - (4.7 * float64(age))
}

func calculateTDEE(bmr float64) float64 {
	activityLevel := 1.2 // Sedentary
	return bmr * activityLevel
}

func calculateBMI(weight, height float64) float64 {
	heightInMeters := height / 100
	return weight / (heightInMeters * heightInMeters)
}
```

---

## 🎯 服务设计原则

### 1. 单一职责

每个服务只负责一个业务领域

### 2. 依赖注入

```go
type Handler struct {
	userService   *services.UserService
	foodService   *services.FoodService
}

func NewHandler(us *services.UserService, fs *services.FoodService) *Handler {
	return &Handler{
		userService: us,
		foodService: fs,
	}
}
```

### 3. 错误处理

```go
func (s *UserService) CreateProfile(profile *models.User) error {
	if err := validateProfile(profile); err != nil {
		return fmt.Errorf("invalid profile: %w", err)
	}
	
	if err := s.db.Create(profile).Error; err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}
	
	return nil
}
```

---

## 🔗 相关链接

- [数据模型](../models/README.md)
- [HTTP 处理器](../handlers/README.md)
- [后端首页](../README.md)
- [项目首页](../../README.md)

---

**最后更新：** 2026-04-06
