/// Deep-dive across ds-persistence — database connections, storage configs,
/// logging.
library;

import 'package:http/http.dart' as http;

import '_shared.dart';

Future<void> main() async {
  final env = Env.load();
  final idToken = await firebaseSignIn(env);
  final ids = await onboard(env.hosts, idToken);
  final h = env.hosts.persistence;
  final headers = bearer(idToken, tenantId: ids.tenantId);
  final report = Report('Persistence deep-dive');

  await report.step('database', 'GET /api/v1/persistence/database',
      () => http.get(Uri.parse('$h/api/v1/persistence/database'), headers: headers));
  await report.step('database', 'GET /api/v1/persistence/database/connections',
      () => http.get(Uri.parse('$h/api/v1/persistence/database/connections'), headers: headers));

  await report.step('storage', 'GET /api/v1/persistence/storage/configs',
      () => http.get(Uri.parse('$h/api/v1/persistence/storage/configs'), headers: headers));

  await report.step('logging', 'GET /api/v1/persistence/logging/configs',
      () => http.get(Uri.parse('$h/api/v1/persistence/logging/configs'), headers: headers));
  await report.step('logging', 'GET /api/v1/persistence/logging/entries',
      () => http.get(Uri.parse('$h/api/v1/persistence/logging/entries'), headers: headers));

  report.print();
}
