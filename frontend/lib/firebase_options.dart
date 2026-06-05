import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return web; // fallback — add platform configs when needed
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'FIREBASE_WEB_API_KEY_REDACTED',
    authDomain: 'fintech-budget-splitter.firebaseapp.com',
    projectId: 'fintech-budget-splitter',
    storageBucket: 'fintech-budget-splitter.firebasestorage.app',
    messagingSenderId: '641788475041',
    appId: '1:641788475041:web:588a3eabaca172896262e0',
    measurementId: 'G-C6JYZ4P7KE',
  );
}
