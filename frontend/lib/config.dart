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
  /// Firebase web API key — injected at build/run time, never committed.
  ///
  /// Local dev: pass `--dart-define=FIREBASE_API_KEY=<key>`.
  /// Firebase Hosting: `lib/bootstrap.dart` loads the public config from
  /// `/__/firebase/init.json` (auto-served by the Hosting origin), so no
  /// key is embedded in the deployed build either.
  ///
  /// Web API keys identify the project to Google's APIs and are public-by-
  /// design (security is enforced by Firebase rules + the authorized-domain
  /// list), but per the DartStream "no committed keys" house standard we keep
  /// it out of source control regardless.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');

  /// Whether a key was actually injected; the login flow surfaces this.
  static bool get hasFirebaseApiKey => firebaseApiKey.isNotEmpty;

  /// FinTech app project scoping for the DartStream experience layer.
  /// Note: the SDK is configured for `DartStreamConfig.dev()` in session.dart,
  /// so the environment label here must match (dev hosts → `development`).
  static const projectId = 'fintech-budget-splitter';
  static const environmentId = 'development';
}
