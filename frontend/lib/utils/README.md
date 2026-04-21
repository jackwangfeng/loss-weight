# 工具函数 (Utils)

> Flutter 通用工具函数

---

## 📁 目录结构

```
utils/
├── README.md                 # 本文档
├── constants.dart            # 常量定义
├── formatters.dart           # 格式化工具
├── validators.dart           # 验证工具
└── extensions.dart           # 扩展方法
```

---

## 📋 工具函数

### 1. 常量定义

**文件：** `utils/constants.dart`

```dart
class AppConstants {
  // API 配置
  static const String API_BASE_URL = 'http://localhost:8000/v1';
  static const Duration API_TIMEOUT = Duration(seconds: 30);

  // 主题配置
  static const String APP_NAME = '减肥 AI 助理';
  static const String APP_VERSION = '1.0.0';

  // 存储键
  static const String KEY_TOKEN = 'auth_token';
  static const String KEY_USER_ID = 'user_id';
  static const String KEY_SETTINGS = 'settings';

  // 餐次类型
  static const String MEAL_BREAKFAST = 'breakfast';
  static const String MEAL_LUNCH = 'lunch';
  static const String MEAL_DINNER = 'dinner';
  static const String MEAL_SNACK = 'snack';

  // 验证规则
  static const int MIN_AGE = 10;
  static const int MAX_AGE = 100;
  static const double MIN_HEIGHT = 100;
  static const double MAX_HEIGHT = 250;
  static const double MIN_WEIGHT = 30;
  static const double MAX_WEIGHT = 300;
}
```

---

### 2. 格式化工具

**文件：** `utils/formatters.dart`

```dart
import 'package:intl/intl.dart';

class Formatters {
  // 格式化体重
  static String formatWeight(double weight) {
    return '${weight.toStringAsFixed(1)} kg';
  }

  // 格式化热量
  static String formatCalories(int calories) {
    return '$calories kcal';
  }

  // 格式化日期
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // 格式化时间
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  // 格式化日期时间
  static String formatDateTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  // 格式化相对时间
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 7) {
      return formatDate(date);
    } else if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 格式化 BMI
  static String formatBMI(double bmi) {
    return bmi.toStringAsFixed(1);
  }
}
```

---

### 3. 验证工具

**文件：** `utils/validators.dart`

```dart
class Validators {
  // 验证昵称
  static String? validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入昵称';
    }
    if (value.length < 2 || value.length > 50) {
      return '昵称长度 2-50 个字符';
    }
    return null;
  }

  // 验证年龄
  static String? validateAge(int? value) {
    if (value == null) {
      return '请输入年龄';
    }
    if (value < 10 || value > 100) {
      return '年龄必须在 10-100 之间';
    }
    return null;
  }

  // 验证身高
  static String? validateHeight(double? value) {
    if (value == null) {
      return '请输入身高';
    }
    if (value < 100 || value > 250) {
      return '身高必须在 100-250cm 之间';
    }
    return null;
  }

  // 验证体重
  static String? validateWeight(double? value) {
    if (value == null) {
      return '请输入体重';
    }
    if (value < 30 || value > 300) {
      return '体重必须在 30-300kg 之间';
    }
    return null;
  }

  // 验证目标体重
  static String? validateTargetWeight(double? value, double currentWeight) {
    if (value == null) {
      return '请输入目标体重';
    }
    if (value >= currentWeight) {
      return '目标体重必须小于当前体重';
    }
    return null;
  }
}
```

---

### 4. 扩展方法

**文件：** `utils/extensions.dart`

```dart
extension StringExtension on String {
  // 首字母大写
  String get capitalize {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  // 判断是否为空或空白
  bool get isNullOrEmpty {
    return isEmpty || trim().isEmpty;
  }
}

extension DateTimeExtension on DateTime {
  // 判断是否是今天
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  // 判断是否是昨天
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  // 格式化日期
  String toFormattedString() {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}

extension NumExtension on num {
  // 格式化为 1 位小数
  String toOneDecimal() {
    return toStringAsFixed(1);
  }

  // 格式化为 2 位小数
  String toTwoDecimal() {
    return toStringAsFixed(2);
  }
}
```

---

## 🎯 使用示例

```dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../utils/extensions.dart';

// 使用常量
Text(AppConstants.APP_NAME)

// 使用格式化
Text(Formatters.formatWeight(75.5))  // "75.5 kg"
Text(Formatters.formatCalories(500))  // "500 kcal"
Text(Formatters.formatDate(DateTime.now()))  // "2026-04-06"

// 使用验证器
TextFormField(
  validator: Validators.validateNickname,
)

// 使用扩展
final date = DateTime.now();
if (date.isToday) {
  print('今天');
}

final name = 'xiaoming';
print(name.capitalize);  // "Xiaoming"
```

---

## 🔗 相关链接

- [数据模型](../models/README.md)
- [API 服务](../services/README.md)
- [前端首页](../../README.md)
- [项目首页](../../../README.md)

---

**最后更新：** 2026-04-06
