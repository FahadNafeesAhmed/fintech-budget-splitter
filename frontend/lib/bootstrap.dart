import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Loads the public Firebase web config the dartstream_client expects.
///
/// On Firebase Hosting, `/__/firebase/init.json` is auto-served on the
/// origin and contains the project's web config. This is the path the
/// dartstream_client README explicitly recommends for hosted Flutter
/// samples ("load the public Firebase config from /__/firebase/init.json
/// on the Firebase Hosting origin instead of committing API keys").
///
/// Locally (or anywhere init.json isn't reachable), falls back to the
/// const in [AppConfig] so `flutter run -d chrome` still works.
Future<String> loadFirebaseApiKey() async {
  try {
    final resp = await http
        .get(Uri.parse('/__/firebase/init.json'))
        .timeout(const Duration(seconds: 2));
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['apiKey'] is String) {
        final key = decoded['apiKey'] as String;
        if (key.isNotEmpty) return key;
      }
    }
  } catch (_) {
    // /__/firebase/init.json is only served by Firebase Hosting; on
    // localhost without `firebase serve` this will 404 or fail to fetch.
  }
  return AppConfig.firebaseApiKey;
}
