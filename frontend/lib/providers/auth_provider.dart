import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  String? _token;
  int? _userId;
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _error;

  String? get token => _token;
  int? get userId => _userId;
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _token != null && _userId != null;

  /// 发送短信验证码
  Future<void> sendSMSCode(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendSMSCode(phone: phone, purpose: 'login');
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 手机号登录
  Future<void> phoneLogin(String phone, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.phoneLogin(
        phone: phone,
        code: code,
      );

      _token = response['token'] as String?;
      _userId = response['user_id'] as int?;
      _error = null;

      // 设置 token 到 ApiService
      final apiService = ApiService();
      apiService.token = _token;

      // 如果是新用户，可能需要完善资料
      final isNewUser = response['is_new_user'] as bool? ?? false;
      if (isNewUser) {
        // TODO: 导航到完善资料页面
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (e) {
      // 忽略退出错误
    } finally {
      _token = null;
      _userId = null;
      _currentUser = null;
      notifyListeners();
    }
  }

  /// 清除认证信息
  void clearAuth() {
    _token = null;
    _userId = null;
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}
