# 减肥AI助理 - 技术架构设计

> 本文档描述MVP版本的技术架构、技术选型、数据库设计和API规范。
>
> ⚠️ **部分内容偏向愿景**：文档中提到 Nginx/Kong 网关、PostgreSQL 主库、
> Redis、Chroma 向量库、OSS、通义千问/百度AI 等，**实际实现更简洁**——
> SQLite + Gemini 2.5-flash + 无 Redis/Chroma/OSS。当前端点和数据模型以
> [../backend/README.md](../backend/README.md) 为准。

---

## 1. 整体架构

### 1.1 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         客户端层                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   iOS App    │  │ Android App  │  │   小程序     │          │
│  │  (Flutter)   │  │  (Flutter)   │  │ (可选)       │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         API网关层                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Nginx / Kong                          │  │
│  │  • 负载均衡  • SSL终止  • 限流  • 认证                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       应用服务层                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  用户服务     │  │  饮食服务     │  │  体重服务     │         │
│  │  User API    │  │  Food API    │  │ Weight API   │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  AI服务      │  │  分析服务     │  │  推送服务     │         │
│  │  AI Service  │  │ Analytics    │  │  Push        │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       数据层                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │PostgreSQL│  │  Redis   │  │  Chroma  │  │   OSS    │       │
│  │ 主数据库  │  │  缓存    │  │ 向量库   │  │ 文件存储  │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      第三方服务                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │食物识别  │  │ 大模型   │  │  短信    │  │  推送    │       │
│  │   CV     │  │  LLM     │  │  SMS     │  │  Push    │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 技术选型

### 2.1 客户端

| 技术 | 选型 | 理由 |
|------|------|------|
| **跨端框架** | Flutter 3.x | 一套代码多端运行，性能好 |
| **状态管理** | Provider / Riverpod | 简单、易维护 |
| **网络请求** | Dio | Flutter官方推荐 |
| **本地存储** | Hive / SharedPreferences | 轻量级缓存 |
| **图片处理** | image_picker + image_cropper | 拍照/裁剪 |

### 2.2 后端

| 技术 | 选型 | 理由 |
|------|------|------|
| **开发语言** | Go 1.21+ | 高性能、并发好、部署简单 |
| **Web 框架** | Gin | 高性能、生态成熟、易上手 |
| **ORM** | GORM v2 | Go 官方推荐、功能完善 |
| **认证** | JWT (golang-jwt) | 无状态、跨平台 |
| **任务队列** | Asynq + Redis | 轻量、高性能 |
| **配置管理** | Viper | 支持多环境、热加载 |
| **日志** | Zap | 高性能结构化日志 |
| **验证** | Go-playground/validator | 功能强大、社区活跃 |

### 2.3 数据存储

| 技术 | 选型 | 理由 |
|------|------|------|
| **主数据库** | PostgreSQL 15 | 稳定、功能丰富 |
| **缓存** | Redis 7 | 高性能、支持多种数据结构 |
| **向量数据库** | Chroma | 轻量、易集成、适合AI记忆 |
| **文件存储** | 阿里云OSS / AWS S3 | 图片/文件存储 |

### 2.4 AI服务

| 服务 | 选型 | 理由 |
|------|------|------|
| **食物识别** | 百度AI / 阿里云CV / 自训练 | 快速上线用第三方，长期自训练 |
| **大模型** | 通义千问 / GPT-4 | 鼓励助手、对话AI |
| **Embedding** | text-embedding-3 | 中文效果好 |

### 2.5 基础设施

| 服务 | 选型 | 理由 |
|------|------|------|
| **服务器** | 阿里云 ECS / AWS EC2 | 弹性伸缩 |
| **容器化** | Docker + Docker Compose | 部署方便 |
| **CI/CD** | GitHub Actions / GitLab CI | 自动化部署 |
| **监控** | Prometheus + Grafana | 性能监控 |
| **日志** | ELK Stack | 日志分析 |

---

## 3. 数据库设计

### 3.1 核心表结构

#### 用户表 (users)

```sql
CREATE TABLE users (
    id              BIGSERIAL PRIMARY KEY,
    nickname        VARCHAR(50) NOT NULL,
    gender          VARCHAR(10) NOT NULL CHECK (gender IN ('male', 'female')),
    age             INTEGER NOT NULL CHECK (age BETWEEN 10 AND 100),
    height          DECIMAL(5,2) NOT NULL CHECK (height BETWEEN 100 AND 250),
    current_weight  DECIMAL(5,2) NOT NULL CHECK (current_weight BETWEEN 30 AND 300),
    target_weight   DECIMAL(5,2) NOT NULL CHECK (target_weight BETWEEN 30 AND 300),
    target_date     DATE,
    
    -- AI计算字段
    bmi             DECIMAL(4,2),
    bmr             DECIMAL(6,2),
    tdee            DECIMAL(6,2),
    daily_budget    INTEGER NOT NULL,
    
    -- 统计字段
    streak_days     INTEGER DEFAULT 0,
    total_loss      DECIMAL(5,2) DEFAULT 0,
    
    -- 时间戳
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    CONSTRAINT unique_nickname UNIQUE (nickname)
);

CREATE INDEX idx_users_created_at ON users(created_at);
```

#### 饮食记录表 (food_records)

```sql
CREATE TABLE food_records (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 食物信息
    food_name       VARCHAR(200) NOT NULL,
    calories        INTEGER NOT NULL,
    protein         DECIMAL(6,2),
    fat             DECIMAL(6,2),
    carbs           DECIMAL(6,2),
    
    -- 份量信息
    portion         DECIMAL(8,2) NOT NULL,
    unit            VARCHAR(20) NOT NULL DEFAULT 'g',
    
    -- 餐次分类
    meal_type       VARCHAR(20) NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    
    -- 记录方式
    record_type     VARCHAR(20) NOT NULL CHECK (record_type IN ('photo', 'search', 'manual')),
    
    -- 图片（如果是拍照）
    image_url       VARCHAR(500),
    ai_confidence   DECIMAL(3,2),
    
    -- 记录时间
    recorded_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    INDEX idx_food_records_user_date ON food_records(user_id, recorded_at),
    INDEX idx_food_records_meal_type ON food_records(user_id, meal_type)
);
```

#### 体重记录表 (weight_records)

```sql
CREATE TABLE weight_records (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 体重数据
    weight          DECIMAL(5,2) NOT NULL CHECK (weight BETWEEN 30 AND 300),
    
    -- 备注
    note            VARCHAR(200),
    
    -- 记录时间
    recorded_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    INDEX idx_weight_records_user_date ON weight_records(user_id, recorded_at),
    INDEX idx_weight_records_date ON weight_records(recorded_at)
);
```

#### AI对话表 (ai_conversations)

```sql
CREATE TABLE ai_conversations (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 对话内容
    role            VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    content         TEXT NOT NULL,
    
    -- 上下文
    session_id      VARCHAR(100),
    parent_id       BIGINT REFERENCES ai_conversations(id),
    
    -- 元数据
    trigger_event   VARCHAR(50),
    tokens_used     INTEGER,
    
    -- 时间戳
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    INDEX idx_conversations_user ON ai_conversations(user_id, created_at),
    INDEX idx_conversations_session ON ai_conversations(session_id)
);
```

#### AI记忆表 (ai_memories)

```sql
CREATE TABLE ai_memories (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 记忆内容
    content         TEXT NOT NULL,
    memory_type     VARCHAR(20) NOT NULL CHECK (memory_type IN ('core', 'recent', 'archived')),
    
    -- 向量化
    embedding       VECTOR(1536),
    
    -- 元数据
    importance      DECIMAL(3,2),
    access_count    INTEGER DEFAULT 0,
    last_accessed   TIMESTAMP WITH TIME ZONE,
    
    -- 时间戳
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    INDEX idx_memories_user ON ai_memories(user_id),
    INDEX idx_memories_type ON ai_memories(memory_type)
);
```

#### 食物库表 (food_database)

```sql
CREATE TABLE food_database (
    id              BIGSERIAL PRIMARY KEY,
    
    -- 食物信息
    name            VARCHAR(200) NOT NULL,
    category        VARCHAR(50),
    
    -- 营养数据（每100g）
    calories        INTEGER NOT NULL,
    protein         DECIMAL(6,2),
    fat             DECIMAL(6,2),
    carbs           DECIMAL(6,2),
    fiber           DECIMAL(6,2),
    
    -- 来源
    source          VARCHAR(50) CHECK (source IN ('official', 'user', 'imported')),
    verified        BOOLEAN DEFAULT FALSE,
    
    -- 索引
    INDEX idx_food_name ON food_database(name),
    INDEX idx_food_category ON food_database(category)
);
```

---

## 4. API设计

### 4.1 API规范

**基础URL:** `https://api.yourapp.com/v1`

**认证方式:** Bearer Token (JWT)

**响应格式:**
```json
{
  "code": 200,
  "message": "success",
  "data": {}
}
```

**错误格式:**
```json
{
  "code": 400,
  "message": "参数错误",
  "details": {}
}
```

---

### 4.2 用户相关API

#### 4.2.1 创建用户档案

```http
POST /users/profile
Content-Type: application/json

Request:
{
  "nickname": "小明",
  "gender": "male",
  "age": 28,
  "height": 175,
  "current_weight": 75.0,
  "target_weight": 65.0,
  "target_date": "2026-08-01"
}

Response:
{
  "code": 200,
  "data": {
    "user_id": 1001,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "bmi": 24.5,
    "bmr": 1650,
    "tdee": 1980,
    "daily_budget": 1480,
    "estimated_weeks": 12
  }
}
```

#### 4.2.2 获取用户信息

```http
GET /users/profile
Authorization: Bearer {token}

Response:
{
  "code": 200,
  "data": {
    "user_id": 1001,
    "nickname": "小明",
    "gender": "male",
    "age": 28,
    "height": 175,
    "current_weight": 75.0,
    "target_weight": 65.0,
    "bmi": 24.5,
    "daily_budget": 1480,
    "streak_days": 7,
    "total_loss": 3.2
  }
}
```

---

### 4.3 饮食记录API

#### 4.3.1 拍照识别食物

```http
POST /food/recognize
Content-Type: multipart/form-data
Authorization: Bearer {token}

Request:
- image: [file]

Response:
{
  "code": 200,
  "data": {
    "foods": [
      {
        "food_name": "宫保鸡丁",
        "calories": 520,
        "protein": 25,
        "fat": 30,
        "carbs": 15,
        "portion": 1,
        "unit": "份",
        "confidence": 0.85
      },
      {
        "food_name": "米饭",
        "calories": 200,
        "protein": 4,
        "fat": 1,
        "carbs": 45,
        "portion": 1,
        "unit": "碗",
        "confidence": 0.92
      }
    ],
    "total_calories": 720
  }
}
```

#### 4.3.2 添加饮食记录

```http
POST /food/records
Content-Type: application/json
Authorization: Bearer {token}

Request:
{
  "food_name": "宫保鸡丁",
  "calories": 520,
  "protein": 25,
  "fat": 30,
  "carbs": 15,
  "portion": 200,
  "unit": "g",
  "meal_type": "lunch",
  "record_type": "photo",
  "recorded_at": "2026-04-05T12:30:00Z"
}

Response:
{
  "code": 200,
  "data": {
    "record_id": 5001,
    "daily_total": 1200,
    "daily_remaining": 280
  }
}
```

#### 4.3.3 获取今日饮食

```http
GET /food/records/today
Authorization: Bearer {token}

Response:
{
  "code": 200,
  "data": {
    "date": "2026-04-05",
    "daily_budget": 1480,
    "total_consumed": 1200,
    "remaining": 280,
    "macros": {
      "protein": {"consumed": 35, "target": 90},
      "fat": {"consumed": 28, "target": 60},
      "carbs": {"consumed": 120, "target": 200}
    },
    "meals": {
      "breakfast": [...],
      "lunch": [...],
      "dinner": [],
      "snack": [...]
    }
  }
}
```

---

### 4.4 体重记录API

#### 4.4.1 记录体重

```http
POST /weight/records
Content-Type: application/json
Authorization: Bearer {token}

Request:
{
  "weight": 72.5,
  "note": "早起空腹",
  "recorded_at": "2026-04-05T08:00:00Z"
}

Response:
{
  "code": 200,
  "data": {
    "record_id": 3001,
    "weight": 72.5,
    "change": -0.3,
    "total_loss": 6.0,
    "remaining": 10.0
  }
}
```

#### 4.4.2 获取体重曲线

```http
GET /weight/records?days=30
Authorization: Bearer {token}

Response:
{
  "code": 200,
  "data": {
    "records": [
      {"date": "2026-03-06", "weight": 78.5},
      {"date": "2026-03-07", "weight": 78.2},
      ...
      {"date": "2026-04-05", "weight": 72.5}
    ],
    "trend": "down",
    "avg_daily_change": -0.2
  }
}
```

---

### 4.5 AI服务API

#### 4.5.1 获取AI鼓励

```http
POST /ai/encouragement
Content-Type: application/json
Authorization: Bearer {token}

Request:
{
  "event": "meal_logged",
  "context": {
    "meal_type": "lunch",
    "calories": 520,
    "daily_total": 1200
  }
}

Response:
{
  "code": 200,
  "data": {
    "message": "记录得真及时！👍 今天吃得挺均衡的～",
    "type": "positive"
  }
}
```

#### 4.5.2 AI对话

```http
POST /ai/chat
Content-Type: application/json
Authorization: Bearer {token}

Request:
{
  "message": "我今天吃多了，好难受",
  "session_id": "session_123"
}

Response:
{
  "code": 200,
  "data": {
    "reply": "抱抱～偶尔多吃很正常啦，不要责怪自己。今天吃的是什么呀？说出来会好受点～",
    "session_id": "session_123"
  }
}
```

---

## 5. 核心业务逻辑

### 5.1 热量计算逻辑

```python
# services/calculator.py

def calculate_bmr(gender: str, weight: float, height: float, age: int) -> float:
    """计算基础代谢率"""
    if gender == 'male':
        return 66 + (13.7 * weight) + (5 * height) - (6.8 * age)
    else:
        return 655 + (9.6 * weight) + (1.8 * height) - (4.7 * age)

def calculate_tdee(bmr: float, activity_level: float = 1.2) -> float:
    """计算每日总消耗"""
    return bmr * activity_level

def calculate_daily_budget(tdee: float, deficit: int = 500) -> int:
    """计算每日热量预算"""
    return int(tdee - deficit)

def calculate_bmi(weight: float, height: float) -> float:
    """计算BMI"""
    return weight / ((height / 100) ** 2)
```

### 5.2 AI鼓励触发逻辑

```python
# services/ai_encouragement.py

async def get_encouragement(
    user: User,
    event: str,
    context: dict
) -> str:
    """获取AI鼓励"""
    
    # 构建用户画像
    user_profile = {
        "name": user.nickname,
        "current_weight": user.current_weight,
        "target_weight": user.target_weight,
        "streak_days": user.streak_days,
        "daily_budget": user.daily_budget
    }
    
    # 构建场景信息
    scenario_map = {
        "meal_logged": "用户刚刚记录了一餐",
        "weight_logged": "用户刚刚记录了体重",
        "goal_reached": "用户达成了一个小目标",
        "ate_too_much": "用户今天吃多了",
        "missed_days": "用户连续几天没打卡"
    }
    
    # 调用大模型
    prompt = build_prompt(user_profile, scenario_map[event], context)
    response = await llm_client.generate(prompt)
    
    return response
```

### 5.3 记忆系统逻辑

```python
# services/ai_memory.py

class AIMemory:
    def __init__(self, user_id: int):
        self.user_id = user_id
        self.vector_store = ChromaDB()
    
    async def add_memory(self, content: str, memory_type: str = 'recent'):
        """添加记忆"""
        # 生成embedding
        embedding = await embedding_model.encode(content)
        
        # 存入向量数据库
        await self.vector_store.add(
            user_id=self.user_id,
            content=content,
            embedding=embedding,
            memory_type=memory_type
        )
    
    async def get_relevant_memories(self, query: str, limit: int = 5):
        """检索相关记忆"""
        query_embedding = await embedding_model.encode(query)
        
        memories = await self.vector_store.search(
            user_id=self.user_id,
            query_embedding=query_embedding,
            limit=limit
        )
        
        return memories
```

---

## 6. 部署架构

### 6.1 开发环境

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  api:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/lossweight
      - REDIS_URL=redis://redis:6379
    volumes:
      - ./backend:/app
    depends_on:
      - db
      - redis
  
  db:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=lossweight
    volumes:
      - pgdata:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
  
  chroma:
    image: chromadb/chroma
    ports:
      - "8001:8000"

volumes:
  pgdata:
```

### 6.2 生产环境

```
┌─────────────────────────────────────────────────────┐
│                  负载均衡 (SLB)                      │
└─────────────────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   ┌────────┐  ┌────────┐  ┌────────┐
   │  API-1 │  │  API-2 │  │  API-3 │
   │ FastAPI│  │ FastAPI│  │ FastAPI│
   └────────┘  └────────┘  └────────┘
        │           │           │
        └───────────┼───────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   ┌────────┐  ┌────────┐  ┌────────┐
   │   RDS  │  │ Redis  │  │  OSS   │
   │PostgreSQL│ │ Cluster│  │  存储  │
   └────────┘  └────────┘  └────────┘
```

---

## 7. 安全设计

### 7.1 认证与授权

```python
# 认证中间件
async def verify_token(request: Request, call_next):
    token = request.headers.get('Authorization')
    if not token:
        return JSONResponse(status_code=401, content={"error": "未认证"})
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
        request.state.user_id = user_id
    except JWTError:
        return JSONResponse(status_code=401, content={"error": "Token无效"})
    
    return await call_next(request)
```

### 7.2 数据加密

- 密码：bcrypt 加密
- JWT：HS256 签名
- 敏感数据：AES-256 加密存储
- HTTPS：强制使用

### 7.3 限流策略

```python
# Redis限流
from fastapi_limiter import FastAPILimiter
from fastapi_limiter.depends import RateLimiter

@app.post("/food/recognize", dependencies=[Depends(RateLimiter(times=10, seconds=60))])
async def recognize_food(...):
    pass
```

---

## 8. 监控与日志

### 8.1 关键指标

| 指标 | 阈值 | 告警 |
|------|------|------|
| API响应时间 | < 500ms | > 1s |
| 错误率 | < 1% | > 5% |
| CPU使用率 | < 70% | > 90% |
| 内存使用率 | < 80% | > 95% |
| 数据库连接 | < 80% | > 95% |

### 8.2 日志规范

```python
import logging

logger = logging.getLogger(__name__)

# 业务日志
logger.info(f"user_id={user_id} action=meal_logged calories={calories}")
logger.warning(f"user_id={user_id} action=ai_recognition_failed confidence={confidence}")
logger.error(f"user_id={user_id} action=payment_failed error={error}")
```

---

## 9. 技术债务管理

### 9.1 MVP阶段可妥协

| 项目 | MVP方案 | 远期优化 |
|------|---------|----------|
| 食物识别 | 第三方API | 自训练模型 |
| 大模型 | 通义千问API | 微调开源模型 |
| 部署 | 单机Docker | K8s集群 |
| 监控 | 基础日志 | ELK+Prometheus |

### 9.2 不可妥协

| 项目 | 要求 |
|------|------|
| 数据安全 | 必须加密 |
| 用户隐私 | 必须合规 |
| API规范 | 必须RESTful |
| 代码质量 | 必须单元测试 |

---

## 10. 开发计划

| 阶段 | 周期 | 里程碑 |
|------|------|--------|
| Phase 1 | 2周 | 数据库设计 + 基础框架 |
| Phase 2 | 2周 | 用户服务 + 饮食服务 |
| Phase 3 | 2周 | 体重服务 + AI服务 |
| Phase 4 | 1周 | 联调测试 |
| Phase 5 | 1周 | 部署上线 |

---

## 附录

### A. 项目目录结构

```
loss-weight/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── models/
│   │   ├── services/
│   │   ├── schemas/
│   │   └── main.py
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   ├── lib/
│   │   ├── screens/
│   │   ├── widgets/
│   │   ├── services/
│   │   └── main.dart
│   └── pubspec.yaml
├── docs/
│   ├── prd-mvp.md
│   ├── roadmap.md
│   ├── prototype-mvp.md
│   └── architecture.md
└── docker-compose.yml
```

### B. 依赖清单

**Backend:**
```txt
fastapi==0.109.0
uvicorn==0.27.0
sqlalchemy==2.0.25
pyjwt==2.8.0
redis==5.0.1
chromadb==0.4.22
openai==1.12.0
```

**Frontend:**
```yaml
dependencies:
  flutter: sdk: flutter
  provider: ^6.1.1
  dio: ^5.4.0
  hive: ^2.2.3
  image_picker: ^1.0.7
```
