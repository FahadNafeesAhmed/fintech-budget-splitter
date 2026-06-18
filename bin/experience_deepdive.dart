/// Deep-dive across ds-experience-orchestration — profiles, cloud-save
/// (split_history slot used by the Flutter client), inventory, sessions,
/// connectors.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '_shared.dart';

Future<void> main() async {
  final env = Env.load();
  final idToken = await firebaseSignIn(env);
  final ids = await onboard(env.hosts, idToken);
  final h = env.hosts.experience;
  final headers = bearer(idToken, tenantId: ids.tenantId);
  final report = Report('Experience deep-dive');

  // Browsers strip X-User-ID off the CORS preflight, so the Flutter client
  // (and these probes) pass scope as query params instead.
  final scopeQs =
      'projectId=${env.projectId}&environmentId=${env.environmentId}&userId=${ids.userId}&tenantId=${ids.tenantId}';

  await report.step('profiles', 'GET  /api/v1/experience/profiles/me',
      () => http.get(Uri.parse('$h/api/v1/experience/profiles/me?$scopeQs'), headers: headers));
  await report.step('profiles', 'PATCH /api/v1/experience/profiles/me',
      () => http.patch(
            Uri.parse('$h/api/v1/experience/profiles/me?$scopeQs'),
            headers: headers,
            body: jsonEncode({'displayName': 'Budget Splitter Smoke'}),
          ));

  // cloud-save round-trip on the slot the app uses
  const slot = 'split_history';
  await report.step('cloud-save', 'POST /api/v1/experience/cloud-save/$slot (write)',
      () => http.post(
            Uri.parse('$h/api/v1/experience/cloud-save/$slot?$scopeQs'),
            headers: headers,
            body: jsonEncode({'items': [
              {'total_amount': 42.0, 'number_of_people': 3, 'amount_per_person': 14.0}
            ]}),
          ));
  await report.step('cloud-save', 'GET  /api/v1/experience/cloud-save/$slot (read)',
      () => http.get(Uri.parse('$h/api/v1/experience/cloud-save/$slot?$scopeQs'), headers: headers));
  await report.step('cloud-save', 'POST /api/v1/experience/cloud-save/$slot (overwrite)',
      () => http.post(
            Uri.parse('$h/api/v1/experience/cloud-save/$slot?$scopeQs'),
            headers: headers,
            body: jsonEncode({'items': []}),
          ));

  await report.step('inventory', 'GET  /api/v1/experience/inventory/items',
      () => http.get(Uri.parse('$h/api/v1/experience/inventory/items?$scopeQs'), headers: headers));

  await report.step('sessions', 'GET  /api/v1/experience/sessions/active',
      () => http.get(Uri.parse('$h/api/v1/experience/sessions/active?$scopeQs'), headers: headers));

  await report.step('connectors', 'GET  /api/v1/experience/connectors',
      () => http.get(Uri.parse('$h/api/v1/experience/connectors'), headers: headers));

  report.print();
}
