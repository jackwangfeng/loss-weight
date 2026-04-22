import 'package:flutter/widgets.dart';

/// Mobile / non-web stub. On iOS/Android we'll wire up a custom button that
/// calls `GoogleSignIn.instance.authenticate()` directly; this stub is just
/// here to keep the conditional import valid.
Widget buildGoogleSignInButton() => const SizedBox.shrink();
