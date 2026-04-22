import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isCodeSent = false;
  int _countdown = 60;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
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
              const SizedBox(height: 48),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: l10n.authPhoneLabel,
                        hintText: l10n.authPhoneHint,
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.authPhoneRequired;
                        }
                        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
                          return l10n.authPhoneInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.authCodeLabel,
                              hintText: l10n.authCodeHint,
                              prefixIcon: const Icon(Icons.shield),
                            ),
                            maxLength: 6,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.authCodeRequired;
                              }
                              if (value.length != 6) {
                                return l10n.authCodeWrongLength;
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isCodeSent ? null : _sendCode,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(130, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _isCodeSent
                                ? l10n.actionResendCode(_countdown)
                                : l10n.actionSendCode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    FilledButton(
                      onPressed: _login,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        l10n.actionSignIn,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Text(
                l10n.authTerms,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    try {
      await authProvider.sendSMSCode(phone);

      if (mounted) {
        setState(() {
          _isCodeSent = true;
          _countdown = 60;
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _countdown--;
            });
          }
        });

        for (int i = 59; i > 0; i--) {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            setState(() {
              _countdown = i;
            });
          }
        }

        if (mounted) {
          setState(() {
            _isCodeSent = false;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.toastCodeSent)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSendFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text;
    final code = _codeController.text;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    try {
      await authProvider.phoneLogin(phone, code);

      if (mounted) {
        if (authProvider.userId != null) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.loadUser(authProvider.userId!);
        }

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.toastSignedIn)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSignInFailed(e.toString()))),
        );
      }
    }
  }
}
