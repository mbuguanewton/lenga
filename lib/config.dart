/// Google Calendar OAuth configuration.
///
/// `serverClientId` is the *Web application* OAuth client ID from Google Cloud
/// Console (google_sign_in 7 on Android authenticates through it; the Android
/// client with this app's package name + SHA-1 must exist in the same project).
/// Supply it without editing source:
///   flutter run --dart-define=LENGA_GOOGLE_SERVER_CLIENT_ID=123-abc.apps.googleusercontent.com
/// See README.md for the full setup.
class LengaConfig {
  const LengaConfig._();

  static const placeholderClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  static const googleServerClientId = String.fromEnvironment(
    'LENGA_GOOGLE_SERVER_CLIENT_ID',
    defaultValue: placeholderClientId,
  );

  static bool get googleConfigured => googleServerClientId != placeholderClientId;

  static const missingClientIdMessage =
      'This build has no Google client ID, so Calendar can\'t connect or refresh. '
      'Rebuild with --dart-define-from-file=env.json (see README). Your events and toggles are kept.';
}
