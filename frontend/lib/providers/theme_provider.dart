import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 两档外观：`dark` 是原来的纯黑（scaffold #000，AMOLED 友好），`medium`
/// 是柔和深色（scaffold #1A1A1C，白天看不累）。都是 Brightness.dark —
/// 文字还是浅色，这里只是调 surface 层级的深浅。
enum AppThemeVariant { dark, medium }

class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app.theme';

  AppThemeVariant _variant = AppThemeVariant.dark;
  AppThemeVariant get variant => _variant;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == 'medium') {
      _variant = AppThemeVariant.medium;
      notifyListeners();
    }
  }

  Future<void> setVariant(AppThemeVariant v) async {
    if (_variant == v) return;
    _variant = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, v.name);
    notifyListeners();
  }
}
