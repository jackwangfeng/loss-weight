import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  /// 发送短信验证码
  Future<Map<String, dynamic>> sendSMSCode({
    required String phone,
    required String purpose,
  }) async {
    final response = await _apiService.post('/auth/sms/send', {
      'phone': phone,
      'purpose': purpose,
    });
    return response.data;
  }

  /// 手机号登录
  Future<Map<String, dynamic>> phoneLogin({
    required String phone,
    required String code,
  }) async {
    final response = await _apiService.post('/auth/sms/login', {
      'phone': phone,
      'code': code,
    });
    
    // 保存 token
    if (response.data['token'] != null) {
      _apiService.token = response.data['token'] as String;
    }
    
    return response.data;
  }

  /// 获取当前用户信息
  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _apiService.get('/auth/me');
    return response.data;
  }

  /// 退出登录
  Future<void> logout() async {
    await _apiService.post('/auth/logout', {});
    _apiService.token = null;
  }
}
