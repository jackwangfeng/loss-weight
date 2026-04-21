import '../models/food_record.dart';
import 'api_service.dart';

class FoodService {
  final ApiService _apiService = ApiService();

  /// 创建食物记录
  Future<FoodRecord> createRecord({
    required int userId,
    String photoUrl = '',
    required String foodName,
    required double calories,
    double protein = 0,
    double carbohydrates = 0,
    double fat = 0,
    double fiber = 0,
    double portion = 0,
    String unit = '',
    required String mealType,
    DateTime? eatenAt,
  }) async {
    final data = {
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
      if (eatenAt != null) 'eaten_at': eatenAt.toIso8601String(),
    };

    final response = await _apiService.post('/food/record', data);
    return FoodRecord.fromJson(response.data);
  }

  /// 获取食物记录列表
  Future<List<FoodRecord>> getRecords({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParameters = <String, dynamic>{
      'user_id': userId,
    };

    if (startDate != null) {
      queryParameters['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      queryParameters['end_date'] = _formatDate(endDate);
    }

    final response = await _apiService.get(
      '/food/records',
      queryParameters: queryParameters,
    );

    final dataList = response.data['records'] as List;
    return dataList.map((item) => FoodRecord.fromJson(item)).toList();
  }

  /// 获取每日营养汇总
  Future<DailyFoodSummary> getDailySummary({
    required int userId,
    DateTime? date,
  }) async {
    final queryParameters = <String, dynamic>{
      'user_id': userId,
    };

    if (date != null) {
      queryParameters['date'] = _formatDate(date);
    }

    final response = await _apiService.get(
      '/food/daily-summary',
      queryParameters: queryParameters,
    );

    return DailyFoodSummary.fromJson(response.data);
  }

  /// 获取单个食物记录
  Future<FoodRecord> getRecord(int recordId) async {
    final response = await _apiService.get('/food/record/$recordId');
    return FoodRecord.fromJson(response.data);
  }

  /// 更新食物记录
  Future<FoodRecord> updateRecord(int recordId, {
    String? foodName,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
    double? fiber,
    String? mealType,
    DateTime? eatenAt,
  }) async {
    final data = <String, dynamic>{};

    if (foodName != null) data['food_name'] = foodName;
    if (calories != null) data['calories'] = calories;
    if (protein != null) data['protein'] = protein;
    if (carbohydrates != null) data['carbohydrates'] = carbohydrates;
    if (fat != null) data['fat'] = fat;
    if (fiber != null) data['fiber'] = fiber;
    if (mealType != null) data['meal_type'] = mealType;
    if (eatenAt != null) data['eaten_at'] = eatenAt.toIso8601String();

    final response = await _apiService.put('/food/record/$recordId', data);
    return FoodRecord.fromJson(response.data);
  }

  /// 删除食物记录
  Future<void> deleteRecord(int recordId) async {
    await _apiService.delete('/food/record/$recordId');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
