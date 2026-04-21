import '../models/weight_record.dart';
import 'api_service.dart';

class WeightService {
  final ApiService _apiService = ApiService();

  /// 创建体重记录
  Future<WeightRecord> createRecord({
    required int userId,
    required double weight,
    double bodyFat = 0,
    double muscle = 0,
    double water = 0,
    double bmi = 0,
    String note = '',
    DateTime? measuredAt,
  }) async {
    final response = await _apiService.post('/weight/record', {
      'user_id': userId,
      'weight': weight,
      'body_fat': bodyFat,
      'muscle': muscle,
      'water': water,
      'bmi': bmi,
      'note': note,
      'measured_at': (measuredAt ?? DateTime.now()).toUtc().toIso8601String(),
    });

    if (response.statusCode == 201) {
      return WeightRecord.fromJson(response.data);
    } else {
      throw Exception('创建体重记录失败');
    }
  }

  /// 获取体重记录列表
  Future<List<WeightRecord>> getRecords({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, String>{
      'user_id': userId.toString(),
    };

    if (startDate != null) {
      params['start_date'] = startDate.toIso8601String().split('T').first;
    }
    if (endDate != null) {
      params['end_date'] = endDate.toIso8601String().split('T').first;
    }

    final response = await _apiService.get('/weight/records', queryParameters: params);

    if (response.statusCode == 200) {
      final data = response.data;
      List recordsList = data['records'] ?? [];
      return recordsList.map((r) => WeightRecord.fromJson(r)).toList();
    } else {
      throw Exception('获取体重记录失败');
    }
  }

  /// 获取体重趋势
  Future<WeightTrend> getTrend({
    required int userId,
    int days = 30,
  }) async {
    final response = await _apiService.get(
      '/weight/trend',
      queryParameters: {
        'user_id': userId.toString(),
        'days': days.toString(),
      },
    );

    if (response.statusCode == 200) {
      return WeightTrend.fromJson(response.data);
    } else {
      throw Exception('获取体重趋势失败');
    }
  }

  /// 更新体重记录
  Future<WeightRecord> updateRecord({
    required int id,
    double? weight,
    double? bodyFat,
    double? muscle,
    double? water,
    double? bmi,
    String? note,
    DateTime? measuredAt,
  }) async {
    final body = <String, dynamic>{};

    if (weight != null) body['weight'] = weight;
    if (bodyFat != null) body['body_fat'] = bodyFat;
    if (muscle != null) body['muscle'] = muscle;
    if (water != null) body['water'] = water;
    if (bmi != null) body['bmi'] = bmi;
    if (note != null) body['note'] = note;
    if (measuredAt != null) body['measured_at'] = measuredAt.toUtc().toIso8601String();

    final response = await _apiService.put('/weight/record/$id', body);

    if (response.statusCode == 200) {
      return WeightRecord.fromJson(response.data);
    } else {
      throw Exception('更新体重记录失败');
    }
  }

  /// 删除体重记录
  Future<void> deleteRecord(int id) async {
    final response = await _apiService.delete('/weight/record/$id');

    if (response.statusCode != 200) {
      throw Exception('删除体重记录失败');
    }
  }
}
