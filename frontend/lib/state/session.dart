import 'package:flutter/foundation.dart';

import '../api/dartstream.dart';
import '../api/firebase_auth.dart';

enum SessionStatus { signedOut, signingIn, signedIn, error }

/// Session state following the DartStream pattern from the founder's sample app.
///
/// Authentication flow:
///   1. Firebase Identity Toolkit issues an ID token (client-side).
///   2. DartStream's ds-auth backend verifies the token and returns userId + tenantId.
///   3. All subsequent API calls use the DartstreamApi instance with the Bearer token.
class Session extends ChangeNotifier {
  SessionStatus status = SessionStatus.signedOut;
  String? email;
  String? userId;
  String? tenantId;
  String? errorMessage;
  DartstreamApi? api;

  bool get isSignedIn => status == SessionStatus.signedIn;

  Future<void> signUp(String email, String password) =>
      _authenticate(() => FirebaseAuthRest.signUp(email, password));

  Future<void> signIn(String email, String password) =>
      _authenticate(() => FirebaseAuthRest.signIn(email, password));

  Future<void> _authenticate(
    Future<FirebaseAuthResult> Function() firebaseAuth,
  ) async {
    status = SessionStatus.signingIn;
    errorMessage = null;
    notifyListeners();

    try {
      final auth = await firebaseAuth();
      final dsApi = DartstreamApi(idToken: auth.idToken);
      final ids = await dsApi.signup();
      api = dsApi;
      this.email = auth.email;
      userId = ids.userId;
      tenantId = ids.tenantId;
      status = SessionStatus.signedIn;
    } catch (e) {
      status = SessionStatus.error;
      errorMessage = _readable(e);
    }

    notifyListeners();
  }

  String _readable(Object e) {
    final s = e.toString();
    return s.startsWith('FirebaseAuthException: ')
        ? s.substring('FirebaseAuthException: '.length)
        : s;
  }

  void signOut() {
    status = SessionStatus.signedOut;
    email = null;
    userId = null;
    tenantId = null;
    errorMessage = null;
    api = null;
    notifyListeners();
  }
}
