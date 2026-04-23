import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/auth_config.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  // Persisted session. JWT TTL on the backend is 7 days (see
  // backend config), so restoring a stored token survives cold starts within
  // that window; 401 from the server naturally kicks us back to login.
  static const _prefsTokenKey = 'auth.token';
  static const _prefsUserIdKey = 'auth.user_id';

  /// Restore a stored session on app startup. Call once in main() before
  /// runApp so HomeScreen sees `isLoggedIn == true` on the first frame when
  /// the user is already logged in.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefsTokenKey);
    final userId = prefs.getInt(_prefsUserIdKey);
    if (token != null && token.isNotEmpty && userId != null) {
      _token = token;
      _userId = userId;
      ApiService().token = token;
      notifyListeners();
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_prefsTokenKey, _token!);
    if (_userId != null) await prefs.setInt(_prefsUserIdKey, _userId!);
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTokenKey);
    await prefs.remove(_prefsUserIdKey);
  }

  // google_sign_in 7.x is event-driven. On web the SDK renders its own button
  // (see widgets/google_sign_in_button_web.dart) and fires events on
  // `authenticationEvents` — so the AuthProvider just subscribes once at
  // init and reacts, instead of calling an imperative `signIn()` that no
  // longer works on web.
  bool _googleInitialized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleSub;

  Future<void> ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    // `clientId` on web = GIS popup's client; on iOS pass null so the plugin
    // reads GIDClientID from Info.plist (iOS OAuth client, different id);
    // Android reads from google-services.json. `serverClientId` stays the web
    // id — that's what the backend verifies as the ID token's `aud`.
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? googleClientId : null,
      serverClientId: googleClientId,
    );
    _googleSub = GoogleSignIn.instance.authenticationEvents
        .listen(_onGoogleAuthEvent, onError: (Object e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
    _googleInitialized = true;
  }

  Future<void> _onGoogleAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      final idToken = event.user.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        _error = 'Google did not return an ID token';
        notifyListeners();
        return;
      }
      _isLoading = true;
      _error = null;
      notifyListeners();
      try {
        final response = await _authService.googleLogin(idToken: idToken);
        _token = response['token'] as String?;
        _userId = response['user_id'] as int?;
        ApiService().token = _token;
        await _persistSession();
      } catch (e) {
        _error = e.toString();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      // Nothing to do — our own logout() drives UI state; this event fires
      // when GIS itself decides to sign the user out (e.g. session expiry).
    }
  }

  /// Interactive Google sign-in for mobile (iOS/Android). On web, the user
  /// clicks the GIS-rendered button instead — this method is a no-op there.
  Future<bool> googleSignInInteractive() async {
    await ensureGoogleInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      // Web: there's no imperative entry point; button widget drives it.
      return false;
    }
    try {
      await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return false;
      }
      rethrow;
    }
  }

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
      await _persistSession();

      // 如果是新用户，可能需要完善资料
      final isNewUser = response['is_new_user'] as bool? ?? false;
      if (isNewUser) {
        // TODO: 导航到完善资料页面
        if (kDebugMode) debugPrint('New user signed in via phone');
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
    }
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // 没登录过 Google 就会抛，忽略
      }
    }
    _token = null;
    _userId = null;
    _currentUser = null;
    ApiService().token = null;
    await _clearPersistedSession();
    notifyListeners();
  }

  /// 清除认证信息
  void clearAuth() {
    _token = null;
    _userId = null;
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _googleSub?.cancel();
    super.dispose();
  }
}
