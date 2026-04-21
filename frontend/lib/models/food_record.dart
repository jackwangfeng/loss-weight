class FoodRecord {
  final int id;
  final int userId;
  final String photoUrl;
  final String foodName;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final String mealType;
  final DateTime eatenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodRecord({
    required this.id,
    required this.userId,
    this.photoUrl = '',
    required this.foodName,
    required this.calories,
    this.protein = 0,
    this.carbohydrates = 0,
    this.fat = 0,
    this.fiber = 0,
    required this.mealType,
    required this.eatenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    return FoodRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      photoUrl: json['photo_url'] ?? '',
      foodName: json['food_name'] ?? '',
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbohydrates: (json['carbohydrates'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      mealType: json['meal_type'] ?? 'breakfast',
      eatenAt: DateTime.parse(json['eaten_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'photo_url': photoUrl,
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
      'meal_type': mealType,
      'eaten_at': eatenAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get mealTypeLabel {
    switch (mealType) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '加餐';
      default:
        return '其他';
    }
  }
}

class DailyFoodSummary {
  final DateTime date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final int mealCount;
  final List<FoodRecord> records;

  DailyFoodSummary({
    required this.date,
    this.totalCalories = 0,
    this.totalProtein = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
    this.mealCount = 0,
    this.records = const [],
  });

  factory DailyFoodSummary.fromJson(Map<String, dynamic> json) {
    var recordsList = json['records'] as List? ?? [];
    List<FoodRecord> records = recordsList.map((r) => FoodRecord.fromJson(r)).toList();

    return DailyFoodSummary(
      date: DateTime.parse(json['date']),
      totalCalories: (json['total_calories'] ?? 0).toDouble(),
      totalProtein: (json['total_protein'] ?? 0).toDouble(),
      totalCarbs: (json['total_carbs'] ?? 0).toDouble(),
      totalFat: (json['total_fat'] ?? 0).toDouble(),
      mealCount: json['meal_count'] ?? 0,
      records: records,
    );
  }
}
