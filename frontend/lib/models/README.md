# 数据模型 (Models)

> Flutter 数据模型定义

---

## 📁 目录结构

```
models/
├── README.md                 # 本文档
├── user.dart                 # 用户模型
├── food_record.dart          # 饮食记录模型
├── weight_record.dart        # 体重记录模型
├── food_item.dart            # 食物项模型
└── ai_message.dart           # AI 消息模型
```

---

## 📋 模型说明

### 1. 用户模型

**文件：** `models/user.dart`

```dart
class User {
  final int userId;
  final String nickname;
  final String gender;
  final int age;
  final double height;
  final double currentWeight;
  final double targetWeight;
  final double bmi;
  final double bmr;
  final double tdee;
  final int dailyBudget;
  final int streakDays;
  final double totalLoss;
  final String? token;

  User({
    required this.userId,
    required this.nickname,
    required this.gender,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    this.bmi = 0,
    this.bmr = 0,
    this.tdee = 0,
    required this.dailyBudget,
    this.streakDays = 0,
    this.totalLoss = 0,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      nickname: json['nickname'],
      gender: json['gender'],
      age: json['age'],
      height: json['height'].toDouble(),
      currentWeight: json['current_weight'].toDouble(),
      targetWeight: json['target_weight'].toDouble(),
      bmi: json['bmi']?.toDouble() ?? 0,
      bmr: json['bmr']?.toDouble() ?? 0,
      tdee: json['tdee']?.toDouble() ?? 0,
      dailyBudget: json['daily_budget'],
      streakDays: json['streak_days'] ?? 0,
      totalLoss: json['total_loss']?.toDouble() ?? 0,
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'nickname': nickname,
      'gender': gender,
      'age': age,
      'height': height,
      'current_weight': currentWeight,
      'target_weight': targetWeight,
      'bmi': bmi,
      'daily_budget': dailyBudget,
      'streak_days': streakDays,
      'total_loss': totalLoss,
    };
  }
}
```

---

### 2. 饮食记录模型

**文件：** `models/food_record.dart`

```dart
class FoodRecord {
  final int? recordId;
  final String foodName;
  final int calories;
  final double? protein;
  final double? fat;
  final double? carbs;
  final double portion;
  final String unit;
  final String mealType;
  final String recordType;
  final DateTime recordedAt;

  FoodRecord({
    this.recordId,
    required this.foodName,
    required this.calories,
    this.protein,
    this.fat,
    this.carbs,
    required this.portion,
    this.unit = 'g',
    required this.mealType,
    required this.recordType,
    required this.recordedAt,
  });

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    return FoodRecord(
      recordId: json['record_id'],
      foodName: json['food_name'],
      calories: json['calories'],
      protein: json['protein']?.toDouble(),
      fat: json['fat']?.toDouble(),
      carbs: json['carbs']?.toDouble(),
      portion: json['portion'].toDouble(),
      unit: json['unit'] ?? 'g',
      mealType: json['meal_type'],
      recordType: json['record_type'],
      recordedAt: DateTime.parse(json['recorded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'portion': portion,
      'unit': unit,
      'meal_type': mealType,
      'record_type': recordType,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}
```

---

### 3. 食物项模型（AI 识别结果）

**文件：** `models/food_item.dart`

```dart
class FoodItem {
  final String foodName;
  final int calories;
  final double? protein;
  final double? fat;
  final double? carbs;
  final double portion;
  final String unit;
  final double confidence;

  FoodItem({
    required this.foodName,
    required this.calories,
    this.protein,
    this.fat,
    this.carbs,
    this.portion = 1,
    this.unit = '份',
    required this.confidence,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      foodName: json['food_name'],
      calories: json['calories'],
      protein: json['protein']?.toDouble(),
      fat: json['fat']?.toDouble(),
      carbs: json['carbs']?.toDouble(),
      portion: json['portion']?.toDouble() ?? 1,
      unit: json['unit'] ?? '份',
      confidence: json['confidence']?.toDouble() ?? 0,
    );
  }
}
```

---

### 4. 体重记录模型

**文件：** `models/weight_record.dart`

```dart
class WeightRecord {
  final int? recordId;
  final double weight;
  final String? note;
  final DateTime recordedAt;

  WeightRecord({
    this.recordId,
    required this.weight,
    this.note,
    required this.recordedAt,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      recordId: json['record_id'],
      weight: json['weight'].toDouble(),
      note: json['note'],
      recordedAt: DateTime.parse(json['recorded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'note': note,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}
```

---

### 5. AI 消息模型

**文件：** `models/ai_message.dart`

```dart
class AIMessage {
  final String id;
  final String role;  // user/assistant
  final String content;
  final DateTime timestamp;

  AIMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory AIMessage.fromJson(Map<String, dynamic> json) {
    return AIMessage(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['created_at']),
    );
  }
}
```

---

## 🎯 使用示例

```dart
// 创建用户
final user = User(
  userId: 1,
  nickname: '小明',
  gender: 'male',
  age: 28,
  height: 175,
  currentWeight: 75.0,
  targetWeight: 65.0,
  dailyBudget: 1480,
);

// JSON 序列化
final json = user.toJson();

// JSON 反序列化
final userFromJson = User.fromJson(json);

// API 响应解析
final response = await api.get('/users/profile');
final user = User.fromJson(response.data['data']);
```

---

## 🔗 相关链接

- [API 服务](../services/README.md)
- [页面组件](../screens/README.md)
- [前端首页](../../README.md)
- [项目首页](../../../README.md)

---

**最后更新：** 2026-04-06
