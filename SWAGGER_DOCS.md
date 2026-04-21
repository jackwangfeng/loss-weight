# Swagger API 文档生成完成

> ⚠️ **历史快照**。最新的路由清单以 `backend/internal/routes/routes.go` 为准，手工测试示例见 [API_TESTS.md](API_TESTS.md)。Swagger YAML（`backend/api/swagger.yaml`）可能未随代码更新。

> ✅ 已生成完整的 OpenAPI 3.0 规范文档

---

## 📊 完成情况

### 1. 生成的文件

| 文件 | 说明 | 状态 |
|------|------|------|
| `backend/api/swagger.yaml` | OpenAPI 3.0 规范文件 | ✅ 完成 |
| `backend/api/README.md` | API 文档使用说明 | ✅ 完成 |

---

## 📋 Swagger 文档内容

### API 模块（4 大模块）

#### 1. 用户模块 (/users)

| 接口 | 方法 | 说明 |
|------|------|------|
| `/v1/users/profile` | POST | 创建用户档案 |
| `/v1/users/profile` | GET | 获取用户信息 |
| `/v1/users/profile` | PUT | 更新用户信息 |

**示例请求：**
```bash
POST /v1/users/profile
Content-Type: application/json

{
  "nickname": "小明",
  "gender": "male",
  "age": 28,
  "height": 175,
  "current_weight": 75.0,
  "target_weight": 65.0,
  "target_date": "2026-08-01"
}
```

---

#### 2. 饮食模块 (/food)

| 接口 | 方法 | 说明 |
|------|------|------|
| `/v1/food/recognize` | POST | 拍照识别食物 |
| `/v1/food/records` | POST | 添加饮食记录 |
| `/v1/food/records` | GET | 获取饮食列表 |
| `/v1/food/records/today` | GET | 今日饮食汇总 |
| `/v1/food/records/{id}` | PUT | 更新饮食记录 |
| `/v1/food/records/{id}` | DELETE | 删除饮食记录 |

**特色功能：**
- 📸 拍照识别（multipart/form-data）
- 📊 实时汇总（macronutrients 追踪）
- 🔍 分页查询（支持餐次/日期筛选）

---

#### 3. 体重模块 (/weight)

| 接口 | 方法 | 说明 |
|------|------|------|
| `/v1/weight/records` | POST | 记录体重 |
| `/v1/weight/records` | GET | 获取体重列表 |
| `/v1/weight/records/{id}` | PUT | 更新体重记录 |
| `/v1/weight/records/{id}` | DELETE | 删除体重记录 |

**特色功能：**
- 📈 趋势分析（较上次变化）
- 📊 累计减重统计
- 🔍 时间范围筛选

---

#### 4. AI 模块 (/ai)

| 接口 | 方法 | 说明 |
|------|------|------|
| `/v1/ai/encouragement` | POST | 获取 AI 鼓励 |
| `/v1/ai/chat` | POST | AI 对话 |

**特色功能：**
- 🤖 场景化鼓励（meal_logged, weight_logged, goal_reached...）
- 💬 连续性对话（session_id 保持上下文）
- 🎯 个性化回复（基于用户数据）

---

## 🎯 核心特性

### 1. 认证机制

**JWT Bearer Token**
- 创建用户时自动返回 token
- 有效期：7 天
- 使用方式：`Authorization: Bearer {token}`

### 2. 统一响应格式

```json
{
  "code": 200,
  "message": "success",
  "data": { ... }
}
```

### 3. 错误处理

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

### 4. 分页支持

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "records": [...],
    "total": 100,
    "page": 1,
    "page_size": 20
  }
}
```

---

## 🚀 使用方式

### 1. 在线查看（推荐）

启动服务后访问：
```
http://localhost:8000/swagger/index.html
```

### 2. 本地预览

```bash
# 使用 Docker 运行 Swagger UI
docker run -d \
  -p 8080:8080 \
  -e SWAGGER_JSON=/api/swagger.yaml \
  -v $(pwd)/backend/api:/api \
  swaggerapi/swagger-ui
```

访问：http://localhost:8080

### 3. Postman 导入

1. 打开 Postman
2. Import → File
3. 选择 `backend/api/swagger.yaml`
4. 自动生成 Collection

### 4. VS Code 预览

安装 **Swagger Viewer** 插件，打开 `swagger.yaml` 文件即可预览。

---

## 📊 API 统计

| 统计项 | 数量 |
|--------|------|
| **总接口数** | 16 个 |
| **用户模块** | 3 个 |
| **饮食模块** | 6 个 |
| **体重模块** | 4 个 |
| **AI 模块** | 2 个 |
| **数据模型** | 20+ 个 |
| **示例代码** | 10+ 个 |

---

## 🎯 接口分类

### 公开接口（无需认证）

| 接口 | 说明 |
|------|------|
| `POST /v1/users/profile` | 创建用户档案 |
| `GET /health` | 健康检查 |

### 认证接口（需要 JWT）

所有其他接口都需要 JWT 认证。

---

## 📝 数据模型

### 核心模型

| 模型 | 说明 |
|------|------|
| **UserProfile** | 用户档案 |
| **FoodRecord** | 饮食记录 |
| **WeightRecord** | 体重记录 |
| **FoodItem** | 食物项（AI 识别结果） |
| **Encouragement** | AI 鼓励 |
| **ChatMessage** | AI 对话消息 |

### 响应模型

| 模型 | 说明 |
|------|------|
| **UserProfileResponse** | 用户档案响应 |
| **FoodRecordResponse** | 饮食记录响应 |
| **WeightRecordResponse** | 体重记录响应 |
| **TodayFoodSummaryResponse** | 今日饮食汇总 |
| **EncouragementResponse** | AI 鼓励响应 |
| **ChatResponse** | AI 对话响应 |

---

## 🔧 开发工具

### 1. Swagger UI
- 在线文档和测试
- 交互式 API 探索

### 2. Postman
- API 测试
- 自动化测试

### 3. VS Code 插件
- Swagger Viewer
- REST Client

### 4. curl
```bash
# 测试 API
curl -X POST http://localhost:8000/v1/users/profile \
  -H "Content-Type: application/json" \
  -d '{...}'
```

---

## 📈 下一步工作

### 高优先级

1. **实现 API 接口**
   - 用户服务
   - 饮食服务
   - 体重服务
   - AI 服务

2. **集成 Swagger UI**
   - 在 Gin 中集成 swagger-ui
   - 自动加载 swagger.yaml

3. **添加更多示例**
   - 请求示例
   - 响应示例
   - 错误示例

### 中优先级

4. **API 版本管理**
   - v1 → v2 迁移策略
   - 向后兼容

5. **速率限制**
   - 每用户请求限制
   - API 配额管理

---

## 🔗 相关链接

- **Swagger 文档：** [backend/api/swagger.yaml](backend/api/swagger.yaml)
- **API 说明：** [backend/api/README.md](backend/api/README.md)
- **后端指南：** [backend/README.md](backend/README.md)
- **技术架构：** [docs/architecture.md](docs/architecture.md)

---

**文档生成时间：** 2026-04-06  
**OpenAPI 版本：** 3.0.3  
**API 版本：** 1.0.0
