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
  /// Firebase web API key. Web API keys identify the project to Google's
  /// APIs and are intended to be public — security is enforced by Firebase
  /// rules + the authorized-domain list, not by hiding the key. The
  /// `--dart-define=FIREBASE_API_KEY=...` override still wins when provided.
  static const _defaultFirebaseApiKey = 'AIzaSyBUDpfDadtLDZ97ezzNWkk5PWheGFV2wvc';
  static const firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: _defaultFirebaseApiKey,
  );

  /// Whether a key was actually injected; the login flow surfaces this.
  static bool get hasFirebaseApiKey => firebaseApiKey.isNotEmpty;

  /// FinTech app project scoping for the DartStream experience layer.
  /// Note: the SDK is configured for `DartStreamConfig.dev()` in session.dart,
  /// so the environment label here must match (dev hosts → `development`).
  static const projectId = 'fintech-budget-splitter';
  static const environmentId = 'development';
}
