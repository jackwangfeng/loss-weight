import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_service.dart';

class FeedbackService {
  final ApiService _api = ApiService();

  /// Pick up version from pubspec manually for now. Swapping in
  /// package_info_plus would fetch it at runtime but that plugin has bitten
  /// us on iOS 26 release builds (see project_ios26_flutter_gotchas memory)
  /// — not worth the regression risk for a single string.
  static const String _appVersion = '1.0.0';

  String _platformTag() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'other';
  }

  /// Submit one piece of user feedback. `userId` is optional — anonymous
  /// feedback is allowed so a logged-out user can still tell us "can't
  /// sign in".
  Future<void> submit({
    int? userId,
    required String content,
    String contact = '',
    String deviceInfo = '',
  }) async {
    final resp = await _api.post('/feedback', {
      if (userId != null) 'user_id': userId,
      'content': content,
      if (contact.isNotEmpty) 'contact': contact,
      'platform': _platformTag(),
      'app_version': _appVersion,
      if (deviceInfo.isNotEmpty) 'device_info': deviceInfo,
    });
    if (resp.statusCode == null ||
        resp.statusCode! < 200 ||
        resp.statusCode! >= 300) {
      throw Exception('提交失败 (${resp.statusCode})');
    }
  }
}
