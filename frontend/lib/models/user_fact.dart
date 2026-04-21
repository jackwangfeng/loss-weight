class UserFact {
  final int id;
  final int userId;
  final String category;
  final String fact;
  final double confidence;
  final int? sourceMessageId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserFact({
    required this.id,
    required this.userId,
    required this.category,
    required this.fact,
    this.confidence = 0,
    this.sourceMessageId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserFact.fromJson(Map<String, dynamic> json) {
    return UserFact(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      category: json['category'] ?? '',
      fact: json['fact'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      sourceMessageId: json['source_message_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'preference': return '偏好';
      case 'constraint': return '约束';
      case 'goal':       return '目标';
      case 'routine':    return '习惯';
      case 'history':    return '经历';
      default:           return category;
    }
  }
}
