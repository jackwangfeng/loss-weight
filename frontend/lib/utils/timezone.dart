import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Cached IANA timezone name for the current device (e.g. "Asia/Shanghai").
///
/// Why cache: the platform call is async and goes over a method channel each
/// time. Every API request that touches "today" or a date range needs this
/// value, and it doesn't change unless the user crosses a tz boundary
/// (rare). Resolving once at app start and reusing the cached string keeps
/// API calls synchronous.
///
/// Why not just use `DateTime.now().timeZoneName`: that's a platform abbrev
/// like "CST" or "EDT" — lossy across DST and ambiguous (CST means both
/// China Standard Time and US Central Standard Time). Backend needs the
/// canonical IANA name to look up the right offset table.
String? _cachedTz;

/// Returns the current IANA timezone name. Call [primeAppTimezone] once at
/// startup; thereafter this is synchronous and safe to call from anywhere.
/// Returns null until primed — callers should treat null as "send no tz
/// param" (backend falls back to UTC, which is wrong but won't crash).
String? appTimezone() => _cachedTz;

/// Resolve the device timezone and cache it. Call once during app startup
/// (before the first home-screen API call). Failures are silent — the app
/// degrades to UTC-based daily boundaries on backend, which is the
/// pre-fix behavior.
Future<void> primeAppTimezone() async {
  try {
    _cachedTz = await FlutterTimezone.getLocalTimezone();
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('primeAppTimezone failed: $e');
    }
  }
}
