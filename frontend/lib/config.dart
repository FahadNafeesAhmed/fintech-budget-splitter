/// App config for the FinTech Budget Splitter.
///
/// Service hosts (ds-auth / ds-platform / ds-experience / ds-reactive /
/// ds-persistence) are no longer hard-coded here — `dartstream_client`
/// resolves them from `DartStreamConfig.dev()` / `.prod()` / `.local()`.
///
/// The Firebase API key is injected at build/run time and is NOT committed.
/// Pass it via:
///   flutter run -d chrome --dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY
class AppConfig {
  /// Local-dev fallback Firebase web API key. When the app is served from
  /// Firebase Hosting it prefers `/__/firebase/init.json` (auto-served by
  /// the Hosting origin), per the dartstream_client README. Web API keys
  /// identify the project to Google's APIs and are intended to be public —
  /// security is enforced by Firebase rules + the authorized-domain list.
  /// The `--dart-define=FIREBASE_API_KEY=...` override still wins.
  static const _fallbackFirebaseApiKey = 'FIREBASE_WEB_API_KEY_REDACTED';
  static const firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: _fallbackFirebaseApiKey,
  );

  /// Whether a key was actually injected; the login flow surfaces this.
  static bool get hasFirebaseApiKey => firebaseApiKey.isNotEmpty;

  /// FinTech app project scoping for the DartStream experience layer.
  /// Note: the SDK is configured for `DartStreamConfig.dev()` in session.dart,
  /// so the environment label here must match (dev hosts → `development`).
  static const projectId = 'fintech-budget-splitter';
  static const environmentId = 'development';
}
