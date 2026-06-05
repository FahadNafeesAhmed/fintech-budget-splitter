import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_models/shared_models.dart' as models;

class FirebaseService {
  FirebaseService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // --- Auth ---

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;

  // --- Firestore ---

  CollectionReference<Map<String, dynamic>> get _transactionsRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User must be signed in.');
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  /// Saves a completed split to the user's transaction history.
  Future<void> saveTransaction({
    required models.Transaction transaction,
    required models.SplitResult result,
  }) async {
    await _transactionsRef.add({
      'total_amount': transaction.totalAmount,
      'number_of_people': transaction.numberOfPeople,
      'description': transaction.description,
      'amount_per_person': result.amountPerPerson,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Streams the user's transaction history, ordered by most recent.
  Stream<List<Map<String, dynamic>>> transactionHistoryStream() {
    return _transactionsRef
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }
}
