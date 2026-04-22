import '../models/user_profile.dart';
import 'api_service.dart';

class UserService {
  final ApiService _apiService = ApiService();

  /// 创建用户档案
  Future<UserProfile> createProfile({
    required String openid,
    required String nickname,
    String? unionid,
    String avatar = '',
    String gender = 'male',
    DateTime? birthday,
    double height = 0,
    required double currentWeight,
    double targetWeight = 0,
    int activityLevel = 1,
    double targetCalorie = 0,
  }) async {
    final data = {
      'openid': openid,
      'nickname': nickname,
      if (unionid != null) 'unionid': unionid,
      'avatar': avatar,
      'gender': gender,
      if (birthday != null) 'birthday': DateTime.utc(birthday.year, birthday.month, birthday.day).toIso8601String(),
      'height': height,
      'current_weight': currentWeight,
      'target_weight': targetWeight,
      'activity_level': activityLevel,
      'target_calorie': targetCalorie,
    };

    final response = await _apiService.post('/users/profile', data);
    return UserProfile.fromJson(response.data);
  }

  /// 获取用户档案
  Future<UserProfile> getProfile(int userId) async {
    final response = await _apiService.get('/users/profile/$userId');
    return UserProfile.fromJson(response.data);
  }

  /// 按 OpenID 获取用户档案
  Future<UserProfile> getProfileByOpenId(String openid) async {
    final response = await _apiService.get('/users/profile/openid/$openid');
    return UserProfile.fromJson(response.data);
  }

  /// 更新用户档案
  Future<UserProfile> updateProfile(int userId, {
    String? nickname,
    String? avatar,
    String? gender,
    DateTime? birthday,
    double? height,
    double? currentWeight,
    double? targetWeight,
    int? activityLevel,
    double? targetCalorie,
    double? targetProteinG,
    double? targetCarbsG,
    double? targetFatG,
  }) async {
    final data = <String, dynamic>{};

    if (nickname != null) data['nickname'] = nickname;
    if (avatar != null) data['avatar'] = avatar;
    if (gender != null) data['gender'] = gender;
    if (birthday != null) data['birthday'] = DateTime.utc(birthday.year, birthday.month, birthday.day).toIso8601String();
    if (height != null) data['height'] = height;
    if (currentWeight != null) data['current_weight'] = currentWeight;
    if (targetWeight != null) data['target_weight'] = targetWeight;
    if (activityLevel != null) data['activity_level'] = activityLevel;
    if (targetCalorie != null) data['target_calorie'] = targetCalorie;
    if (targetProteinG != null) data['target_protein_g'] = targetProteinG;
    if (targetCarbsG != null) data['target_carbs_g'] = targetCarbsG;
    if (targetFatG != null) data['target_fat_g'] = targetFatG;

    final response = await _apiService.put('/users/profile/$userId', data);
    return UserProfile.fromJson(response.data);
  }

  /// 删除用户档案
  Future<void> deleteProfile(int userId) async {
    await _apiService.delete('/users/profile/$userId');
  }
}
