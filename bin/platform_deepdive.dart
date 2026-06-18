/// Deep-dive across ds-platform-services. Feature-flag CRUD is exercised
/// as create → read → update → delete so the tenant is left clean.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '_shared.dart';

Future<void> main() async {
  final env = Env.load();
  final idToken = await firebaseSignIn(env);
  final ids = await onboard(env.hosts, idToken);
  final h = env.hosts.platform;
  final headers = bearer(idToken, tenantId: ids.tenantId);
  final report = Report('Platform deep-dive');

  // feature-flags CRUD
  final flagKey = 'smoke_flag_${DateTime.now().millisecondsSinceEpoch}';
  await report.step('feature-flags', 'GET    /api/v1/platform/feature-flags',
      () => http.get(Uri.parse('$h/api/v1/platform/feature-flags'), headers: headers));
  await report.step('feature-flags', 'POST   /api/v1/platform/feature-flags',
      () => http.post(
            Uri.parse('$h/api/v1/platform/feature-flags'),
            headers: headers,
            body: jsonEncode({'key': flagKey, 'enabled': false, 'description': 'smoke'}),
          ));
  await report.step('feature-flags', 'GET    /api/v1/platform/feature-flags/$flagKey',
      () => http.get(Uri.parse('$h/api/v1/platform/feature-flags/$flagKey'), headers: headers));
  await report.step('feature-flags', 'PATCH  /api/v1/platform/feature-flags/$flagKey',
      () => http.patch(
            Uri.parse('$h/api/v1/platform/feature-flags/$flagKey'),
            headers: headers,
            body: jsonEncode({'enabled': true}),
          ));
  await report.step('feature-flags', 'DELETE /api/v1/platform/feature-flags/$flagKey',
      () => http.delete(Uri.parse('$h/api/v1/platform/feature-flags/$flagKey'), headers: headers));

  // projects
  await report.step('projects', 'GET    /api/v1/platform/projects',
      () => http.get(Uri.parse('$h/api/v1/platform/projects'), headers: headers));
  await report.step('projects', 'GET    /api/v1/platform/projects/${env.projectId}/environments',
      () => http.get(Uri.parse('$h/api/v1/platform/projects/${env.projectId}/environments'), headers: headers));
  await report.step('projects', 'GET    /api/v1/platform/projects/${env.projectId}/integrations',
      () => http.get(Uri.parse('$h/api/v1/platform/projects/${env.projectId}/integrations'), headers: headers));

  // api-keys CRUD
  await report.step('api-keys', 'GET    /api/v1/platform/api-keys',
      () => http.get(Uri.parse('$h/api/v1/platform/api-keys'), headers: headers));

  // settings
  await report.step('settings', 'GET    /api/v1/platform/settings/profile',
      () => http.get(Uri.parse('$h/api/v1/platform/settings/profile'), headers: headers));
  await report.step('settings', 'GET    /api/v1/platform/settings/notifications',
      () => http.get(Uri.parse('$h/api/v1/platform/settings/notifications'), headers: headers));

  // team — destructive ops gated
  await report.step('team', 'GET    /api/v1/platform/team/members',
      () => http.get(Uri.parse('$h/api/v1/platform/team/members'), headers: headers));
  await report.step('team', 'GET    /api/v1/platform/team/invitations',
      () => http.get(Uri.parse('$h/api/v1/platform/team/invitations'), headers: headers));
  final skip = destructiveEnabled() ? null : 'set DEEPDIVE_DESTRUCTIVE=1';
  await report.step('team', 'POST   /api/v1/platform/team/invitations',
      () => http.post(
            Uri.parse('$h/api/v1/platform/team/invitations'),
            headers: headers,
            body: jsonEncode({'email': 'invite+smoke@example.com', 'role': 'member'}),
          ),
      skipReason: skip);

  // sub-services
  await report.step('middleware', 'GET    /api/v1/platform/middleware',
      () => http.get(Uri.parse('$h/api/v1/platform/middleware'), headers: headers));
  await report.step('discovery', 'GET    /api/v1/platform/discovery/services',
      () => http.get(Uri.parse('$h/api/v1/platform/discovery/services'), headers: headers));

  report.print();
}
