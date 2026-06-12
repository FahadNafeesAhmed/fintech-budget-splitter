import 'package:dartstream_client/dartstream_client.dart';
import 'package:flutter/foundation.dart';

enum SessionStatus { signedOut, signingIn, signedIn, error }

/// Session state powered by the public `dartstream_client` SDK.
///
/// The SDK's `DartStreamClient.signIn` / `signUp` do the full handshake in
/// one call: Firebase Identity Toolkit auth + ds-auth onboarding. The returned
/// [DartStreamConnection] carries a resolved [DartStreamSession] (with
/// `userId`, `tenantId`, `email`, `idToken`) and a session-bound
/// [DartStreamClient] used for all subsequent service calls
/// (`experience`, `reactive`, `platform`, `persistence`, `billing`).
class Session extends ChangeNotifier {
  Session({required this.firebaseApiKey});

  /// Resolved at app boot from `/__/firebase/init.json` on Firebase Hosting,
  /// or the const fallback locally — see `bootstrap.dart`.
  final String firebaseApiKey;

  SessionStatus status = SessionStatus.signedOut;
  String? errorMessage;
  DartStreamConnection? _connection;

  bool get isSignedIn => status == SessionStatus.signedIn;

  DartStreamClient? get client => _connection?.client;
  DartStreamSession? get dsSession => _connection?.session;
  String? get email => _connection?.session.email;
  String? get userId => _connection?.session.userId;
  String? get tenantId => _connection?.session.tenantId;

  DartStreamConfig get _config =>
      DartStreamConfig.dev(firebaseApiKey: firebaseApiKey);

  Future<void> signUp(String email, String password) => _authenticate(
        () => DartStreamClient.signUp(
          config: _config,
          email: email,
          password: password,
        ),
      );

  Future<void> signIn(String email, String password) => _authenticate(
        () => DartStreamClient.signIn(
          config: _config,
          email: email,
          password: password,
        ),
      );

  Future<void> _authenticate(
    Future<DartStreamConnection> Function() doAuth,
  ) async {
    status = SessionStatus.signingIn;
    errorMessage = null;
    notifyListeners();

    try {
      _connection = await doAuth();
      status = SessionStatus.signedIn;
    } catch (e) {
      status = SessionStatus.error;
      errorMessage = _readable(e);
    }

    notifyListeners();
  }

  String _readable(Object e) {
    final s = e.toString();
    // Browser-side network failure (most often CORS rejection from the
    // DartStream backend, which only whitelists http://localhost:8080 on
    // dev). Identity Toolkit calls succeed; the ds-auth POST is blocked.
    if (s.contains('ClientException') &&
        (s.contains('Failed to fetch') ||
            s.contains('NetworkError') ||
            s.contains('XMLHttpRequest'))) {
      return 'Could not reach DartStream (CORS or network). '
          'The dev backend only allows http://localhost:8080; '
          'run with `flutter run -d chrome --web-port=8080`, or ask the '
          'DartStream team to whitelist this origin.';
    }
    if (s.contains('EMAIL_EXISTS')) {
      return 'An account with that email already exists — switch to Sign In.';
    }
    if (s.contains('EMAIL_NOT_FOUND') ||
        s.contains('INVALID_LOGIN_CREDENTIALS') ||
        s.contains('INVALID_PASSWORD')) {
      return 'Invalid email or password.';
    }
    if (s.contains('WEAK_PASSWORD')) {
      return 'Password is too weak — use at least 6 characters.';
    }
    if (s.contains('INVALID_EMAIL')) {
      return 'That email address is not valid.';
    }
    if (s.contains('TOO_MANY_ATTEMPTS')) {
      return 'Too many attempts — please wait a moment and try again.';
    }
    return s;
  }

  void signOut() {
    _connection = null;
    status = SessionStatus.signedOut;
    errorMessage = null;
    notifyListeners();
  }
}
