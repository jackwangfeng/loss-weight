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
  final double portion;
  final String unit;
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
    this.portion = 0,
    this.unit = '',
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
      portion: (json['portion'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
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
      'portion': portion,
      'unit': unit,
      'meal_type': mealType,
      'eaten_at': eatenAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get portionLabel {
    if (portion <= 0) return '';
    final n = portion == portion.roundToDouble()
        ? portion.toInt().toString()
        : portion.toStringAsFixed(1);
    return unit.isEmpty ? n : '$n$unit';
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
