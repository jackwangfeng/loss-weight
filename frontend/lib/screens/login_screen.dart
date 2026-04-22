import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
              Icon(
                Icons.fitness_center,
                size: 72,
                color: scheme.primary,
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
