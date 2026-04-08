# API 文档 (Swagger/OpenAPI)

> 本目录包含完整的 OpenAPI 3.0 规范文档

---

## 📁 文件结构

```
api/
├── README.md                 # 本文档
├── swagger.yaml              # OpenAPI 3.0 规范文件
└── routes/
    ├── routes.go             # 路由汇总
    ├── users.go              # 用户路由
    ├── food.go               # 饮食路由
    ├── weight.go             # 体重路由
    └── ai.go                 # AI 路由
```

---

## 📖 Swagger 文档

### 文件说明

**swagger.yaml** 包含完整的 API 定义：

- **版本：** OpenAPI 3.0.3
- **API 版本：** 1.0.0
- **协议：** HTTP/HTTPS
- **认证：** JWT Bearer Token

### 在线查看

启动服务后访问：

```
http://localhost:8000/swagger/index.html
```

或使用 Swagger UI 的在线版本导入 `swagger.yaml` 文件。

---

## 🔐 认证方式

### JWT Bearer Token

**获取 Token：**
```bash
POST /v1/users/profile
Content-Type: application/json

{
  "nickname": "小明",
  "gender": "male",
  "age": 28,
  "height": 175,
  "current_weight": 75.0,
  "target_weight": 65.0
}

# 响应包含 token
{
  "code": 200,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**使用 Token：**
```bash
GET /v1/users/profile
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## 📋 API 模块

### 1. 用户模块 (/users)

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| `/users/profile` | POST | 创建用户档案 | ❌ |
| `/users/profile` | GET | 获取用户信息 | ✅ |
| `/users/profile` | PUT | 更新用户信息 | ✅ |

**示例：创建用户**
```bash
curl -X POST http://localhost:8000/v1/users/profile \
  -H "Content-Type: application/json" \
  -d '{
    "nickname": "小明",
    "gender": "male",
    "age": 28,
    "height": 175,
    "current_weight": 75.0,
    "target_weight": 65.0
  }'
```

---

### 2. 饮食模块 (/food)

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| `/food/recognize` | POST | 拍照识别食物 | ✅ |
| `/food/records` | POST | 添加饮食记录 | ✅ |
| `/food/records` | GET | 获取饮食列表 | ✅ |
| `/food/records/today` | GET | 今日饮食汇总 | ✅ |
| `/food/records/{id}` | PUT | 更新饮食记录 | ✅ |
| `/food/records/{id}` | DELETE | 删除饮食记录 | ✅ |

**示例：拍照识别**
```bash
curl -X POST http://localhost:8000/v1/food/recognize \
  -H "Authorization: Bearer {token}" \
  -F "image=@/path/to/food.jpg"
```

**示例：添加饮食记录**
```bash
curl -X POST http://localhost:8000/v1/food/records \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "food_name": "宫保鸡丁",
    "calories": 520,
    "protein": 25,
    "fat": 30,
    "carbs": 15,
    "portion": 200,
    "unit": "g",
    "meal_type": "lunch",
    "record_type": "manual"
  }'
```

---

### 3. 体重模块 (/weight)

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| `/weight/records` | POST | 记录体重 | ✅ |
| `/weight/records` | GET | 获取体重列表 | ✅ |
| `/weight/records/{id}` | PUT | 更新体重记录 | ✅ |
| `/weight/records/{id}` | DELETE | 删除体重记录 | ✅ |

**示例：记录体重**
```bash
curl -X POST http://localhost:8000/v1/weight/records \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "weight": 72.5,
    "note": "早起空腹",
    "recorded_at": "2026-04-05T08:00:00Z"
  }'
```

---

### 4. AI 模块 (/ai)

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| `/ai/encouragement` | POST | 获取 AI 鼓励 | ✅ |
| `/ai/chat` | POST | AI 对话 | ✅ |

**示例：获取 AI 鼓励**
```bash
curl -X POST http://localhost:8000/v1/ai/encouragement \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "meal_logged",
    "context": {
      "meal_type": "lunch",
      "calories": 520,
      "daily_total": 1200
    }
  }'
```

**示例：AI 对话**
```bash
curl -X POST http://localhost:8000/v1/ai/chat \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "我今天吃多了，好难受",
    "session_id": "session_123"
  }'
```

---

## 🔧 开发工具

### 1. Swagger UI

**安装：**
```bash
# 使用 Docker 运行 Swagger UI
docker run -d \
  -p 8080:8080 \
  -e SWAGGER_JSON=/api/swagger.yaml \
  -v $(pwd)/api:/api \
  swaggerapi/swagger-ui
```

访问：http://localhost:8080

### 2. Postman

导入 `swagger.yaml` 文件自动生成 Postman Collection。

### 3. VS Code 插件

- **Swagger Viewer** - 预览 YAML 文件
- **REST Client** - 测试 API

---

## 📊 响应格式

### 成功响应

```json
{
  "code": 200,
  "message": "success",
  "data": {
    // 具体数据
  }
}
```

### 错误响应

```json
{
  "code": 400,
  "message": "请求参数错误",
  "details": {
    "field": "nickname",
    "error": "长度必须在 2-50 之间"
  }
}
```

---

## 🎯 最佳实践

### 1. 错误处理

- 使用标准 HTTP 状态码
- 提供详细的错误信息
- 包含错误字段定位

### 2. 分页

```bash
GET /v1/food/records?page=1&page_size=20
```

### 3. 筛选

```bash
GET /v1/food/records?meal_type=lunch&date=2026-04-05
```

### 4. 排序

```bash
GET /v1/weight/records?sort=recorded_at&order=desc
```

---

## 📝 更新文档

### 添加新接口

1. 在 `swagger.yaml` 中添加路径定义
2. 在对应的 `routes/*.go` 文件中实现
3. 更新 `README.md` 中的接口列表

### 修改接口

1. 更新 `swagger.yaml` 中的定义
2. 同步更新 Go 代码中的实现
3. 测试确保向后兼容

---

## 🔗 相关链接

- [OpenAPI 规范](https://swagger.io/specification/)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)
- [后端首页](../README.md)
- [技术架构](../../docs/architecture.md)

---

**最后更新：** 2026-04-06
