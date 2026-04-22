import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/user_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  final localeProvider = LocaleProvider();
  await localeProvider.load();
  runApp(RecompDailyApp(localeProvider: localeProvider));
}

class RecompDailyApp extends StatelessWidget {
  final LocaleProvider localeProvider;
  const RecompDailyApp({Key? key, required this.localeProvider}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, locale, _) => MaterialApp(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: _buildTheme(),
          theme: _buildTheme(),
          locale: locale.locale, // null = follow system
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

// ============================================================================
//  Theme — dark, compact, data-dense. Black surfaces + single red accent.
//  Typography: tight letter-spacing, reduced weight contrast, numeric-friendly.
// ============================================================================

const _bg           = Color(0xFF000000);  // Scaffold
const _surface      = Color(0xFF0E0E10);  // Card / AppBar
const _surfaceHi    = Color(0xFF1A1A1D);  // Input bg, raised card
const _surfaceHiHi  = Color(0xFF242428);  // Pressed / hover
const _outline      = Color(0xFF2A2A2E);
const _outlineSoft  = Color(0xFF1E1E22);
const _onSurface    = Color(0xFFE7E7EA);
const _muted        = Color(0xFF8A8A90);
const _accent       = Color(0xFFE53935);  // signal red
const _onAccent     = Color(0xFFFFFFFF);

ThemeData _buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _accent,
    onPrimary: _onAccent,
    secondary: _accent,
    onSecondary: _onAccent,
    error: _accent,
    onError: _onAccent,
    surface: _surface,
    onSurface: _onSurface,
    surfaceContainerLowest: _bg,
    surfaceContainerLow: _surface,
    surfaceContainer: _surfaceHi,
    surfaceContainerHigh: _surfaceHi,
    surfaceContainerHighest: _surfaceHiHi,
    onSurfaceVariant: _muted,
    outline: _outline,
    outlineVariant: _outlineSoft,
    inverseSurface: _onSurface,
    onInverseSurface: _bg,
    inversePrimary: _accent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: _bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    fontFamily: null, // use platform default sans-serif
  );

  // Tightened, numeric-friendly typography.
  // NOTE: each TextStyle sets `color: _onSurface` explicitly — if you only
  // call `.apply(bodyColor: ...)` and then `.copyWith(bodyLarge: TextStyle(...))`,
  // the copyWith REPLACES the style whole and the color from apply is lost,
  // which leaks black-on-black into TextField input text on dark theme.
  final tt = base.textTheme.copyWith(
    displayLarge:  const TextStyle(color: _onSurface, fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 1.1),
    displayMedium: const TextStyle(color: _onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15),
    headlineLarge: const TextStyle(color: _onSurface, fontWeight: FontWeight.w600, letterSpacing: -0.3),
    headlineMedium:const TextStyle(color: _onSurface, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleLarge:    const TextStyle(color: _onSurface, fontWeight: FontWeight.w600, letterSpacing: -0.1),
    titleMedium:   const TextStyle(color: _onSurface, fontWeight: FontWeight.w600),
    titleSmall:    const TextStyle(color: _onSurface, fontWeight: FontWeight.w600),
    bodyLarge:     const TextStyle(color: _onSurface, fontSize: 15, height: 1.45),
    bodyMedium:    const TextStyle(color: _onSurface, fontSize: 14, height: 1.45),
    bodySmall:     const TextStyle(color: _muted, fontSize: 12, height: 1.4),
    labelLarge:    const TextStyle(color: _onSurface, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    labelMedium:   const TextStyle(color: _onSurface, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    labelSmall:    const TextStyle(color: _muted, fontSize: 11, letterSpacing: 0.4),
  );

  return base.copyWith(
    textTheme: tt,
    primaryTextTheme: tt,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: _accent,
      selectionColor: Color(0x40E53935),
      selectionHandleColor: _accent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: _onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: _onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _outlineSoft, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(color: _outlineSoft, space: 1, thickness: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: _muted,
      textColor: _onSurface,
    ),
    iconTheme: const IconThemeData(color: _onSurface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: _accent.withValues(alpha: 0.12),
      iconTheme: WidgetStatePropertyAll(const IconThemeData(color: _muted)),
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
      height: 64,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: _onSurface,
      unselectedLabelColor: _muted,
      indicatorColor: _accent,
      dividerColor: _outlineSoft,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceHi,
      hintStyle: const TextStyle(color: _muted),
      labelStyle: const TextStyle(color: _muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: _onAccent,
        disabledBackgroundColor: _surfaceHi,
        disabledForegroundColor: _muted,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: _onAccent,
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _onSurface,
        side: const BorderSide(color: _outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: _surfaceHiHi,
      contentTextStyle: TextStyle(color: _onSurface),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
          color: _onSurface, fontSize: 17, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(color: _onSurface, fontSize: 14, height: 1.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: _surface,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _accent,
      linearTrackColor: _outlineSoft,
      circularTrackColor: _outlineSoft,
    ),
  );
}
