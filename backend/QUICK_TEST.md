# 后端 API 快速测试指南

> ⚠️ **已被取代**。最新的手工测试清单见 [../API_TESTS.md](../API_TESTS.md)，  
> 启动方式见 [README.md](README.md)。

## 🚀 启动服务

```bash
cd backend

# 方式 1: 使用 SQLite（推荐，无需数据库）
go mod tidy
go run cmd/server/main.go -config config.test.yaml

# 方式 2: 使用 PostgreSQL
# 1. 启动数据库
docker compose up -d db

# 2. 修改 config.yaml 配置
# database_url: postgresql://postgres:postgres@localhost:5432/lossweight?sslmode=disable

# 3. 运行服务
go run cmd/server/main.go
```

服务启动在：**http://localhost:8000**

## 📋 API 测试示例

### 1. 健康检查

```bash
curl -s http://localhost:8000/health | jq .
# 预期输出：{"status":"healthy"}
```

### 2. 创建用户档案

```bash
curl -s -X POST http://localhost:8000/v1/users/profile \
  -H "Content-Type: application/json" \
  -d '{
    "openid": "test_openid_123",
    "nickname": "张三",
    "gender": "male",
    "birthday": "1990-01-01",
    "height": 175,
    "current_weight": 75,
    "target_weight": 65,
    "activity_level": 2
  }' | jq .
```

### 3. 获取用户信息

```bash
# 按 ID 获取
curl -s http://localhost:8000/v1/users/profile/1 | jq .

# 按 OpenID 获取
curl -s http://localhost:8000/v1/users/profile/openid/test_openid_123 | jq .
```

### 4. 更新用户信息

```bash
curl -s -X PUT http://localhost:8000/v1/users/profile/1 \
  -H "Content-Type: application/json" \
  -d '{
    "current_weight": 74,
    "target_weight": 64
  }' | jq .
```

### 5. 创建食物记录

```bash
curl -s -X POST http://localhost:8000/v1/food/record \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "food_name": "红烧肉",
    "calories": 500,
    "protein": 20,
    "carbohydrates": 15,
    "fat": 40,
    "fiber": 2,
    "meal_type": "lunch"
  }' | jq .
```

### 6. 获取食物记录列表

```bash
# 获取所有记录
curl -s "http://localhost:8000/v1/food/records?user_id=1" | jq .

# 按日期范围获取
curl -s "http://localhost:8000/v1/food/records?user_id=1&start_date=2024-01-01&end_date=2024-12-31" | jq .
```

### 7. 获取每日营养汇总

```bash
curl -s "http://localhost:8000/v1/food/daily-summary?user_id=1&date=2024-01-01" | jq .
```

### 8. 创建体重记录

```bash
curl -s -X POST http://localhost:8000/v1/weight/record \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "weight": 75,
    "body_fat": 25,
    "muscle": 55,
    "water": 45,
    "bmi": 24.5
  }' | jq .
```

### 9. 获取体重记录列表

```bash
curl -s "http://localhost:8000/v1/weight/records?user_id=1" | jq .
```

### 10. 获取体重趋势

```bash
# 获取最近 30 天趋势
curl -s "http://localhost:8000/v1/weight/trend?user_id=1&days=30" | jq .

# 获取最近 7 天趋势
curl -s "http://localhost:8000/v1/weight/trend?user_id=1&days=7" | jq .
```

### 11. AI 食物识别（Mock 模式）

```bash
curl -s -X POST http://localhost:8000/v1/ai/recognize \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://example.com/food.jpg"
  }' | jq .

# 预期输出（Mock）：
# {
#   "food_name": "测试食物",
#   "calories": 300,
#   "protein": 15,
#   "carbohydrates": 40,
#   "fat": 10,
#   "fiber": 5,
#   "confidence": 0.95
# }
```

### 12. AI 鼓励助手（Mock 模式）

```bash
curl -s -X POST http://localhost:8000/v1/ai/encouragement \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "current_weight": 75,
    "target_weight": 65,
    "weight_loss": 5,
    "days_active": 30,
    "achievements": ["坚持记录 7 天", "减重 5kg"]
  }' | jq .

# 预期输出（Mock）：
# {
#   "message": "太棒了！你已经坚持了 30 天，减重 5.0 kg！继续保持，你一定能达成目标！💪",
#   "suggestions": [
#     "今天记得多喝水，保持身体水分",
#     "晚餐可以选择清淡的蔬菜沙拉",
#     "睡前做 10 分钟拉伸，帮助睡眠"
#   ]
# }
```

### 13. AI 聊天（Mock 模式）

```bash
curl -s -X POST http://localhost:8000/v1/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "messages": [
      {"role": "user", "content": "我该如何控制晚餐的热量？"}
    ]
  }' | jq .

# 预期输出（Mock）：
# {
#   "message_id": 1,
#   "role": "assistant",
#   "content": "你好！我是你的 AI 减肥助手。有什么我可以帮助你的吗？",
#   "thread_id": ""
# }
```

### 14. 创建 AI 对话线程

```bash
curl -s -X POST "http://localhost:8000/v1/ai/chat/thread?user_id=1" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "减肥咨询"
  }' | jq .
```

### 15. 获取对话线程列表

```bash
curl -s "http://localhost:8000/v1/ai/chat/threads?user_id=1" | jq .
```

### 16. 获取聊天记录

```bash
curl -s "http://localhost:8000/v1/ai/chat/history?user_id=1&thread_id=1&limit=50" | jq .
```

## 🧪 运行自动化测试脚本

### Bash 脚本测试

```bash
cd backend/tests
./run_api_tests.sh
```

### Go 测试

```bash
cd backend/tests
go test -v api_test.go
```

## 📊 完整的 API 端点列表

### 用户档案 (5 个)
- `POST /v1/users/profile` - 创建用户档案
- `GET /v1/users/profile/:id` - 获取用户档案
- `GET /v1/users/profile/openid/:openid` - 按 OpenID 获取
- `PUT /v1/users/profile/:id` - 更新用户档案
- `DELETE /v1/users/profile/:id` - 删除用户档案

### 食物记录 (6 个)
- `POST /v1/food/record` - 创建食物记录
- `GET /v1/food/records` - 获取食物记录列表
- `GET /v1/food/record/:id` - 获取单个记录
- `PUT /v1/food/record/:id` - 更新记录
- `DELETE /v1/food/record/:id` - 删除记录
- `GET /v1/food/daily-summary` - 每日营养汇总

### 体重记录 (6 个)
- `POST /v1/weight/record` - 创建体重记录
- `GET /v1/weight/records` - 获取体重记录列表
- `GET /v1/weight/record/:id` - 获取单个记录
- `PUT /v1/weight/record/:id` - 更新记录
- `DELETE /v1/weight/record/:id` - 删除记录
- `GET /v1/weight/trend` - 体重趋势

### AI 功能 (6 个)
- `POST /v1/ai/recognize` - 识别食物图片
- `POST /v1/ai/encouragement` - 获取 AI 鼓励
- `POST /v1/ai/chat` - AI 对话
- `GET /v1/ai/chat/history` - 获取聊天记录
- `POST /v1/ai/chat/thread` - 创建对话线程
- `GET /v1/ai/chat/threads` - 获取对话线程列表

## 🔧 配置 AI 服务

在 `config.yaml` 中添加 AI 配置以启用真实 AI 服务：

```yaml
# LLM API 配置（用于 AI 鼓励和聊天）
llm_api_key: your-llm-api-key
llm_api_url: https://api.openai.com/v1/chat/completions

# Vision API 配置（用于食物识别）
vision_api_key: your-vision-api-key
vision_api_url: https://api.openai.com/v1/chat/completions
```

**注意**：如果不配置 AI API，服务会使用 Mock 响应，不会报错。

## 📝 测试数据示例

### 用户档案数据

```json
{
  "id": 1,
  "openid": "test_openid_123",
  "nickname": "张三",
  "gender": "male",
  "height": 175,
  "current_weight": 75,
  "target_weight": 65,
  "activity_level": 2
}
```

### 食物记录数据

```json
{
  "id": 1,
  "user_id": 1,
  "food_name": "红烧肉",
  "calories": 500,
  "protein": 20,
  "carbohydrates": 15,
  "fat": 40,
  "meal_type": "lunch"
}
```

### 体重记录数据

```json
{
  "id": 1,
  "user_id": 1,
  "weight": 75,
  "body_fat": 25,
  "muscle": 55,
  "bmi": 24.5
}
```

## ⚠️ 常见问题

### 1. 端口被占用

**错误**：`Bind for :8000 failed: port is already allocated`

**解决**：修改 `config.yaml` 中的 `port` 配置

### 2. 数据库连接失败

**错误**：`failed to initialize database`

**解决**：
- 使用 SQLite：确保 `database_url: sqlite:///tmp/lossweight.db`
- 使用 PostgreSQL：确保数据库已启动且配置正确

### 3. JSON 解析失败

**错误**：`invalid character`

**解决**：检查 JSON 格式，确保使用双引号

## 🎯 下一步

1. 测试所有 API 端点确保功能正常
2. 根据需求调整 API 设计
3. 开发前端 Flutter 应用
4. 集成真实 AI 服务
