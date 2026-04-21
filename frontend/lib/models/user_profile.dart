

class UserProfile {
  final int id;
  final String openid;
  final String? unionid;
  final String nickname;
  final String avatar;
  final String gender;
  final DateTime? birthday;
  final double height;
  final double currentWeight;
  final double targetWeight;
  final int activityLevel;
  final double targetCalorie;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.openid,
    this.unionid,
    required this.nickname,
    this.avatar = '',
    this.gender = 'male',
    this.birthday,
    this.height = 0,
    required this.currentWeight,
    this.targetWeight = 0,
    this.activityLevel = 1,
    this.targetCalorie = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 0,
      openid: json['openid'] ?? '',
      unionid: json['unionid'],
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      gender: json['gender'] ?? 'male',
      birthday: json['birthday'] != null ? DateTime.parse(json['birthday']) : null,
      height: (json['height'] ?? 0).toDouble(),
      currentWeight: (json['current_weight'] ?? 0).toDouble(),
      targetWeight: (json['target_weight'] ?? 0).toDouble(),
      activityLevel: json['activity_level'] ?? 1,
      targetCalorie: (json['target_calorie'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'openid': openid,
      'unionid': unionid,
      'nickname': nickname,
      'avatar': avatar,
      'gender': gender,
      'birthday': birthday?.toIso8601String(),
      'height': height,
      'current_weight': currentWeight,
      'target_weight': targetWeight,
      'activity_level': activityLevel,
      'target_calorie': targetCalorie,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  double get bmi {
    if (height == 0) return 0;
    return currentWeight / ((height / 100) * (height / 100));
  }

  double get weightLoss {
    if (targetWeight == 0) return 0;
    return currentWeight - targetWeight;
  }
}
