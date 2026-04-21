# 减肥 AI 助理 · Loss Weight AI Assistant

> AI 驱动的智能减肥助理：拍照识别食物、文本/语音记录饮食运动体重、每日 AI 简报、真·长期记忆的聊天教练

---

## 🏗 技术栈（实际）

| 层 | 选型 |
|---|---|
| 前端 | Flutter 3.38（iOS / Android / Web 三端），Provider 状态管理，Dio HTTP，fl_chart，image_picker，**speech_to_text**（语音输入）|
| 后端 | Go 1.21 + Gin + GORM + SQLite（默认）/ Postgres（可选），Viper 配置，Zap 日志 |
| AI | Google Gemini 2.5-flash（文本/视觉）+ text-embedding-004（RAG 检索）|
| 认证 | 手机号 + 短信验证码 → 简单 token（非 JWT），后续可换 |
| 部署 | 本地 `go run` + `flutter build web`，E2E 测试靠 Node 静态服务器 serve `build/web`|

---

## 🚀 快速启动（本地开发）

### 1) 后端

```bash
cd backend

# AI 模式：需要 Gemini key 和代理（如果需要）
export GEMINI_API_KEY=<你的 key>      # 可用 .env + `set -a; source .env; set +a`
source /usr/local/proxy1.sh            # 如果访问 Gemini 需要代理
make local-gemini                      # 用 config.gemini.yaml + 跳过短信验证
```

不想调 Gemini 时（所有 AI 接口降级为 mock，仅 `debug=true` 下生效）：
```bash
make local                             # 用 config.test.yaml
```

端口：`8000`（配置在 `config.*.yaml`）

### 2) 前端（Web 模式，适合日常开发和 E2E 测试）

```bash
cd frontend
flutter build web --release            # ~20s
node tests/static_server.js            # 零依赖 Node 静态服务器，serve build/web 到 :8888
```

浏览器开 `http://localhost:8888`。

或调试模式（hot reload）：
```bash
flutter run -d chrome
```

### 3) E2E 测试一条龙

```bash
cd frontend && ./run_e2e_tests.sh      # build + serve + 跑 Playwright + 清理
./run_e2e_tests.sh --skip-build        # 跳过 build（改测试时）
```

当前 **26/26 通过**，约 50s。

---

## 🧭 应用结构

**底部导航 4 个 tab**：

```
首页 · 记录 · AI · 我的
         │
         ▼ (内部 TabBar)
      饮食 | 运动 | 体重
```

**首页**：今日 AI 简报卡（目标/吃/烧/剩余 + AI 一句话建议）+ 体重概览 + 快捷入口

**记录**：饮食 / 运动 / 体重 三个子 tab，**每个都支持**：
- 手动填写
- **AI 文本解析**：输入 "一碗米饭 200g" / "跑步 5 公里 30 分钟" / "68.5kg 早"
- **语音输入**：点话筒说话，自动转写 → AI 解析 → 填表
- 饮食额外支持：拍照识别、常吃食物快选

**AI**：聊天入口。进入空对话时 AI 主动基于当前数据打招呼。**带真·长期记忆**（见下）。

**我的**：编辑 8 个字段的资料表（昵称 / 性别 / 生日 / 身高 / 当前体重 / 目标体重 / 活动水平 / 每日目标热量）

---

## 🧠 AI 记忆系统（Chat 接口的 5 层上下文）

每次调 `/v1/ai/chat` 时，后端自动组装：

1. **实时画像**——从 DB 查 profile + 今日饮食 + 近 7 天体重趋势
2. **长期记忆**——`user_facts` 表里 LLM 异步抽取的结构化偏好/约束（示例：*"乳糖不耐受"、"讨厌跑步"、"周三有瑜伽课"*）
3. **滚动摘要**——thread 消息 ≥ 20 时压缩老消息成 200–400 字摘要
4. **向量检索 RAG**——对当前问题做 embedding，cosine 找 top-3 最相关历史消息
5. **最近滑窗**——最近 10 条原文

效果：AI 真的记得你的约束。推荐晚餐时会自动避开牛奶（乳糖不耐）、安排运动时绕开跑步。

---

## 📋 API 全量端点

| 组 | 方法 & 路径 | 说明 |
|---|---|---|
| 健康 | `GET /health` | 存活检查 |
| 认证 | `POST /v1/auth/sms/send` | 发送短信验证码 |
| 认证 | `POST /v1/auth/sms/login` | 手机号 + 验证码登录（test 配置下 code=`123456`）|
| 认证 | `GET /v1/auth/me`（鉴权）| 当前用户信息 |
| 认证 | `POST /v1/auth/logout`（鉴权）| 退出登录 |
| 用户 | `POST/GET/PUT/DELETE /v1/users/profile[/:id]` | 用户档案 CRUD |
| 饮食 | `POST/GET/PUT/DELETE /v1/food/record[s][/:id]` | 饮食 CRUD |
| 饮食 | `GET /v1/food/daily-summary` | 每日热量汇总 |
| 运动 | `POST/GET/PUT/DELETE /v1/exercise/record[s][/:id]` | 运动 CRUD |
| 运动 | `GET /v1/exercise/daily-summary` | 每日消耗汇总 |
| 体重 | `POST/GET/PUT/DELETE /v1/weight/record[s][/:id]` | 体重 CRUD |
| 体重 | `GET /v1/weight/trend` | 体重趋势 |
| AI | `POST /v1/ai/chat` | 聊天（带记忆）|
| AI | `GET /v1/ai/chat/history` | 聊天历史 |
| AI | `POST /v1/ai/chat/thread` | 新建对话线程 |
| AI | `GET /v1/ai/chat/threads` | 用户对话列表 |
| AI | `POST /v1/ai/recognize` | 图片识别食物（data URL / http URL）|
| AI | `POST /v1/ai/estimate-nutrition` | 文本估营养素 |
| AI | `POST /v1/ai/estimate-exercise` | 文本估运动消耗 |
| AI | `POST /v1/ai/parse-weight` | 文本解析体重 |
| AI | `POST /v1/ai/daily-brief` | 今日 AI 简报（首页卡片数据源）|
| AI | `POST /v1/ai/encouragement` | AI 鼓励 |

---

## 📁 代码地图

```
loss-weight/
├─ README.md                    # 你在这里
├─ API_TESTS.md                 # API 手工测试清单
├─ docs/
│  ├─ prd-mvp.md                # 产品需求（设计阶段）
│  ├─ architecture.md           # 技术架构（部分内容是愿景）
│  ├─ roadmap.md                # 迭代路线图
│  └─ prototype-mvp.md          # 原型
├─ backend/
│  ├─ README.md                 # 后端指南
│  ├─ Makefile                  # make local / local-gemini / test
│  ├─ config.test.yaml          # 测试配置（无 key，AI 走 mock）
│  ├─ config.gemini.yaml.example # Gemini 配置模板（key 从环境变量注入）
│  ├─ cmd/server/main.go        # 入口
│  ├─ internal/
│  │  ├─ config/                # viper 配置
│  │  ├─ database/              # sqlite 初始化 + auto-migrate
│  │  ├─ models/                # 8 个表（user/food/weight/exercise/ai 等）
│  │  ├─ services/              # 业务逻辑，含 ai_memory.go 记忆系统
│  │  ├─ handlers/              # gin handler
│  │  ├─ middleware/            # CORS + Logger + Recovery + AuthRequired
│  │  └─ routes/
│  └─ tests/
│     ├─ run_api_tests.sh       # curl 版 API 冒烟
│     └─ test_ai_chat.sh        # 单独测 AI chat
└─ frontend/
   ├─ README.md                 # 前端指南
   ├─ pubspec.yaml              # Flutter 依赖
   ├─ run_e2e_tests.sh          # 一键 build+serve+test+cleanup
   ├─ lib/
   │  ├─ main.dart              # Web 端强制开 Semantics（Playwright 要）
   │  ├─ models/                # Dart 数据模型
   │  ├─ services/              # API 客户端
   │  ├─ providers/             # Provider 状态
   │  ├─ screens/               # 6 个页面 + records 外壳
   │  └─ widgets/
   │     └─ voice_input_button.dart  # 通用语音按钮
   └─ tests/
      ├─ static_server.js       # Node 零依赖静态服务器
      ├─ flutter_canvas_test.js # 12 个 UI 测试
      └─ backend_api_test.js    # 14 个后端串行测试
```

---

## 🧪 测试运行概览

- **后端手工冒烟**：`backend/tests/run_api_tests.sh`（curl + jq）
- **Playwright E2E**：`frontend/run_e2e_tests.sh`，26 条用例覆盖 UI 导航 + 后端全链路，约 50 秒
- **对话记忆端到端**：直接和后端对话 5-10 轮后查 `user_facts` 表能看到 LLM 抽取的事实

---

## 📄 许可证

MIT
