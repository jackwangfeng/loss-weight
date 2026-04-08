# 减肥 AI 助理 - Loss Weight AI Assistant

> 一款让用户「轻松减肥、量化减肥」的 AI 助理应用

---

## 📖 项目概述

**产品定位：** AI 驱动的智能减肥助理

**核心价值：**
- 📸 **拍照就知道吃多少** - AI 识别食物热量
- 🤖 **AI 陪你减肥** - 大模型驱动的鼓励助手
- 📊 **量化看得见** - 热量预算、体重曲线、目标预测

**Slogan：** 「轻松减肥，AI 陪你」

---

## 🗺️ 项目地图

```
loss-weight/
│
├── 📄 README.md                  # 项目总览（本文档）
├── 📄 LICENSE
├── 📄 .gitignore
│
├── 📁 docs/                      # 📚 项目文档
│   ├── README.md                 # 文档导航
│   ├── prd-mvp.md                # MVP 产品需求文档
│   ├── roadmap.md                # 远期功能规划
│   ├── prototype-mvp.md          # MVP 原型设计
│   └── architecture.md           # 技术架构设计
│
├── 📁 backend/                   # 🔧 后端服务 (Go + Gin)
│   ├── README.md                 # 后端开发指南
│   ├── IMPLEMENTATION.md         # 实现文档
│   ├── BACKEND_COMPLETE.md       # 完成总结
│   ├── cmd/
│   │   └── server/
│   │       └── main.go           # 应用入口
│   ├── internal/
│   │   ├── models/               # 数据库模型
│   │   ├── services/             # 业务服务
│   │   ├── handlers/             # HTTP 处理器
│   │   ├── middleware/           # 中间件
│   │   ├── routes/               # API 路由
│   │   ├── config/               # 配置管理
│   │   └── database/             # 数据库初始化
│   ├── api/
│   │   └── swagger.yaml          # API 文档
│   ├── tests/
│   │   ├── run_api_tests.sh      # Bash 测试脚本
│   │   └── api_test.go           # Go 测试
│   ├── go.mod                    # Go 依赖
│   ├── config.yaml               # 配置文件
│   └── Dockerfile                # Docker 镜像
│
├── 📁 frontend/                  # 📱 前端应用 (Flutter)
│   ├── README.md                 # 前端开发指南
│   ├── lib/
│   │   ├── README.md             # Flutter 代码说明
│   │   ├── main.dart             # 应用入口
│   │   ├── screens/              # 页面组件
│   │   │   └── README.md         # 页面说明
│   │   ├── widgets/              # 可复用组件
│   │   │   └── README.md         # 组件说明
│   │   ├── services/             # API 服务
│   │   │   └── README.md         # 服务说明
│   │   ├── models/               # 数据模型
│   │   │   └── README.md         # 模型说明
│   │   └── utils/                # 工具函数
│   │       └── README.md         # 工具说明
│   ├── pubspec.yaml              # Flutter 依赖
│   └── test/                     # 测试代码
│
└── 📁 docker-compose.yml         # Docker 编排

```

---

## 🚀 快速开始

### 环境要求

- Python 3.11+
- Flutter 3.x
- PostgreSQL 15
- Redis 7
- Docker & Docker Compose

### 开发环境启动

```bash
# 1. 克隆项目
git clone https://github.com/your-org/loss-weight.git
cd loss-weight

# 2. 启动开发环境（数据库 + 缓存）
docker-compose up -d db redis chroma

# 3. 启动后端服务（Go）
cd backend
go mod download
go run cmd/server/main.go

# 4. 启动前端应用
cd frontend
flutter pub get
flutter run
```

### 访问服务

- **后端 API 文档：** http://localhost:8000/docs
- **前端应用：** 自动启动模拟器

---

## 📋 功能规划

### MVP 阶段（当前）

| 功能模块 | 状态 | 说明 |
|---------|------|------|
| 用户档案 | 📝 设计中 | 建立减脂目标 |
| 饮食记录 | 📝 设计中 | 拍照识别 + 搜索 |
| 体重记录 | 📝 设计中 | 记录 + 曲线 |
| AI 鼓励助手 | 📝 设计中 | 大模型驱动 |
| 今日概览 | 📝 设计中 | 数据汇总 |

### 远期规划

| 阶段 | 核心功能 | 预计周期 |
|------|---------|---------|
| **二期** | 智能推荐 + 运动记录 | Q3 2026 |
| **三期** | 强化对话 AI + 情绪识别 | Q4 2026 |
| **四期** | 习惯系统 + 社交功能 | Q1 2027 |
| **五期** | 会员订阅 + 商业化 | Q2 2027 |
| **六期** | 教练入驻 + 平台化 | Q3 2027 |

详细规划见：[docs/roadmap.md](docs/roadmap.md)

---

## 📚 文档导航

| 文档类型 | 链接 | 说明 |
|---------|------|------|
| **产品需求** | [docs/prd-mvp.md](docs/prd-mvp.md) | MVP 功能需求详细说明 |
| **远期规划** | [docs/roadmap.md](docs/roadmap.md) | 6 期功能规划 + 商业演进 |
| **原型设计** | [docs/prototype-mvp.md](docs/prototype-mvp.md) | 8 个核心页面交互设计 |
| **技术架构** | [docs/architecture.md](docs/architecture.md) | 技术选型 + 数据库 + API 设计 |

---

## 🛠️ 技术栈

### 后端
- **框架：** Gin (Go 1.21+)
- **数据库：** PostgreSQL 15
- **ORM：** GORM v2
- **缓存：** Redis 7
- **向量库：** Chroma (AI 记忆)
- **认证：** JWT
- **任务队列：** Asynq
- **日志：** Zap
- **配置：** Viper

### 前端
- **框架：** Flutter 3.x
- **状态管理：** Provider / Riverpod
- **网络请求：** Dio
- **本地存储：** Hive

### AI 服务
- **食物识别：** 百度 AI / 阿里云 CV
- **大模型：** 通义千问 / GPT-4
- **Embedding：** text-embedding-3

### 基础设施
- **容器化：** Docker + Docker Compose
- **部署：** 阿里云 ECS / AWS EC2
- **监控：** Prometheus + Grafana
- **日志：** ELK Stack

---

## 👥 团队协作

### Git 工作流

```bash
# 功能开发
git checkout -b feature/feature-name
git commit -m "feat: add feature-name"
git push origin feature/feature-name

# 修复 bug
git checkout -b fix/bug-name
git commit -m "fix: resolve bug-name"
git push origin fix/bug-name
```

### 提交规范

- `feat:` 新功能
- `fix:` Bug 修复
- `docs:` 文档更新
- `style:` 代码格式
- `refactor:` 重构
- `test:` 测试相关
- `chore:` 构建/工具

---

## 📊 开发进度

| 阶段 | 开始时间 | 结束时间 | 状态 |
|------|---------|---------|------|
| 需求分析 | 2026-04-01 | 2026-04-05 | ✅ 已完成 |
| 原型设计 | 2026-04-05 | 2026-04-06 | ✅ 已完成 |
| 技术架构 | 2026-04-06 | 2026-04-07 | ✅ 已完成 |
| 框架搭建 | 2026-04-07 | 2026-04-10 | 🔄 进行中 |
| 功能开发 | 2026-04-10 | 2026-05-10 | ⏳ 待开始 |
| 测试优化 | 2026-05-10 | 2026-05-20 | ⏳ 待开始 |
| 上线部署 | 2026-05-20 | 2026-05-25 | ⏳ 待开始 |

---

## 📝 许可证

MIT License

---

## 🔗 相关链接

- [产品需求文档](docs/prd-mvp.md)
- [技术架构文档](docs/architecture.md)
- [原型设计文档](docs/prototype-mvp.md)
- [远期规划文档](docs/roadmap.md)

---

**最后更新：** 2026-04-06
# loss-weight
