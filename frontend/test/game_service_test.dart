import 'dart:convert';

import 'package:dartstream_client/dartstream_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/services/game_service.dart';

/// MockClient-injected tests verifying GameService sends the correct DartStream
/// service contracts (the two that have historically bitten the cohort):
///   - cloud-save wraps the body in the `{'payload': …}` envelope,
///   - reactive events use the snake_case `event_type` key.
void main() {
  const session = DartStreamSession(
    idToken: 'test-id-token',
    userId: 'user-1',
    tenantId: 'tenant-1',
    raw: {},
    email: 'tester@example.com',
  );

  /// Builds a GameService whose SDK client routes every HTTP call through
  /// [handler] so we can assert on the outgoing request.
  GameService serviceWith(Future<http.Response> Function(http.Request) handler) {
    final mock = MockClient(handler);
    final client = DartStreamClient(
      config: DartStreamConfig.dev(firebaseApiKey: 'test-key'),
      httpClient: mock,
    );
    return GameService(client, session);
  }

  test('saveHighScore sends the {payload: …} cloud-save envelope', () async {
    http.Request? captured;
    final svc = serviceWith((req) async {
      captured = req;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await svc.saveHighScore(4200);

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    // Envelope present — not a bare {'high_score': …}.
    expect(body.containsKey('payload'), isTrue);
    expect(body['payload'], {'high_score': 4200});
  });

  test('logGameOver sends snake_case event_type with payload', () async {
    http.Request? captured;
    final svc = serviceWith((req) async {
      captured = req;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await svc.logGameOver(99);

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['event_type'], 'game_over'); // snake_case, not eventType
    expect(body['payload'], {'score': 99});
  });

  test('loadHighScore returns 0 when the slot is empty', () async {
    final svc = serviceWith((req) async {
      // Empty snapshot response.
      return http.Response(jsonEncode({}), 200);
    });

    final hs = await svc.loadHighScore();
    expect(hs, 0);
  });
}
