# Backend · Go + Gin

> 减肥 AI 助理的后端。实际技术栈：Go 1.21 + Gin + GORM + SQLite + Gemini 2.5-flash。

---

## 🚀 启动

```bash
cd backend
go mod download

# 带 AI：需要 Gemini key（可从 .env 加载）
source /usr/local/proxy1.sh                     # 如果你访问 Gemini 要走代理
export GEMINI_API_KEY=<你的 key>                # 或 set -a; source .env; set +a
make local-gemini                               # 用 config.gemini.yaml

# 不带 AI（AI 接口降级为 mock，仅 debug 模式允许）
make local                                      # 用 config.test.yaml
```

默认监听 `:8000`，SQLite DB 在 `/tmp/loss_weight.db`（配置里写的路径）。

### Makefile 目标

| 目标 | 作用 |
|---|---|
| `make help` | 列出目标 |
| `make local` | test 配置启动（无 key）|
| `make local-gemini` | gemini 配置启动（前置校验 `GEMINI_API_KEY`）|
| `make test` | 跑 `tests/run_api_tests.sh` |
| `make build` | 编译生产二进制到 `./server` |
| `make run-prod` | 用 `config.yaml` 启 `./server` |

---

## 📁 结构

```
backend/
├─ cmd/server/main.go           # 入口：配置加载 + 数据库 + gin 路由
├─ config.test.yaml             # test 配置（SQLite，无 key → AI 走 mock）
├─ config.gemini.yaml.example   # Gemini 配置模板（.gitignore 里已屏蔽真实 yaml）
├─ internal/
│  ├─ config/                   # viper 加载 + BindEnv（敏感 key 从环境变量）
│  ├─ database/                 # sqlite 连接 + auto-migrate
│  ├─ models/
│  │  ├─ auth.go                # UserAccount（phone/token/最后登录等）
│  │  ├─ user.go                # UserProfile（身高/体重/活动水平...）
│  │  ├─ food.go                # FoodRecord（含 portion/unit）
│  │  ├─ weight.go              # WeightRecord
│  │  ├─ exercise.go            # ExerciseRecord
│  │  ├─ ai.go                  # AIChatMessage + AIChatThread + UserFact
│  │  ├─ summary.go             # DailySummary
│  │  └─ sms.go                 # SMSCode
│  ├─ services/
│  │  ├─ auth_service.go        # 登录 / 建 profile
│  │  ├─ user_service.go
│  │  ├─ food_service.go
│  │  ├─ weight_service.go
│  │  ├─ exercise_service.go
│  │  ├─ ai_service.go          # Gemini 调用（chat / recognize / estimate-*）
│  │  └─ ai_memory.go           # RAG + 事实抽取 + 摘要滚动 + 滑窗
│  ├─ handlers/                 # gin 层
│  ├─ middleware/
│  │  └─ middleware.go          # CORS / Logger / Recovery / AuthRequired
│  └─ routes/routes.go          # 各业务分组的路由装配
└─ tests/
   ├─ run_api_tests.sh          # curl 冒烟
   └─ test_ai_chat.sh           # AI chat 单独冒烟
```

---

## 🔑 配置

配置优先级：**环境变量 > yaml > 默认值**。

敏感 key 显式绑到环境变量（见 `internal/config/config.go`）：

- `GEMINI_API_KEY` / `GEMINI_API_URL`
- `VISION_API_KEY` / `VISION_API_URL`（空则复用 GEMINI）
- `OPENAI_API_KEY` / `BAIDU_CV_API_KEY`
- `SECRET_KEY`

`config.gemini.yaml` 在 `.gitignore` 里，示例在 `config.gemini.yaml.example`。

---

## 📋 API 端点

### 健康
- `GET /health`

### 认证（`/v1/auth`）

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/sms/send` | — | 发送验证码 |
| POST | `/sms/login` | — | 手机号登录，返回 `{token, user_id, is_new_user, account}` |
| GET | `/me` | ✅ | 当前用户信息（含 profile）|
| POST | `/logout` | ✅ | 退出 |

鉴权用 `Authorization: Bearer <token>`。Token 格式：`token_<userID>_<yyyymmddHHMMSS>`，由 `middleware.AuthRequired` 解析后往 `gin.Context` 写 `user_id`。

### 用户（`/v1/users`）
- `POST /profile` / `GET /profile/:id` / `PUT /profile/:id` / `DELETE /profile/:id`
- `GET /profile/openid/:openid`

### 饮食（`/v1/food`）
- `POST /record` / `GET /records` / `GET /record/:id` / `PUT /record/:id` / `DELETE /record/:id`
- `GET /daily-summary`

### 运动（`/v1/exercise`）
- `POST /record` / `GET /records` / `GET /record/:id` / `PUT /record/:id` / `DELETE /record/:id`
- `GET /daily-summary`

### 体重（`/v1/weight`）
- `POST /record` / `GET /records` / `GET /record/:id` / `PUT /record/:id` / `DELETE /record/:id`
- `GET /trend`

### AI（`/v1/ai`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/chat` | 聊天（后端自动组装画像+事实+摘要+RAG+滑窗）|
| GET | `/chat/history` | 线程内消息 |
| POST | `/chat/thread` | 新建线程 |
| GET | `/chat/threads` | 用户线程列表 |
| POST | `/recognize` | 图片识别食物，`image_url` 支持 data URL 或 http(s) URL |
| POST | `/estimate-nutrition` | 文本估营养："一碗米饭 200g" |
| POST | `/estimate-exercise` | 文本估运动："跑步 5 公里 30 分钟" |
| POST | `/parse-weight` | 文本解析体重："68.5kg 早" |
| POST | `/daily-brief` | 今日简报（首页卡片数据源）|
| POST | `/encouragement` | AI 鼓励 |

---

## 🧠 AI 记忆系统

每次 `/v1/ai/chat` 的 context 组装：

```
[system]  用户画像 + 长期记忆事实 + 线程摘要
[system]  RAG 相关历史片段（embedding cosine 找 top-3）
[user/model...] 最近滑窗 10 条原文
[user]    本轮输入
```

异步后台（不阻塞主流程）：

- 每条消息入库后异步调 `text-embedding-004` 生成 768 维向量存 BLOB
- 每 6 条新消息触发事实抽取 → 写入 `user_facts`（去重）
- 线程消息 ≥ 20 时触发摘要压缩 → 写 `AIChatThread.Summary`

代码在 `internal/services/ai_memory.go`。

---

## 🗄️ 数据表（auto-migrate）

```go
models.UserProfile, models.UserSettings,
models.FoodRecord, models.WeightRecord, models.ExerciseRecord,
models.AIChatMessage, models.AIChatThread, models.UserFact,
models.DailySummary, models.SMSCode, models.UserAccount,
```

SQLite 文件位置取决于 `database_url`（默认 `sqlite:///tmp/loss_weight.db`）。

---

## 🧪 测试

```bash
# 手工 curl 冒烟
make test                  # 等价于 tests/run_api_tests.sh

# AI chat 专项
./tests/test_ai_chat.sh

# 前端 Playwright 的 backend_api_test.js 覆盖 14 条后端端到端流程
cd ../frontend && ./run_e2e_tests.sh --skip-build -- tests/backend_api_test.js
```

---

## 📝 Mock 降级行为

`debug: true` 的配置（`config.test.yaml` / `config.gemini.yaml`）允许 AI 接口在缺少 `GEMINI_API_KEY` 时返回写死的 mock。`debug: false`（生产）缺 key 直接 hard fail，避免静默兜底。

---

## 🔗 相关文档

- [项目总览](../README.md)
- [API 手工测试清单](../API_TESTS.md)
- [架构设计（部分愿景）](../docs/architecture.md)
