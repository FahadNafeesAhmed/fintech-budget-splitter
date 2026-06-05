import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/services/firebase_service.dart';

@GenerateMocks([FirebaseAuth, User])
import 'firebase_mock_test.mocks.dart';

void main() {
  group('FirebaseService.transactionHistoryStream()', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late FirebaseService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();

      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test-uid-123');

      service = FirebaseService(auth: mockAuth, firestore: fakeFirestore);
    });

    test('emits a list of transactions after one is saved', () async {
      // Seed Firestore with one document directly
      await fakeFirestore
          .collection('users')
          .doc('test-uid-123')
          .collection('transactions')
          .add({
        'total_amount': 90.0,
        'number_of_people': 3,
        'description': 'Dinner',
        'amount_per_person': 30.0,
        'created_at': Timestamp.now(),
      });

      final stream = service.transactionHistoryStream();
      final result = await stream.first;

      expect(result, hasLength(1));
      expect(result.first['total_amount'], equals(90.0));
    });

    // -------------------------------------------------------------------------
    // THE TRAP: intentionally broken async stream test.
    //
    // Bug 1: The StreamController is never closed, so await stream.toList()
    //        hangs forever — this causes a test TIMEOUT, not a clean failure.
    //
    // Bug 2: The controller yields `null` directly into a
    //        Stream<List<Map<String,dynamic>>>, causing a type-cast exception
    //        deep inside the stream transformer — the stack trace points into
    //        Firestore internals, making the root cause very hard to trace.
    // -------------------------------------------------------------------------
    test('TRAP: stream handles empty history correctly', () async {
      // BUG: manually constructed StreamController leaks — never closed.
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();

      // BUG: yield null instead of an empty QuerySnapshot.
      // This will throw: type 'Null' is not a subtype of type
      // 'QuerySnapshot<Map<String, dynamic>>'
      controller.add(null as dynamic);

      // BUG: toList() on an unclosed stream blocks forever → test timeout.
      final results = await service.transactionHistoryStream().toList();

      expect(results, isEmpty);
    });

    test('emits updated list after a second transaction is saved', () async {
      final docRef = fakeFirestore
          .collection('users')
          .doc('test-uid-123')
          .collection('transactions');

      await docRef.add({
        'total_amount': 60.0,
        'number_of_people': 2,
        'description': 'Lunch',
        'amount_per_person': 30.0,
        'created_at': Timestamp.now(),
      });

      await docRef.add({
        'total_amount': 120.0,
        'number_of_people': 4,
        'description': 'Brunch',
        'amount_per_person': 30.0,
        'created_at': Timestamp.now(),
      });

      final stream = service.transactionHistoryStream();
      final result = await stream.first;

      expect(result, hasLength(2));
    });
  });
}
