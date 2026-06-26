/// Deep-dive across the DartStream OAuth2 client-credentials flow (ticket #96).
///
/// This probe exercises the machine-to-machine path: exchange a clientId +
/// clientSecret for a DartStream-signed Bearer JWT, then call each service
/// with that token. No Firebase user, no interactive login.
///
/// Requires OAUTH2_CLIENT_ID + OAUTH2_CLIENT_SECRET in the environment
/// (created via the dashboard "Applications" screen after paying).
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '_shared.dart';

Future<void> main() async {
  final env = Env.load();

  final clientId = Platform.environment['OAUTH2_CLIENT_ID'] ?? '';
  final clientSecret = Platform.environment['OAUTH2_CLIENT_SECRET'] ?? '';
  if (clientId.isEmpty || clientSecret.isEmpty) {
    stderr.writeln(
      '[env] missing OAUTH2_CLIENT_ID and/or OAUTH2_CLIENT_SECRET.\n'
      '      Create an Application in the DartStream dashboard\n'
      '      (Settings → Applications) and copy the credentials.',
    );
    exit(2);
  }

  final report = Report('OAuth2 client-credentials deep-dive');
  final h = env.hosts;

  // ── Step 1: exchange client credentials for a Bearer JWT ──────────
  String? accessToken;

  await report.step(
    'token',
    'POST /api/v1/oauth2/token (client_credentials)',
    () async {
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final res = await http.post(
        Uri.parse('${h.auth}/api/v1/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $credentials',
        },
        body: 'grant_type=client_credentials',
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        accessToken = body['access_token'] as String?;
        final expiresIn = body['expires_in'];
        final scope = body['scope'] ?? '';
        stdout.writeln('   token obtained — expires_in=$expiresIn scope=$scope');
      }
      return res;
    },
  );

  if (accessToken == null) {
    stderr.writeln('\n[abort] token exchange failed — cannot continue.');
    report.print();
    exit(1);
  }

  final oauthHeaders = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  // ── Step 2: hit each service with the OAuth2 token ────────────────

  await report.step(
    'platform',
    'GET /api/v1/platform/feature-flags (OAuth2 token)',
    () => http.get(
      Uri.parse('${h.platform}/api/v1/platform/feature-flags'),
      headers: oauthHeaders,
    ),
  );

  await report.step(
    'platform',
    'GET /api/v1/platform/projects (OAuth2 token)',
    () => http.get(
      Uri.parse('${h.platform}/api/v1/platform/projects'),
      headers: oauthHeaders,
    ),
  );

  await report.step(
    'experience',
    'GET /api/v1/experience/profiles/me (OAuth2 token)',
    () => http.get(
      Uri.parse('${h.experience}/api/v1/experience/profiles/me'),
      headers: oauthHeaders,
    ),
  );

  await report.step(
    'reactive',
    'GET /api/v1/reactive/events/subscriptions (OAuth2 token)',
    () => http.get(
      Uri.parse('${h.reactive}/api/v1/reactive/events/subscriptions'),
      headers: oauthHeaders,
    ),
  );

  await report.step(
    'persistence',
    'GET /api/v1/persistence/database (OAuth2 token)',
    () => http.get(
      Uri.parse('${h.persistence}/api/v1/persistence/database'),
      headers: oauthHeaders,
    ),
  );

  // ── Step 3: negative test — garbage Bearer should be rejected ─────

  await report.step(
    'auth',
    'GET /api/v1/platform/feature-flags (garbage Bearer → expect 401/403)',
    () => http.get(
      Uri.parse('${h.platform}/api/v1/platform/feature-flags'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer not-a-real-token',
      },
    ),
    ok: (status) => status == 401 || status == 403,
  );

  report.print();
}
