class ExerciseRecord {
  final int id;
  final int userId;
  final String type;
  final int durationMin;
  final String intensity;
  final double caloriesBurned;
  final double distance;
  final String notes;
  final DateTime exercisedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExerciseRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.durationMin,
    this.intensity = '',
    this.caloriesBurned = 0,
    this.distance = 0,
    this.notes = '',
    required this.exercisedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExerciseRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? '',
      durationMin: json['duration_min'] ?? 0,
      intensity: json['intensity'] ?? '',
      caloriesBurned: (json['calories_burned'] ?? 0).toDouble(),
      distance: (json['distance'] ?? 0).toDouble(),
      notes: json['notes'] ?? '',
      exercisedAt: DateTime.parse(json['exercised_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

}
