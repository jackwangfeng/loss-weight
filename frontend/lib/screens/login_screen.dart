import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthProvider? _authProvider;
  VoidCallback? _authListener;

  // Hidden SMS-login easter egg (Android only). Tap the gym-bell icon 7 times
  // within ~3s to surface a phone+code login sheet. Backend prod has
  // SKIP_SMS_VERIFY=true so code 123456 works for any phone — usable by
  // mainland China friends who can't reach Google. Reset the counter on
  // timeout so accidental double-taps don't accumulate forever.
  int _eggTaps = 0;
  DateTime? _eggFirstTapAt;
  static const _eggThreshold = 7;
  static const _eggWindow = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    // Kick Google init on the next frame so GIS is wired up by the time the
    // rendered button attempts to draw. Also hook a listener so we auto-pop
    // this screen when the Google stream drives us into a signed-in state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _authProvider = auth;
      auth.ensureGoogleInitialized();

      _authListener = () async {
        if (!mounted) return;
        if (auth.isLoggedIn) {
          if (auth.userId != null) {
            final userProvider =
                Provider.of<UserProvider>(context, listen: false);
            await userProvider.loadUser(auth.userId!);
          }
          if (!mounted) return;
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).toastSignedIn)),
          );
        } else if (auth.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)
                  .errorGoogleSignInFailed(auth.error!)),
            ),
          );
        }
      };
      auth.addListener(_authListener!);
    });
  }

  @override
  void dispose() {
    if (_authListener != null && _authProvider != null) {
      _authProvider!.removeListener(_authListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.actionSignIn),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onLogoTap,
                child: Icon(
                  Icons.fitness_center,
                  size: 72,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appTagline,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),

              // Only Google on海外版. Backend still supports SMS for tests,
              // but the UI is single-path to keep the first screen clean.
              Center(
                child: kIsWeb
                    ? buildGoogleSignInButton()
                    : OutlinedButton.icon(
                        onPressed: _googleLogin,
                        icon: const Icon(Icons.account_circle, size: 20),
                        label: Text(l10n.authContinueWithGoogle),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
              ),

              const Spacer(flex: 2),

              Text(
                l10n.authTerms,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _onLogoTap() {
    // Easter egg only lights up on Android — iOS goes through TestFlight,
    // web users have other workarounds.
    if (kIsWeb || !Platform.isAndroid) return;
    final now = DateTime.now();
    if (_eggFirstTapAt == null || now.difference(_eggFirstTapAt!) > _eggWindow) {
      _eggFirstTapAt = now;
      _eggTaps = 1;
      return;
    }
    _eggTaps += 1;
    if (_eggTaps >= _eggThreshold) {
      _eggTaps = 0;
      _eggFirstTapAt = null;
      _showSmsLoginSheet();
    }
  }

  Future<void> _showSmsLoginSheet() async {
    final phoneCtrl = TextEditingController();
    // Pre-fill the test OTP — prod backend runs SKIP_SMS_VERIFY=true so
    // any phone + 123456 lets the user in. When real SMS lands, drop the
    // pre-fill.
    final codeCtrl = TextEditingController(text: '123456');
    bool sending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  '手机号登录（测试）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '验证码用 123456',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    hintText: '11 位手机号',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final phone = phoneCtrl.text.trim();
                          final code = codeCtrl.text.trim();
                          if (phone.length != 11 || code.isEmpty) return;
                          setSt(() => sending = true);
                          try {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            await auth.phoneLogin(phone, code);
                            if (auth.isLoggedIn) {
                              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                              // Outer listener handles pop + snackbar.
                            } else {
                              setSt(() => sending = false);
                              if (sheetCtx.mounted) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  SnackBar(content: Text('登录失败：${auth.error ?? "未知错误"}')),
                                );
                              }
                            }
                          } catch (e) {
                            setSt(() => sending = false);
                            if (sheetCtx.mounted) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(content: Text('登录失败：$e')),
                              );
                            }
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('登录'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mobile-only: triggers the imperative GIS flow. On web the GIS button
  /// widget drives everything via `authenticationEvents`, so this isn't used.
  Future<void> _googleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    try {
      await authProvider.googleSignInInteractive();
      // Success path runs via the authenticationEvents listener in AuthProvider,
      // which flips isLoggedIn and wakes our addListener(). Nothing more to do.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorGoogleSignInFailed(e.toString()))),
        );
      }
    }
  }
}
