/// OAuth / identity configuration.
///
/// `googleClientId` is the **Web** OAuth 2.0 Client ID from Google Cloud
/// Console (Credentials). It's a public identifier — the security anchor is
/// that the backend verifies incoming ID tokens against the same ID as their
/// `aud` claim, so a leaked client ID can't be used to forge tokens.
///
/// Override per environment with:
///   flutter build web --dart-define=GOOGLE_CLIENT_ID=<other-id>
library;

const String googleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue:
      '604310975641-chq87tal9oii607rigc1uq59vjsirgas.apps.googleusercontent.com',
);
