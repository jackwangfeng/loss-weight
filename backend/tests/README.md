# API 接口测试

> 完整的 API 接口测试脚本和说明

---

## 📁 测试文件

```
tests/
├── README.md                 # 本文档
├── api_test.go               # Go 测试代码
└── run_api_tests.sh          # Bash 测试脚本
```

---

## 🚀 快速开始

### 方式 1：Bash 脚本（推荐）

**前提条件：**
- bash
- curl
- jq

**运行测试：**
```bash
# 1. 给脚本添加执行权限
chmod +x tests/run_api_tests.sh

# 2. 启动后端服务
cd backend
go run cmd/server/main.go

# 3. 在另一个终端运行测试
./tests/run_api_tests.sh

# 或者指定 API 地址
TEST_BASE_URL=http://localhost:8000/v1 ./tests/run_api_tests.sh
```

---

### 方式 2：Go 测试

**运行测试：**
```bash
cd backend

# 运行所有测试
go test ./tests -v

# 运行特定测试
go test ./tests -run TestAPI -v

# 生成覆盖率报告
go test ./tests -coverprofile=coverage.out
go tool cover -html=coverage.out
```

---

## 📋 测试用例

### 1. 用户模块

| 测试项 | 接口 | 说明 |
|--------|------|------|
| ✅ 创建用户档案 | `POST /users/profile` | 创建新用户并获取 token |
| ✅ 获取用户档案 | `GET /users/profile` | 使用 token 获取用户信息 |
| ✅ 更新用户档案 | `PUT /users/profile` | 更新用户体重等信息 |

**测试数据示例：**
```json
{
  "nickname": "测试用户",
  "gender": "male",
  "age": 28,
  "height": 175,
  "current_weight": 75.0,
  "target_weight": 65.0,
  "target_date": "2026-08-01"
}
```

---

### 2. 饮食模块

| 测试项 | 接口 | 说明 |
|--------|------|------|
| ✅ 添加饮食记录 | `POST /food/records` | 记录一餐饮食 |
| ✅ 获取今日饮食汇总 | `GET /food/records/today` | 获取今日热量和营养素汇总 |
| ✅ 获取饮食记录列表 | `GET /food/records` | 获取饮食记录列表（分页） |

**测试数据示例：**
```json
{
  "food_name": "宫保鸡丁",
  "calories": 520,
  "protein": 25,
  "fat": 30,
  "carbs": 15,
  "portion": 200,
  "unit": "g",
  "meal_type": "lunch",
  "record_type": "manual"
}
```

---

### 3. 体重模块

| 测试项 | 接口 | 说明 |
|--------|------|------|
| ✅ 记录体重 | `POST /weight/records` | 记录当前体重 |
| ✅ 获取体重记录列表 | `GET /weight/records` | 获取体重历史记录 |

**测试数据示例：**
```json
{
  "weight": 72.5,
  "note": "测试记录",
  "recorded_at": "2026-04-05T08:00:00Z"
}
```

---

### 4. AI 模块

| 测试项 | 接口 | 说明 |
|--------|------|------|
| ✅ 获取 AI 鼓励 | `POST /ai/encouragement` | 根据场景获取 AI 鼓励 |
| ✅ AI 对话 | `POST /ai/chat` | 与 AI 助手对话 |

**测试数据示例：**
```json
{
  "event": "meal_logged",
  "context": {
    "meal_type": "lunch",
    "calories": 520,
    "daily_total": 1200
  }
}
```

---

## 🎯 测试流程

### 完整流程

```
1. 创建用户档案
   ↓
2. 获取 Token
   ↓
3. 使用 Token 测试其他接口
   ├─ 用户模块
   ├─ 饮食模块
   ├─ 体重模块
   └─ AI 模块
   ↓
4. 输出测试报告
```

---

## 📊 测试输出

### 成功示例

```
========================================
🚀 减肥 AI 助理 - API 接口测试
========================================

测试配置:
  Base URL: http://localhost:8000/v1
  超时时间：30s

📋 测试用户模块
----------------------------------------
[✅ PASS] 创建用户档案：UserID=1001
[✅ PASS] 获取用户档案：状态码=200
[✅ PASS] 更新用户档案：状态码=200

🍽️  测试饮食模块
----------------------------------------
[✅ PASS] 添加饮食记录：状态码=200
[✅ PASS] 获取今日饮食汇总：状态码=200
[✅ PASS] 获取饮食记录列表：状态码=200

⚖️  测试体重模块
----------------------------------------
[✅ PASS] 记录体重：状态码=200
[✅ PASS] 获取体重记录列表：状态码=200

🤖 测试 AI 模块
----------------------------------------
[✅ PASS] 获取 AI 鼓励：消息：记录得真及时！👍
[✅ PASS] AI 对话：回复：抱抱～偶尔多吃很正常啦

========================================
✅ 所有测试完成！
========================================

测试数据：
  Token: eyJhbGciOiJIUzI1NiIsInR5cCI...
  UserID: 1001
```

---

## 🔧 故障排查

### 常见问题

#### 1. 连接被拒绝

**错误：** `curl: (7) Failed to connect to localhost port 8000`

**解决：**
```bash
# 确保后端服务正在运行
cd backend
go run cmd/server/main.go

# 检查端口是否被占用
lsof -i :8000
```

#### 2. Token 无效

**错误：** `401 Unauthorized`

**解决：**
- 确保创建用户时成功获取 token
- 检查 token 是否过期（有效期 7 天）
- 确认 Authorization header 格式正确

#### 3. jq 未安装

**错误：** `command not found: jq`

**解决：**
```bash
# macOS
brew install jq

# Ubuntu/Debian
apt-get install jq

# CentOS/RHEL
yum install jq
```

---

## 📝 自定义测试

### 修改测试数据

编辑 `run_api_tests.sh` 中的测试数据：

```bash
# 修改创建用户的数据
CREATE_USER_DATA='{
    "nickname": "你的测试用户",
    "gender": "male",
    "age": 28,
    ...
}'
```

### 添加新测试用例

在脚本末尾添加新的测试：

```bash
# 新增测试
echo "测试新功能..."
NEW_TEST_DATA='{...}'
RESPONSE=$(http_post "/new/endpoint" "$NEW_TEST_DATA" "$TOKEN")
STATUS_CODE=$(echo "$RESPONSE" | jq -r '.code // empty')

if [ "$STATUS_CODE" == "200" ]; then
    print_result "新功能测试" "PASS" "状态码=$STATUS_CODE"
else
    print_result "新功能测试" "FAIL" "状态码=$STATUS_CODE"
fi
```

---

## 🎯 最佳实践

### 1. 测试隔离

每个测试应该独立，不依赖其他测试的结果。

### 2. 清理数据

测试完成后清理测试数据：

```bash
# 添加清理步骤
cleanup() {
    echo "清理测试数据..."
    # 删除测试用户等
}

trap cleanup EXIT
```

### 3. 断言明确

确保每个测试都有明确的断言：

```bash
if [ "$STATUS_CODE" == "200" ]; then
    print_result "测试" "PASS"
else
    print_result "测试" "FAIL"
    exit 1  # 失败时退出
fi
```

---

## 🔗 相关链接

- [API 文档](../api/swagger.yaml)
- [API 说明](../api/README.md)
- [后端指南](../README.md)
- [技术架构](../../docs/architecture.md)

---

**最后更新：** 2026-04-06
