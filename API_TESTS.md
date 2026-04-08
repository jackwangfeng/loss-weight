# API 接口测试脚本生成完成

> ✅ 已创建完整的 API 接口测试脚本

---

## 📊 完成情况

### 生成的文件

| 文件 | 说明 | 类型 |
|------|------|------|
| `backend/tests/run_api_tests.sh` | Bash 测试脚本 | 可执行脚本 |
| `backend/tests/api_test.go` | Go 测试代码 | 单元测试 |
| `backend/tests/README.md` | 测试说明文档 | 文档 |

---

## 🚀 快速开始

### 方式 1：Bash 脚本（简单快捷）

```bash
# 1. 启动后端服务
cd backend
go run cmd/server/main.go

# 2. 在另一个终端运行测试
./tests/run_api_tests.sh

# 或指定 API 地址
TEST_BASE_URL=http://localhost:8000/v1 ./tests/run_api_tests.sh
```

### 方式 2：Go 测试

```bash
cd backend

# 运行测试
go test ./tests -v

# 生成覆盖率报告
go test ./tests -coverprofile=coverage.out
```

---

## 📋 测试用例总览

### 4 大模块，10 个测试用例

#### 1. 用户模块（3 个）
- ✅ 创建用户档案
- ✅ 获取用户档案
- ✅ 更新用户档案

#### 2. 饮食模块（3 个）
- ✅ 添加饮食记录
- ✅ 获取今日饮食汇总
- ✅ 获取饮食记录列表

#### 3. 体重模块（2 个）
- ✅ 记录体重
- ✅ 获取体重记录列表

#### 4. AI 模块（2 个）
- ✅ 获取 AI 鼓励
- ✅ AI 对话

---

## 📊 测试输出示例

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
```

---

## 🔧 测试特性

### 1. 自动 Token 管理

- 创建用户后自动获取 token
- 后续请求自动携带 token
- 无需手动配置

### 2. 彩色输出

- ✅ 绿色：测试通过
- ❌ 红色：测试失败
- 📋 黄色：模块标题

### 3. 详细日志

- 每个测试用例都有状态输出
- 失败时显示详细错误信息
- 最后输出测试数据摘要

### 4. 错误处理

- 自动检测 HTTP 状态码
- 解析 JSON 响应
- 友好的错误提示

---

## 📝 测试数据

### 默认测试用户

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

### 测试饮食记录

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

### 测试体重记录

```json
{
  "weight": 72.5,
  "note": "测试记录",
  "recorded_at": "2026-04-05T08:00:00Z"
}
```

---

## 🔍 故障排查

### 问题 1：连接被拒绝

**错误：** `curl: (7) Failed to connect to localhost port 8000`

**解决：**
```bash
# 确保后端服务正在运行
cd backend
go run cmd/server/main.go

# 检查端口
lsof -i :8000
```

### 问题 2：jq 未安装

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

### 问题 3：权限不足

**错误：** `Permission denied`

**解决：**
```bash
chmod +x backend/tests/run_api_tests.sh
```

---

## 📚 文档参考

| 文档 | 说明 |
|------|------|
| **[tests/README.md](backend/tests/README.md)** | 完整测试指南 |
| **[api/swagger.yaml](backend/api/swagger.yaml)** | API 文档 |
| **[api/README.md](backend/api/README.md)** | API 使用说明 |

---

## 🎯 下一步工作

### 高优先级

1. **启动后端服务**
   - 确保数据库已启动
   - 运行后端服务
   - 验证服务正常

2. **运行测试脚本**
   - 执行 `run_api_tests.sh`
   - 查看测试结果
   - 修复失败的测试

3. **添加更多测试**
   - 边界值测试
   - 错误场景测试
   - 性能测试

### 中优先级

4. **集成 CI/CD**
   - GitHub Actions
   - 自动化测试
   - 代码覆盖率检查

---

## 📊 测试统计

| 统计项 | 数量 |
|--------|------|
| **测试模块** | 4 个 |
| **测试用例** | 10 个 |
| **测试脚本** | 2 个 |
| **文档** | 3 个 |

---

## 🔗 相关链接

- **测试脚本：** [backend/tests/run_api_tests.sh](backend/tests/run_api_tests.sh)
- **测试文档：** [backend/tests/README.md](backend/tests/README.md)
- **API 文档：** [backend/api/swagger.yaml](backend/api/swagger.yaml)
- **后端指南：** [backend/README.md](backend/README.md)

---

**测试脚本生成时间：** 2026-04-06  
**测试框架：** Bash + curl + jq  
**Go 测试框架：** testing
