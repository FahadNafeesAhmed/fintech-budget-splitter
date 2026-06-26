/// Shared helpers for the bin/ CLIs.
///
/// These probes deliberately hand-write the Firebase Identity Toolkit + raw
/// DartStream HTTP calls so they verify the deployed contracts independently
/// of the dartstream_client SDK that the Flutter frontend uses. Don't copy
/// this pattern into an app — use the SDK there.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class Env {
  Env._(this.firebaseApiKey, this.testEmail, this.testPassword, this.projectId,
      this.environmentId, this.hosts);

  final String firebaseApiKey;
  final String testEmail;
  final String testPassword;
  final String projectId;
  final String environmentId;
  final ServiceHosts hosts;

  static Env load() {
    String req(String k) {
      final v = Platform.environment[k];
      if (v == null || v.isEmpty) {
        stderr.writeln('[env] missing $k — copy .env.example to .env and fill it in.');
        exit(2);
      }
      return v;
    }

    String opt(String k, String fallback) =>
        Platform.environment[k]?.trim().isNotEmpty == true
            ? Platform.environment[k]!
            : fallback;

    return Env._(
      req('FIREBASE_API_KEY'),
      req('TEST_EMAIL'),
      req('TEST_PASSWORD'),
      opt('PROJECT_ID', 'fintech-budget-splitter'),
      opt('ENVIRONMENT_ID', 'development'),
      ServiceHosts(
        auth: opt('API_AUTH', 'https://dev-apiauth.dartstream.io'),
        platform: opt('API_PLATFORM', 'https://dev-apiplatform.dartstream.io'),
        experience: opt('API_EXPERIENCE', 'https://dev-apiexperience.dartstream.io'),
        reactive: opt('API_REACTIVE', 'https://dev-apireactive.dartstream.io'),
        persistence: opt('API_PERSISTENCE', 'https://dev-apipersistence.dartstream.io'),
        billing: opt('API_BILLING', 'https://dev-apibilling.dartstream.io'),
      ),
    );
  }
}

class ServiceHosts {
  ServiceHosts({
    required this.auth,
    required this.platform,
    required this.experience,
    required this.reactive,
    required this.persistence,
    required this.billing,
  });
  final String auth;
  final String platform;
  final String experience;
  final String reactive;
  final String persistence;

  /// Host that mounts the OAuth2 token endpoint (ds-billing).
  final String billing;
}

/// Sign in (auto-signup on first run) with Firebase Identity Toolkit and
/// return the freshly minted ID token. This mirrors the browser flow used
/// by the Flutter client.
Future<String> firebaseSignIn(Env env) async {
  final signInUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${env.firebaseApiKey}';
  final signUpUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${env.firebaseApiKey}';

  Future<http.Response> hit(String url) => http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': env.testEmail,
          'password': env.testPassword,
          'returnSecureToken': true,
        }),
      );

  var res = await hit(signInUrl);
  if (res.statusCode == 400 &&
      (res.body.contains('EMAIL_NOT_FOUND') ||
          res.body.contains('INVALID_LOGIN_CREDENTIALS'))) {
    res = await hit(signUpUrl);
  }
  if (res.statusCode != 200) {
    throw StateError('Firebase auth failed (${res.statusCode}): ${res.body}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return body['idToken'] as String;
}

/// Onboard the user against ds-auth and return the resolved
/// (userId, tenantId) pair. Signup is idempotent — returning users get the
/// same record back.
Future<({String userId, String tenantId})> onboard(
  ServiceHosts hosts,
  String idToken,
) async {
  final res = await http.post(
    Uri.parse('${hosts.auth}/api/v1/auth/signup'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    },
    body: jsonEncode({}),
  );
  if (res.statusCode == 409) {
    // Idempotent fallback: the user exists, just log in.
    final login = await http.post(
      Uri.parse('${hosts.auth}/api/v1/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    );
    if (login.statusCode >= 400) {
      throw StateError('login fallback failed (${login.statusCode}): ${login.body}');
    }
    final body = jsonDecode(login.body) as Map<String, dynamic>;
    return (
      userId: (body['userId'] ?? body['user_id']).toString(),
      tenantId: (body['tenantId'] ?? body['tenant_id']).toString(),
    );
  }
  if (res.statusCode >= 400) {
    throw StateError('signup failed (${res.statusCode}): ${res.body}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return (
    userId: (body['userId'] ?? body['user_id']).toString(),
    tenantId: (body['tenantId'] ?? body['tenant_id']).toString(),
  );
}

/// Tracks PASS/FAIL/SKIP across a deep-dive run and prints a summary table.
class Report {
  Report(this.title);
  final String title;
  final List<_Row> _rows = [];

  Future<void> step(
    String group,
    String name,
    Future<http.Response> Function() call, {
    bool Function(int status)? ok,
    String? skipReason,
  }) async {
    if (skipReason != null) {
      _rows.add(_Row(group, name, 'SKIP', 0, skipReason));
      return;
    }
    try {
      final res = await call();
      final isOk = ok?.call(res.statusCode) ?? (res.statusCode < 400);
      final excerpt = res.body.length > 100 ? '${res.body.substring(0, 100)}…' : res.body;
      _rows.add(_Row(group, name, isOk ? 'PASS' : 'FAIL', res.statusCode, excerpt));
    } catch (e) {
      _rows.add(_Row(group, name, 'FAIL', 0, e.toString()));
    }
  }

  void print() {
    stdout.writeln('\n=== $title ===');
    var pass = 0, fail = 0, skip = 0;
    String? group;
    for (final r in _rows) {
      if (r.group != group) {
        stdout.writeln('\n[${r.group}]');
        group = r.group;
      }
      stdout.writeln('  ${r.status.padRight(4)} ${r.code.toString().padLeft(3)} ${r.name}');
      if (r.status == 'PASS') pass++;
      if (r.status == 'FAIL') fail++;
      if (r.status == 'SKIP') skip++;
    }
    stdout.writeln('\n--- $pass PASS / $fail FAIL / $skip SKIP (${_rows.length} total) ---');
    if (fail > 0) exitCode = 1;
  }
}

class _Row {
  _Row(this.group, this.name, this.status, this.code, this.excerpt);
  final String group;
  final String name;
  final String status;
  final int code;
  final String excerpt;
}

Map<String, String> bearer(String idToken, {String? tenantId}) => {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
      if (tenantId != null) 'X-Tenant-ID': tenantId,
    };

bool destructiveEnabled() =>
    (Platform.environment['DEEPDIVE_DESTRUCTIVE'] ?? '') == '1';
