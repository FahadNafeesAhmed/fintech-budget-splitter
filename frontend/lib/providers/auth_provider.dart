import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_service.dart';

/// Singleton FirebaseService shared across the app.
final firebaseServiceProvider = Provider<FirebaseService>(
  (_) => FirebaseService(),
);

/// Streams the current Firebase auth state.
/// Yields [User] when signed in, null when signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
});

/// Derived provider — true only when a user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

/// Streams the signed-in user's transaction history from Firestore.
/// Throws [StateError] if called while unauthenticated.
final transactionHistoryProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final isAuth = ref.watch(isAuthenticatedProvider);

  if (!isAuth) {
    // Return an empty stream — UI should gate on [authStateProvider] first.
    return const Stream.empty();
  }

  return service.transactionHistoryStream();
});
