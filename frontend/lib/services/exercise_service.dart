import '../models/exercise_record.dart';
import 'api_service.dart';

class ExerciseService {
  final ApiService _apiService = ApiService();

  /// 新增运动记录
  Future<ExerciseRecord> createRecord({
    required int userId,
    required String type,
    required int durationMin,
    String intensity = '',
    double caloriesBurned = 0,
    double distance = 0,
    String notes = '',
    DateTime? exercisedAt,
  }) async {
    final data = {
      'user_id': userId,
      'type': type,
      'duration_min': durationMin,
      'intensity': intensity,
      'calories_burned': caloriesBurned,
      'distance': distance,
      'notes': notes,
      if (exercisedAt != null) 'exercised_at': exercisedAt.toIso8601String(),
    };
    final r = await _apiService.post('/exercise/record', data);
    return ExerciseRecord.fromJson(r.data);
  }

  /// 列表
  Future<List<ExerciseRecord>> getRecords({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final qp = <String, dynamic>{'user_id': userId};
    if (startDate != null) qp['start_date'] = _fmt(startDate);
    if (endDate != null) qp['end_date'] = _fmt(endDate);
    final r = await _apiService.get('/exercise/records', queryParameters: qp);
    final list = r.data['records'] as List? ?? [];
    return list.map((e) => ExerciseRecord.fromJson(e)).toList();
  }

  /// 每日汇总
  Future<Map<String, dynamic>> getDailySummary({
    required int userId,
    DateTime? date,
  }) async {
    final qp = <String, dynamic>{'user_id': userId};
    if (date != null) qp['date'] = _fmt(date);
    final r = await _apiService.get('/exercise/daily-summary', queryParameters: qp);
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteRecord(int id) async {
    await _apiService.delete('/exercise/record/$id');
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
