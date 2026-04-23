import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  final localeProvider = LocaleProvider();
  final themeProvider = ThemeProvider();
  final authProvider = AuthProvider();
  await Future.wait([
    localeProvider.load(),
    themeProvider.load(),
    authProvider.load(),
  ]);
  runApp(RecompDailyApp(
    localeProvider: localeProvider,
    themeProvider: themeProvider,
    authProvider: authProvider,
  ));
}

class RecompDailyApp extends StatelessWidget {
  final LocaleProvider localeProvider;
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;
  const RecompDailyApp({
    Key? key,
    required this.localeProvider,
    required this.themeProvider,
    required this.authProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
        builder: (context, locale, themePref, _) {
          final palette = themePref.variant == AppThemeVariant.medium
              ? _paletteMedium
              : _paletteDark;
          // System chrome picks up whichever scaffold bg we're on so the
          // status bar / nav bar blend in.
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: palette.bg,
            systemNavigationBarIconBrightness: Brightness.light,
          ));
          return MaterialApp(
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            darkTheme: _buildTheme(palette),
            theme: _buildTheme(palette),
            locale: locale.locale, // null = follow system
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

// ============================================================================
//  Theme — two dark variants (pure black vs graphite). Same red accent.
//  Typography: tight letter-spacing, reduced weight contrast, numeric-friendly.
// ============================================================================

class _Palette {
  final Color bg;           // Scaffold
  final Color surface;      // Card / AppBar
  final Color surfaceHi;    // Input bg, raised card
  final Color surfaceHiHi;  // Pressed / hover
  final Color outline;
  final Color outlineSoft;
  final Color onSurface;
  final Color muted;
  final Color accent = const Color(0xFFE53935);
  final Color onAccent = const Color(0xFFFFFFFF);
  const _Palette({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.surfaceHiHi,
    required this.outline,
    required this.outlineSoft,
    required this.onSurface,
    required this.muted,
  });
}

const _paletteDark = _Palette(
  bg:           Color(0xFF000000),
  surface:      Color(0xFF0E0E10),
  surfaceHi:    Color(0xFF1A1A1D),
  surfaceHiHi:  Color(0xFF242428),
  outline:      Color(0xFF2A2A2E),
  outlineSoft:  Color(0xFF1E1E22),
  onSurface:    Color(0xFFE7E7EA),
  muted:        Color(0xFF8A8A90),
);

const _paletteMedium = _Palette(
  bg:           Color(0xFF1A1A1C),
  surface:      Color(0xFF26262A),
  surfaceHi:    Color(0xFF32323A),
  surfaceHiHi:  Color(0xFF40404A),
  outline:      Color(0xFF48484F),
  outlineSoft:  Color(0xFF323238),
  onSurface:    Color(0xFFECECEF),
  muted:        Color(0xFFA2A2A8),
);

ThemeData _buildTheme(_Palette p) {
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.accent,
    onError: p.onAccent,
    surface: p.surface,
    onSurface: p.onSurface,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surfaceHi,
    surfaceContainerHigh: p.surfaceHi,
    surfaceContainerHighest: p.surfaceHiHi,
    onSurfaceVariant: p.muted,
    outline: p.outline,
    outlineVariant: p.outlineSoft,
    inverseSurface: p.onSurface,
    onInverseSurface: p.bg,
    inversePrimary: p.accent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    fontFamily: null, // use platform default sans-serif
  );

  // Tightened, numeric-friendly typography.
  // NOTE: each TextStyle sets `color:` explicitly — if you only
  // call `.apply(bodyColor: ...)` and then `.copyWith(bodyLarge: TextStyle(...))`,
  // the copyWith REPLACES the style whole and the color from apply is lost,
  // which leaks black-on-black into TextField input text.
  final tt = base.textTheme.copyWith(
    displayLarge:  TextStyle(color: p.onSurface, fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 1.1),
    displayMedium: TextStyle(color: p.onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15),
    headlineLarge: TextStyle(color: p.onSurface, fontWeight: FontWeight.w600, letterSpacing: -0.3),
    headlineMedium:TextStyle(color: p.onSurface, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleLarge:    TextStyle(color: p.onSurface, fontWeight: FontWeight.w600, letterSpacing: -0.1),
    titleMedium:   TextStyle(color: p.onSurface, fontWeight: FontWeight.w600),
    titleSmall:    TextStyle(color: p.onSurface, fontWeight: FontWeight.w600),
    bodyLarge:     TextStyle(color: p.onSurface, fontSize: 15, height: 1.45),
    bodyMedium:    TextStyle(color: p.onSurface, fontSize: 14, height: 1.45),
    bodySmall:     TextStyle(color: p.muted, fontSize: 12, height: 1.4),
    labelLarge:    TextStyle(color: p.onSurface, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    labelMedium:   TextStyle(color: p.onSurface, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    labelSmall:    TextStyle(color: p.muted, fontSize: 11, letterSpacing: 0.4),
  );

  return base.copyWith(
    textTheme: tt,
    primaryTextTheme: tt,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.25),
      selectionHandleColor: p.accent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: p.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.outlineSoft, width: 1),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.outlineSoft, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      textColor: p.onSurface,
    ),
    iconTheme: IconThemeData(color: p.onSurface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accent.withValues(alpha: 0.12),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: p.muted)),
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
      height: 64,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.onSurface,
      unselectedLabelColor: p.muted,
      indicatorColor: p.accent,
      dividerColor: p.outlineSoft,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHi,
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.accent, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.surfaceHi,
        disabledForegroundColor: p.muted,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.onSurface,
        side: BorderSide(color: p.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceHiHi,
      contentTextStyle: TextStyle(color: p.onSurface),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
          color: p.onSurface, fontSize: 17, fontWeight: FontWeight.w600),
      contentTextStyle: TextStyle(color: p.onSurface, fontSize: 14, height: 1.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.outlineSoft,
      circularTrackColor: p.outlineSoft,
    ),
  );
}
