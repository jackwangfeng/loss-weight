import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// Renders Google's GIS-branded button. When tapped, GIS triggers its own
/// popup/one-tap flow and emits the credential via the
/// `GoogleSignIn.instance.authenticationEvents` stream — AuthProvider picks
/// it up there. We don't handle the tap ourselves.
Widget buildGoogleSignInButton() {
  return gsi_web.renderButton(
    configuration: gsi_web.GSIButtonConfiguration(
      theme: gsi_web.GSIButtonTheme.filledBlack,
      shape: gsi_web.GSIButtonShape.pill,
      text: gsi_web.GSIButtonText.continueWith,
      size: gsi_web.GSIButtonSize.large,
      minimumWidth: 280,
    ),
  );
}
