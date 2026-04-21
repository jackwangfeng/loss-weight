# API 手工测试清单

> 本文档以**代码实际端点**为准。自动化测试见 `frontend/tests/backend_api_test.js`（14 条串行端到端，随 Playwright 跑）。

---

## 🚀 起后端

```bash
cd backend
source /usr/local/proxy1.sh                     # 访问 Gemini 需要代理的话
set -a && source .env && set +a                 # 加载 GEMINI_API_KEY
SKIP_SMS_VERIFY=true go run cmd/server/main.go -config config.gemini.yaml
```

无 key 模式：`make local`（用 `config.test.yaml`，AI 接口走 mock）。

---

## 📋 端点速查

### 无需鉴权

```bash
# 健康检查
curl http://localhost:8000/health

# 发送短信（SKIP_SMS_VERIFY=true 下立即成功）
curl -X POST http://localhost:8000/v1/auth/sms/send \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","purpose":"login"}'

# 登录（test 模式下 code 固定 123456）
curl -X POST http://localhost:8000/v1/auth/sms/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","code":"123456"}'
# → {"token":"token_1_20260422...", "user_id":1, "is_new_user":false, "account":{...}}
```

拿到 token 后导出：

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/v1/auth/sms/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","code":"123456"}' | jq -r .token)
```

### 需要鉴权（`Authorization: Bearer $TOKEN`）

```bash
# 当前用户
curl http://localhost:8000/v1/auth/me -H "Authorization: Bearer $TOKEN"

# 退出
curl -X POST http://localhost:8000/v1/auth/logout -H "Authorization: Bearer $TOKEN"
```

---

## 👤 用户

```bash
# 创建档案（登录时已自动建一份默认，通常不用手工创建）
curl -X POST http://localhost:8000/v1/users/profile \
  -H "Content-Type: application/json" \
  -d '{"openid":"phone_13800138000","nickname":"测试","current_weight":70,"target_weight":65}'

# 获取
curl http://localhost:8000/v1/users/profile/1

# 更新
curl -X PUT http://localhost:8000/v1/users/profile/1 \
  -H "Content-Type: application/json" \
  -d '{"height":175,"target_calorie":1800}'
```

---

## 🍽 饮食

```bash
# 记录
curl -X POST http://localhost:8000/v1/food/record \
  -H "Content-Type: application/json" \
  -d '{
    "user_id":1,
    "food_name":"宫保鸡丁",
    "calories":520, "protein":25, "fat":30, "carbohydrates":15,
    "portion":200, "unit":"g",
    "meal_type":"lunch"
  }'

# 列表
curl "http://localhost:8000/v1/food/records?user_id=1"

# 每日汇总
curl "http://localhost:8000/v1/food/daily-summary?user_id=1"

# 删除 / 更新：PUT /food/record/:id  DELETE /food/record/:id
```

---

## 🏃 运动

```bash
# 记录
curl -X POST http://localhost:8000/v1/exercise/record \
  -H "Content-Type: application/json" \
  -d '{
    "user_id":1,
    "type":"跑步", "duration_min":30, "intensity":"medium",
    "calories_burned":350, "distance":5
  }'

# 列表 / 汇总（类似饮食）
curl "http://localhost:8000/v1/exercise/records?user_id=1"
curl "http://localhost:8000/v1/exercise/daily-summary?user_id=1"
```

---

## ⚖️ 体重

```bash
# 记录
curl -X POST http://localhost:8000/v1/weight/record \
  -H "Content-Type: application/json" \
  -d '{"user_id":1, "weight":68.5, "body_fat":22, "note":"晨重"}'

# 列表 / 趋势
curl "http://localhost:8000/v1/weight/records?user_id=1"
curl "http://localhost:8000/v1/weight/trend?user_id=1&days=30"
```

---

## 🤖 AI

```bash
# 文本估营养
curl -X POST http://localhost:8000/v1/ai/estimate-nutrition \
  -H "Content-Type: application/json" \
  -d '{"text":"一碗米饭 200g"}'

# 文本估运动消耗
curl -X POST http://localhost:8000/v1/ai/estimate-exercise \
  -H "Content-Type: application/json" \
  -d '{"text":"跑步 5 公里 30 分钟"}'

# 文本解析体重
curl -X POST http://localhost:8000/v1/ai/parse-weight \
  -H "Content-Type: application/json" \
  -d '{"text":"68.5kg 早"}'

# 图片识别食物（data URL 或 http URL 都行）
curl -X POST http://localhost:8000/v1/ai/recognize \
  -H "Content-Type: application/json" \
  -d '{"image_url":"data:image/jpeg;base64,...."}'

# 今日 AI 简报（首页卡片数据源）
curl -X POST http://localhost:8000/v1/ai/daily-brief \
  -H "Content-Type: application/json" \
  -d '{"user_id":1}'

# AI 聊天（记忆系统自动组装上下文，不必传历史）
curl -X POST http://localhost:8000/v1/ai/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "user_id":1,
    "thread_id":"t1",
    "messages":[{"role":"user","content":"晚餐建议？"}]
  }'

# 聊天线程 + 历史
curl -X POST "http://localhost:8000/v1/ai/chat/thread?user_id=1" \
  -H "Content-Type: application/json" -d '{"title":"减肥计划"}'
curl "http://localhost:8000/v1/ai/chat/threads?user_id=1"
curl "http://localhost:8000/v1/ai/chat/history?user_id=1&thread_id=1"

# AI 鼓励
curl -X POST http://localhost:8000/v1/ai/encouragement \
  -H "Content-Type: application/json" \
  -d '{"user_id":1,"current_weight":70,"target_weight":65,"weight_loss":3,"days_active":15}'
```

---

## 🧪 自动化

### Shell 冒烟

```bash
cd backend
./tests/run_api_tests.sh                   # 主路径
./tests/test_ai_chat.sh                    # 只测 chat
```

### Playwright E2E（14 条后端 + 12 条 UI）

```bash
cd frontend
./run_e2e_tests.sh                         # 一键 build + serve + test
./run_e2e_tests.sh --skip-build -- tests/backend_api_test.js   # 只跑后端那 14 条
```

---

## ⚠️ Mock vs 真 Gemini

- 后端启动时 `debug: true` + 没有 `GEMINI_API_KEY`：AI 接口**降级返回 mock**（写死的文本），日志会 `Warn`
- `debug: false` + 没 key：hard fail 500，避免生产环境静默骗调用方
- 如果某个 AI 测试返回了固定的 `你好！我是你的 AI 减肥助手……`——那就是在 mock

想验证是不是真的调 Gemini：问两个不同的问题，回复内容应当不同。

---

## 🔗 相关

- [后端 README](backend/README.md) · 完整路由表 + 数据表
- [前端 README](frontend/README.md)
- [E2E 测试指南](frontend/tests/README.md)
