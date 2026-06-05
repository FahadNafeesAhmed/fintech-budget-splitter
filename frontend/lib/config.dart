/// Hosts and Firebase config for the FinTech Budget Splitter.
///
/// Follows the DartStream AppConfig pattern from the founder's sample app.
///
/// Firebase project: fintech-budget-splitter
///   projectId        : fintech-budget-splitter
///   authDomain       : fintech-budget-splitter.firebaseapp.com
///   storageBucket    : fintech-budget-splitter.firebasestorage.app
///   messagingSenderId: 641788475041
///   appId            : 1:641788475041:web:588a3eabaca172896262e0
///   measurementId    : G-C6JYZ4P7KE
///
/// The Firebase API key is injected at build/run time and is NOT committed.
/// Pass it via:
///   flutter run -d chrome --dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY
class AppConfig {
  static const firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');

  /// Whether a key was actually injected; the login flow surfaces this.
  static bool get hasFirebaseApiKey => firebaseApiKey.isNotEmpty;

  /// DartStream microservice hosts (dev environment).
  /// Replace with production hosts when deploying to prod.
  static const authHost = 'https://dev-apiauth.dartstream.io';
  static const platformHost = 'https://dev-apiplatform.dartstream.io';
  static const experienceHost = 'https://dev-apiexperience.dartstream.io';
  static const reactiveHost = 'https://dev-apireactive.dartstream.io';
  static const persistenceHost = 'https://dev-apipersistence.dartstream.io';

  /// FinTech app project/environment scoping for DartStream experience layer.
  static const projectId = 'fintech-budget-splitter';
  static const environmentId = 'production';
}
