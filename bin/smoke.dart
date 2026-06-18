/// FinTech Budget Splitter — end-to-end smoke CLI.
///
/// Hits one representative contract per DartStream service to confirm the
/// dev environment is healthy. Prints PASS/FAIL with HTTP status + body
/// excerpt so a regression points straight at the broken contract.
///
/// Usage:
///   set -a && source .env && set +a
///   dart run bin/smoke.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '_shared.dart';

Future<void> main() async {
  final env = Env.load();
  stdout.writeln('-> Signing in as ${env.testEmail}…');
  final idToken = await firebaseSignIn(env);
  final ids = await onboard(env.hosts, idToken);
  stdout.writeln('-> userId=${ids.userId} tenantId=${ids.tenantId}');

  final report = Report('Smoke — FinTech Budget Splitter (all services)');
  final h = env.hosts;
  final headers = bearer(idToken, tenantId: ids.tenantId);

  await report.step('auth', 'GET  /api/v1/auth/me',
      () => http.get(Uri.parse('${h.auth}/api/v1/auth/me'), headers: headers));

  await report.step('platform', 'GET  /api/v1/platform/feature-flags',
      () => http.get(Uri.parse('${h.platform}/api/v1/platform/feature-flags'), headers: headers));

  // The Flutter client gates rounding on this flag — make sure the read
  // contract is intact even if no flag is set yet.
  await report.step('platform', 'GET  /api/v1/platform/feature-flags?key=enable_rounding',
      () => http.get(Uri.parse('${h.platform}/api/v1/platform/feature-flags?key=enable_rounding'), headers: headers));

  await report.step('experience', 'GET  /api/v1/experience/profiles/me',
      () => http.get(Uri.parse('${h.experience}/api/v1/experience/profiles/me?userId=${ids.userId}&tenantId=${ids.tenantId}'), headers: headers));

  // Cloud-save round-trip on the slot the Flutter client uses.
  final slot = 'split_history';
  final scopeQs = 'projectId=${env.projectId}&environmentId=${env.environmentId}&userId=${ids.userId}&tenantId=${ids.tenantId}';
  await report.step('experience', 'POST /api/v1/experience/cloud-save/$slot',
      () => http.post(
            Uri.parse('${h.experience}/api/v1/experience/cloud-save/$slot?$scopeQs'),
            headers: headers,
            body: jsonEncode({'items': []}),
          ));
  await report.step('experience', 'GET  /api/v1/experience/cloud-save/$slot',
      () => http.get(Uri.parse('${h.experience}/api/v1/experience/cloud-save/$slot?$scopeQs'), headers: headers));

  await report.step('experience', 'GET  /api/v1/experience/inventory/items',
      () => http.get(Uri.parse('${h.experience}/api/v1/experience/inventory/items?$scopeQs'), headers: headers));

  await report.step('reactive', 'POST /api/v1/reactive/events/log',
      () => http.post(
            Uri.parse('${h.reactive}/api/v1/reactive/events/log'),
            headers: headers,
            body: jsonEncode({
              'eventType': 'smoke.ping',
              'payload': {'source': 'smoke.dart'},
            }),
          ));
  await report.step('reactive', 'GET  /api/v1/reactive/streaming/channels',
      () => http.get(Uri.parse('${h.reactive}/api/v1/reactive/streaming/channels'), headers: headers));

  await report.step('persistence', 'GET  /api/v1/persistence/database',
      () => http.get(Uri.parse('${h.persistence}/api/v1/persistence/database'), headers: headers));

  report.print();
}
