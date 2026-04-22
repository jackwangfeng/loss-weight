import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Convenience: resolve the effective locale code to send with AI requests.
/// Looks up LocaleProvider, resolves "follow system" to the concrete platform
/// locale, and falls back to 'en' if nothing matches our supported set.
String effectiveAiLocale(BuildContext ctx) {
  final provider = Provider.of<LocaleProvider>(ctx, listen: false);
  final system = Localizations.localeOf(ctx);
  return provider.effectiveLanguageCode(system);
}

/// Persisted UI language choice + source of truth for the locale passed to
/// AI endpoints. `null` means "follow system default".
///
/// Stored as a short language code ('en' / 'zh') in shared_preferences under
/// the key `app.locale`. Absence of the key → follow system.
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app.locale';

  /// Locales we ship translations for. Keep in sync with lib/l10n/*.arb.
  static const supportedLanguageCodes = ['en', 'zh'];

  Locale? _locale; // null = follow system
  Locale? get locale => _locale;

  /// Call once at app startup to restore the saved choice.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && supportedLanguageCodes.contains(code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  /// Pass null to reset to "follow system".
  Future<void> setLanguageCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_prefsKey);
      _locale = null;
    } else {
      if (!supportedLanguageCodes.contains(code)) return;
      await prefs.setString(_prefsKey, code);
      _locale = Locale(code);
    }
    notifyListeners();
  }

  /// What the server / AI prompt should treat as the user's language.
  /// Resolves "follow system" to an actual supported code using the current
  /// platform locale; falls back to 'en' if nothing matches.
  String effectiveLanguageCode(Locale systemLocale) {
    if (_locale != null) return _locale!.languageCode;
    if (supportedLanguageCodes.contains(systemLocale.languageCode)) {
      return systemLocale.languageCode;
    }
    return 'en';
  }
}
