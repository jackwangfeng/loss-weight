// Thin wrapper over google_sign_in_web's `renderButton()`.
//
// Why: google_sign_in 7.x requires Google's GIS-rendered button on web
// (signIn popup can't come from arbitrary DOM — anti-phishing rule).
// `GoogleSignIn.instance.authenticate()` throws UnimplementedError on web.
//
// Dart can't import `google_sign_in_web/web_only.dart` on non-web platforms,
// so we use a conditional import to swap in a stub for mobile builds.
// The dart:html check works on all Flutter targets — web has it, mobile doesn't.

export 'google_sign_in_button_stub.dart'
    if (dart.library.html) 'google_sign_in_button_web.dart'
    show buildGoogleSignInButton;
