class WeightRecord {
  final int id;
  final int userId;
  final double weight;
  final double bodyFat;
  final double muscle;
  final double water;
  final double bmi;
  final String note;
  final DateTime measuredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  WeightRecord({
    required this.id,
    required this.userId,
    required this.weight,
    this.bodyFat = 0,
    this.muscle = 0,
    this.water = 0,
    this.bmi = 0,
    this.note = '',
    required this.measuredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      weight: (json['weight'] ?? 0).toDouble(),
      bodyFat: (json['body_fat'] ?? 0).toDouble(),
      muscle: (json['muscle'] ?? 0).toDouble(),
      water: (json['water'] ?? 0).toDouble(),
      bmi: (json['bmi'] ?? 0).toDouble(),
      note: json['note'] ?? '',
      measuredAt: DateTime.parse(json['measured_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'weight': weight,
      'body_fat': bodyFat,
      'muscle': muscle,
      'water': water,
      'bmi': bmi,
      'note': note,
      'measured_at': measuredAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class WeightTrend {
  final List<WeightRecord> records;
  final int count;
  final int days;

  WeightTrend({
    required this.records,
    required this.count,
    required this.days,
  });

  factory WeightTrend.fromJson(Map<String, dynamic> json) {
    var recordsList = json['records'] as List? ?? [];
    List<WeightRecord> records = recordsList.map((r) => WeightRecord.fromJson(r)).toList();

    return WeightTrend(
      records: records,
      count: json['count'] ?? 0,
      days: json['days'] ?? 30,
    );
  }

  double get weightChange {
    if (records.length < 2) return 0;
    return records.last.weight - records.first.weight;
  }

  double get averageWeight {
    if (records.isEmpty) return 0;
    double total = records.fold(0, (sum, record) => sum + record.weight);
    return total / records.length;
  }
}
