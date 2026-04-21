# Flutter 应用代码

> Flutter 核心代码目录

---

## 📁 目录结构

```
lib/
├── README.md                 # 本文档
├── main.dart                 # 应用入口
├── screens/                  # 页面组件
│   ├── home_screen.dart      # 首页
│   ├── profile_screen.dart   # 档案页
│   └── ...
├── widgets/                  # 可复用组件
├── services/                 # API 服务
├── models/                   # 数据模型
└── utils/                    # 工具函数
```

---

## 🚀 应用入口

**文件：** `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const LossWeightApp());
}

class LossWeightApp extends StatelessWidget {
  const LossWeightApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        // 其他 Provider...
      ],
      child: MaterialApp(
        title: '减肥 AI 助理',
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
```

---

## 📱 页面组件 (screens/)

### 核心页面列表

| 页面 | 文件 | 说明 |
|------|------|------|
| **首页** | `home_screen.dart` | 今日概览 |
| **档案页** | `profile_screen.dart` | 用户档案建立 |
| **饮食记录** | `food_record_screen.dart` | 拍照/搜索食物 |
| **体重记录** | `weight_screen.dart` | 体重曲线 |
| **AI 对话** | `chat_screen.dart` | AI 聊天 |
| **统计页** | `stats_screen.dart` | 数据统计 |

### 页面示例

```dart
// home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今天也要加油哦 💪'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 热量圆环
            const CalorieRingWidget(),
            // 饮食列表
            const MealListWidget(),
            // AI 建议
            const AISuggestionCard(),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'photo',
            onPressed: () => _navigateToFoodRecord(context),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'weight',
            onPressed: () => _showWeightDialog(context),
            child: const Icon(Icons.monitor_weight),
          ),
        ],
      ),
    );
  }
}
```

---

## 🧩 可复用组件 (widgets/)

### 组件分类

| 组件 | 文件 | 说明 |
|------|------|------|
| **热量圆环** | `calorie_ring.dart` | 展示热量进度 |
| **饮食卡片** | `food_card.dart` | 展示食物信息 |
| **AI 建议卡片** | `ai_suggestion_card.dart` | AI 建议展示 |
| **体重曲线** | `weight_chart.dart` | 体重趋势图 |

### 组件示例

```dart
// calorie_ring.dart
import 'package:flutter/material.dart';

class CalorieRingWidget extends StatelessWidget {
  final int consumed;
  final int budget;
  
  const CalorieRingWidget({
    Key? key,
    required this.consumed,
    required this.budget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = consumed / budget;
    final remaining = budget - consumed;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: percentage,
              strokeWidth: 20,
              backgroundColor: Colors.grey[200],
            ),
          ),
          Column(
            children: [
              Text(
                '$consumed/$budget',
                style: const TextStyle(fontSize: 24),
              ),
              Text('剩余 $remaining kcal'),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

## 🔌 API 服务 (services/)

### 服务分类

| 服务 | 文件 | 说明 |
|------|------|------|
| **API 客户端** | `api_service.dart` | HTTP 请求封装 |
| **用户服务** | `user_service.dart` | 用户相关 API |
| **饮食服务** | `food_service.dart` | 饮食相关 API |
| **体重服务** | `weight_service.dart` | 体重相关 API |

### API 调用示例

```dart
// services/api_service.dart
import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/v1',
    connectTimeout: const Duration(seconds: 10),
  ));

  // 添加 Token
  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // GET 请求
  Future<Response> get(String path) async {
    return await _dio.get(path);
  }

  // POST 请求
  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }
}

// services/food_service.dart
class FoodService {
  final ApiService _apiService;

  FoodService(this._apiService);

  Future<List<FoodItem>> recognizeFood(File image) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path),
    });

    final response = await _apiService.post(
      '/food/recognize',
      data: formData,
    );

    return (response.data['data'] as List)
        .map((item) => FoodItem.fromJson(item))
        .toList();
  }
}
```

---

## 📊 数据模型 (models/)

### 模型示例

```dart
// models/user.dart
class User {
  final int userId;
  final String nickname;
  final double bmi;
  final int dailyBudget;

  User({
    required this.userId,
    required this.nickname,
    required this.bmi,
    required this.dailyBudget,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      nickname: json['nickname'],
      bmi: json['bmi'].toDouble(),
      dailyBudget: json['daily_budget'],
    );
  }
}

// models/food_record.dart
class FoodRecord {
  final int recordId;
  final String foodName;
  final int calories;
  final String mealType;
  final DateTime recordedAt;

  FoodRecord({
    required this.recordId,
    required this.foodName,
    required this.calories,
    required this.mealType,
    required this.recordedAt,
  });

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    return FoodRecord(
      recordId: json['record_id'],
      foodName: json['food_name'],
      calories: json['calories'],
      mealType: json['meal_type'],
      recordedAt: DateTime.parse(json['recorded_at']),
    );
  }
}
```

---

## 🔗 子目录说明

| 目录 | 说明 |
|------|------|
| [screens/](screens/README.md) | 页面组件 |
| [widgets/](widgets/README.md) | 可复用组件 |
| [services/](services/README.md) | API 服务 |
| [models/](models/README.md) | 数据模型 |
| [utils/](utils/README.md) | 工具函数 |

---

## 🔗 相关链接

- [前端首页](../README.md)
- [后端服务](../backend/README.md)
- [项目首页](../../README.md)

---

**最后更新：** 2026-04-06
