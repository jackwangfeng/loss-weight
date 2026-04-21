# 可复用组件 (Widgets)

> Flutter 可复用 UI 组件

---

## 📁 目录结构

```
widgets/
├── README.md                 # 本文档
├── calorie_ring.dart         # 热量圆环组件
├── food_card.dart            # 食物卡片组件
├── ai_suggestion_card.dart   # AI 建议卡片
├── weight_chart.dart         # 体重曲线图
├── meal_section.dart         # 餐次分组组件
└── common/                   # 通用组件
    ├── loading.dart          # 加载组件
    └── error_view.dart       # 错误展示组件
```

---

## 🧩 组件分类

### 业务组件

| 组件 | 文件 | 说明 |
|------|------|------|
| **热量圆环** | `calorie_ring.dart` | 展示今日热量进度 |
| **食物卡片** | `food_card.dart` | 展示单条饮食记录 |
| **AI 建议卡片** | `ai_suggestion_card.dart` | 展示 AI 建议 |
| **体重曲线** | `weight_chart.dart` | 体重趋势图 |
| **餐次分组** | `meal_section.dart` | 按餐次分组展示 |

---

### 通用组件

| 组件 | 文件 | 说明 |
|------|------|------|
| **加载组件** | `loading.dart` | Loading 动画 |
| **错误展示** | `error_view.dart` | 错误状态 UI |
| **空状态** | `empty_view.dart` | 空数据状态 |
| **按钮** | `buttons.dart` | 自定义按钮 |

---

## 📝 组件示例

### 1. 热量圆环组件

**文件：** `widgets/calorie_ring.dart`

```dart
import 'package:flutter/material.dart';

class CalorieRingWidget extends StatelessWidget {
  final int consumed;
  final int budget;
  final int protein;
  final int proteinTarget;

  const CalorieRingWidget({
    Key? key,
    required this.consumed,
    required this.budget,
    this.protein = 0,
    this.proteinTarget = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = consumed / budget;
    final remaining = budget - consumed;
    
    Color ringColor;
    if (percentage < 0.8) {
      ringColor = Colors.green;
    } else if (percentage < 1.0) {
      ringColor = Colors.orange;
    } else {
      ringColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              strokeWidth: 20,
              backgroundColor: Colors.grey[200],
              color: ringColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$consumed/$budget',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '剩余 $remaining kcal',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (proteinTarget > 0) ...[
                const SizedBox(height: 16),
                Text('蛋白质 $protein/$proteinTarget g'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
```

---

### 2. 食物卡片组件

**文件：** `widgets/food_card.dart`

```dart
import 'package:flutter/material.dart';

class FoodCardWidget extends StatelessWidget {
  final String foodName;
  final int calories;
  final String mealType;
  final DateTime recordedAt;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FoodCardWidget({
    Key? key,
    required this.foodName,
    required this.calories,
    required this.mealType,
    required this.recordedAt,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _getMealIcon(mealType),
        title: Text(foodName),
        subtitle: Text(_formatTime(recordedAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$calories kcal',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit?.call();
                } else if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getMealIcon(String mealType) {
    IconData icon;
    String label;
    
    switch (mealType) {
      case 'breakfast':
        icon = Icons.free_breakfast;
        label = '早餐';
        break;
      case 'lunch':
        icon = Icons.wb_sunny;
        label = '午餐';
        break;
      case 'dinner':
        icon = Icons.nightlight;
        label = '晚餐';
        break;
      case 'snack':
        icon = Icons.cookie;
        label = '加餐';
        break;
      default:
        icon = Icons.restaurant;
        label = '正餐';
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
```

---

### 3. AI 建议卡片

**文件：** `widgets/ai_suggestion_card.dart`

```dart
import 'package:flutter/material.dart';

class AISuggestionCard extends StatelessWidget {
  final String message;
  final String type;  // positive/comfort/congratulation
  final VoidCallback? onViewDetails;

  const AISuggestionCard({
    Key? key,
    required this.message,
    this.type = 'positive',
    this.onViewDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: _getBackgroundColor(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIcon(), size: 24),
                const SizedBox(width: 8),
                const Text(
                  '💬 AI 小建议',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            if (onViewDetails != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onViewDetails,
                child: const Text('查看详情 >'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case 'positive':
        return Colors.green[50]!;
      case 'comfort':
        return Colors.blue[50]!;
      case 'congratulation':
        return Colors.orange[50]!;
      default:
        return Colors.grey[50]!;
    }
  }

  IconData _getIcon() {
    switch (type) {
      case 'positive':
        return Icons.thumb_up;
      case 'comfort':
        return Icons.favorite;
      case 'congratulation':
        return Icons.celebration;
      default:
        return Icons.lightbulb;
    }
  }
}
```

---

## 🎨 组件设计原则

### 1. 单一职责

每个组件只做一件事

```dart
// ✅ 好的设计
class CalorieRingWidget extends StatelessWidget {
  // 只负责展示热量圆环
}

class ProteinProgressWidget extends StatelessWidget {
  // 只负责展示蛋白质进度
}

// ❌ 不好的设计
class HomeSummaryWidget extends StatelessWidget {
  // 做了太多事情
  // - 热量圆环
  // - 蛋白质进度
  // - 脂肪进度
  // - 碳水进度
}
```

### 2. 可复用性

使用参数让组件更灵活

```dart
// ✅ 好的设计
class FoodCardWidget extends StatelessWidget {
  final String foodName;
  final int calories;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  // 可以通过参数定制
}

// ❌ 不好的设计
class FixedFoodCard extends StatelessWidget {
  // 写死了数据，无法复用
}
```

### 3. 性能优化

使用 const 构造函数

```dart
// ✅ 好的设计
class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return const Text('Hello');  // const
  }
}
```

---

## 🔗 相关链接

- [页面组件](../screens/README.md)
- [API 服务](../services/README.md)
- [前端首页](../../README.md)
- [项目首页](../../../README.md)

---

**最后更新：** 2026-04-06
