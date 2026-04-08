# Backend (Go + Gin)

> Go 语言后端服务，提供高性能 RESTful API

---

## 📁 目录结构

```
backend/
├── README.md                 # 本文档
├── go.mod                    # Go 模块定义
├── go.sum                    # 依赖锁定
├── cmd/
│   └── server/
│       └── main.go           # 应用入口
├── internal/                 # 私有包
│   ├── config/               # 配置管理
│   ├── database/             # 数据库连接
│   ├── handlers/             # HTTP 处理器
│   ├── models/               # 数据模型
│   ├── services/             # 业务逻辑
│   ├── middleware/           # 中间件
│   └── utils/                # 工具函数
├── pkg/                      # 公共包
│   ├── auth/                 # 认证模块
│   ├── image/                # 图片处理
│   └── ai/                   # AI 服务
└── api/
    └── routes/               # API 路由定义
```

---

## 🚀 快速开始

### 环境要求

- Go 1.21+
- PostgreSQL 15
- Redis 7

### 开发环境

```bash
# 安装依赖
go mod download

# 运行开发服务器
go run cmd/server/main.go

# 构建生产版本
go build -o server cmd/server/main.go
```

---

## 📦 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| **框架** | Gin v1.9 | Web 框架 |
| **ORM** | GORM v2 | 数据库操作 |
| **配置** | Viper v1.18 | 配置管理 |
| **日志** | Zap v1.26 | 高性能日志 |
| **认证** | JWT v5 | JWT 认证 |
| **验证** | validator v10 | 数据验证 |
| **任务队列** | Asynq v0.24 | 异步任务 |

---

## 📋 API 接口

### API 文档

**Swagger UI:** http://localhost:8000/swagger/index.html

**OpenAPI YAML:** [api/swagger.yaml](api/swagger.yaml)

### 用户相关

| 接口 | 方法 | 说明 |
|------|------|------|
| `/v1/users/profile` | POST | 创建用户档案 |
| `/v1/users/profile` | GET | 获取用户信息 |
| `/v1/users/profile` | PUT | 更新用户信息 |

### 饮食相关

| 接口 | 方法 | 说明 |
|------|------|------|
| `/v1/food/recognize` | POST | 拍照识别食物 |
| `/v1/food/records` | POST | 添加饮食记录 |
| `/v1/food/records/today` | GET | 获取今日饮食 |

### 体重相关

| 接口 | 方法 | 说明 |
|------|------|------|
| `/v1/weight/records` | POST | 记录体重 |
| `/v1/weight/records` | GET | 获取体重曲线 |

### AI 相关

| 接口 | 方法 | 说明 |
|------|------|------|
| `/v1/ai/encouragement` | POST | 获取 AI 鼓励 |
| `/v1/ai/chat` | POST | AI 对话 |

---

## 🗄️ 数据库

### 核心表

| 表名 | 说明 |
|------|------|
| `users` | 用户档案 |
| `food_records` | 饮食记录 |
| `weight_records` | 体重记录 |
| `ai_conversations` | AI 对话 |
| `ai_memories` | AI 记忆 |
| `food_database` | 食物库 |

详见：[internal/models/README.md](internal/models/README.md)

---

## 🧪 测试

```bash
# 运行测试
go test ./...

# 运行覆盖率测试
go test -cover ./...

# 生成覆盖率报告
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

---

## 📝 开发规范

### 代码风格

- 遵循 Go 官方规范
- 使用 `gofmt` 格式化
- 使用 `golint` 检查

### 项目结构

- `cmd/` - 应用入口
- `internal/` - 私有业务逻辑
- `pkg/` - 公共库

### 错误处理

```go
// ✅ 好的设计
if err != nil {
    return nil, fmt.Errorf("failed to create user: %w", err)
}

// ❌ 不好的设计
if err != nil {
    panic(err)
}
```

---

## 🔗 相关链接

- [技术架构文档](../docs/architecture.md)
- [API 路由](api/routes/README.md)
- [数据模型](internal/models/README.md)
- [项目首页](../README.md)

---

**最后更新：** 2026-04-06
