/// Deep-dive across the full ds-auth surface used by the budget splitter.
///
/// Destructive operations (DELETE user, revoke-all-sessions) are skipped
/// unless DEEPDIVE_DESTRUCTIVE=1 so a normal run doesn't brick the shared
/// test account.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '_shared.dart';

Future<void> main() async {
  final env = Env.load();
  final idToken = await firebaseSignIn(env);
  final ids = await onboard(env.hosts, idToken);
  final h = env.hosts.auth;
  final headers = bearer(idToken, tenantId: ids.tenantId);
  final report = Report('Auth deep-dive');

  await report.step('auth', 'GET  /api/v1/auth/me',
      () => http.get(Uri.parse('$h/api/v1/auth/me'), headers: headers));
  await report.step('auth', 'GET  /api/v1/auth/user-status',
      () => http.get(Uri.parse('$h/api/v1/auth/user-status'), headers: headers));
  await report.step('auth', 'POST /api/v1/auth/login',
      () => http.post(Uri.parse('$h/api/v1/auth/login'), headers: headers));

  await report.step('users', 'GET  /api/v1/users',
      () => http.get(Uri.parse('$h/api/v1/users'), headers: headers));
  await report.step('users', 'GET  /api/v1/users/${ids.userId}',
      () => http.get(Uri.parse('$h/api/v1/users/${ids.userId}'), headers: headers));
  await report.step('users', 'PATCH /api/v1/users/${ids.userId}',
      () => http.patch(
            Uri.parse('$h/api/v1/users/${ids.userId}'),
            headers: headers,
            body: jsonEncode({'displayName': 'Budget Splitter Smoke'}),
          ));
  await report.step('users', 'GET  /api/v1/users/${ids.userId}/sessions',
      () => http.get(Uri.parse('$h/api/v1/users/${ids.userId}/sessions'), headers: headers));
  await report.step('users', 'GET  /api/v1/users/${ids.userId}/avatar',
      () => http.get(Uri.parse('$h/api/v1/users/${ids.userId}/avatar'), headers: headers));

  for (final p in ['google', 'github', 'microsoft']) {
    await report.step('federated', 'GET  /api/v1/auth/signin/$p',
        () => http.get(Uri.parse('$h/api/v1/auth/signin/$p'), headers: headers));
  }

  await report.step('providers', 'GET  /api/v1/providers',
      () => http.get(Uri.parse('$h/api/v1/providers'), headers: headers));

  // Reversible status transitions are safe to exercise.
  for (final action in ['suspend', 'activate', 'deactivate', 'activate']) {
    await report.step('users', 'POST /api/v1/users/${ids.userId}/$action',
        () => http.post(Uri.parse('$h/api/v1/users/${ids.userId}/$action'), headers: headers));
  }

  // Destructive — gated.
  final destructive = destructiveEnabled() ? null : 'set DEEPDIVE_DESTRUCTIVE=1';
  await report.step('users', 'DELETE /api/v1/users/${ids.userId}',
      () => http.delete(Uri.parse('$h/api/v1/users/${ids.userId}'), headers: headers),
      skipReason: destructive);
  await report.step('users', 'POST /api/v1/users/${ids.userId}/sessions/revoke-all',
      () => http.post(Uri.parse('$h/api/v1/users/${ids.userId}/sessions/revoke-all'), headers: headers),
      skipReason: destructive);

  report.print();
}
