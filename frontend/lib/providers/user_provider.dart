import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 加载用户信息
  Future<void> loadUser(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _userService.getProfile(userId);
      _error = null;
    } catch (e) {
      // 用户不存在或加载失败，不设置错误，让 currentUser 保持 null
      _error = null;
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建用户档案
  Future<void> createUserProfile({
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _userService.createProfile(
        openid: openid,
        nickname: nickname,
        unionid: unionid,
        avatar: avatar,
        gender: gender,
        birthday: birthday,
        height: height,
        currentWeight: currentWeight,
        targetWeight: targetWeight,
        activityLevel: activityLevel,
        targetCalorie: targetCalorie,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新用户信息
  Future<void> updateUserProfile({
    String? nickname,
    String? avatar,
    String? gender,
    DateTime? birthday,
    double? height,
    double? currentWeight,
    double? targetWeight,
    int? activityLevel,
    double? targetCalorie,
  }) async {
    if (_currentUser == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _userService.updateProfile(
        _currentUser!.id,
        nickname: nickname,
        avatar: avatar,
        gender: gender,
        birthday: birthday,
        height: height,
        currentWeight: currentWeight,
        targetWeight: targetWeight,
        activityLevel: activityLevel,
        targetCalorie: targetCalorie,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清除用户信息
  void clearUser() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}
