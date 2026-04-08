# HTTP 处理器 (Handlers)

> HTTP 请求处理器

---

## 📁 文件结构

```
handlers/
├── README.md                 # 本文档
├── user.go                   # 用户处理器
├── food.go                   # 饮食处理器
├── weight.go                 # 体重处理器
└── ai.go                     # AI 处理器
```

---

## 📋 处理器设计

### 职责

- 接收 HTTP 请求
- 参数验证
- 调用业务服务
- 返回 HTTP 响应

---

### 示例：用户处理器

**文件：** `handlers/user.go`

```go
package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/your-org/loss-weight/backend/internal/services"
	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
)

type UserHandler struct {
	userService *services.UserService
	logger      *zap.Logger
}

func NewUserHandler(us *services.UserService, logger *zap.Logger) *UserHandler {
	return &UserHandler{
		userService: us,
		logger:      logger,
	}
}

// CreateUserProfile godoc
// @Summary Create user profile
// @Tags users
// @Accept json
// @Produce json
// @Param profile body models.User true "User profile"
// @Success 200 {object} map[string]interface{}
// @Router /v1/users/profile [post]
func (h *UserHandler) CreateUserProfile(c *gin.Context) {
	var profile models.User
	
	if err := c.ShouldBindJSON(&profile); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    400,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}
	
	if err := h.userService.CreateProfile(&profile); err != nil {
		h.logger.Error("Failed to create user", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    500,
			"message": "Failed to create user",
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 200,
		"data": profile,
	})
}

// GetUserProfile godoc
// @Summary Get user profile
// @Tags users
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/users/profile [get]
func (h *UserHandler) GetUserProfile(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	user, err := h.userService.GetByID(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"code":    404,
			"message": "User not found",
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 200,
		"data": user,
	})
}
```

---

## 🎯 处理器设计原则

### 1. 薄处理器

处理器只负责：
- 参数验证
- 调用服务
- 返回响应

业务逻辑放在 Service 层

### 2. 统一响应格式

```go
type Response struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}
```

### 3. 错误处理

```go
func (h *UserHandler) GetUserProfile(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	user, err := h.userService.GetByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, ErrorResponse("User not found"))
			return
		}
		
		h.logger.Error("Failed to get user", zap.Error(err))
		c.JSON(http.StatusInternalServerError, ErrorResponse("Internal error"))
		return
	}
	
	c.JSON(http.StatusOK, SuccessResponse(user))
}
```

---

## 🔗 相关链接

- [业务服务](../services/README.md)
- [数据模型](../models/README.md)
- [后端首页](../README.md)
- [项目首页](../../README.md)

---

**最后更新：** 2026-04-06
