/// Deep-dive across ds-reactive-dataflow — events, streaming, notifications,
/// lifecycle hooks. CRUD groups self-clean.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '_shared.dart';

Future<void> main() async {
  final env = Env.load();
  final idToken = await firebaseSignIn(env);
  final ids = await onboard(env.hosts, idToken);
  final h = env.hosts.reactive;
  final headers = bearer(idToken, tenantId: ids.tenantId);
  final report = Report('Reactive deep-dive');

  // events — log the same event types the Flutter client emits
  for (final type in ['split_calculated', 'split_error', 'smoke.ping']) {
    await report.step('events', 'POST /api/v1/reactive/events/log ($type)',
        () => http.post(
              Uri.parse('$h/api/v1/reactive/events/log'),
              headers: headers,
              body: jsonEncode({
                'eventType': type,
                'payload': {'source': 'reactive_deepdive.dart'},
              }),
            ));
  }
  await report.step('events', 'GET  /api/v1/reactive/events',
      () => http.get(Uri.parse('$h/api/v1/reactive/events'), headers: headers));

  // streaming channels CRUD
  final channelName = 'smoke_${DateTime.now().millisecondsSinceEpoch}';
  await report.step('streaming', 'GET    /api/v1/reactive/streaming/channels',
      () => http.get(Uri.parse('$h/api/v1/reactive/streaming/channels'), headers: headers));
  await report.step('streaming', 'POST   /api/v1/reactive/streaming/channels',
      () => http.post(
            Uri.parse('$h/api/v1/reactive/streaming/channels'),
            headers: headers,
            body: jsonEncode({'name': channelName}),
          ));
  await report.step('streaming', 'DELETE /api/v1/reactive/streaming/channels/$channelName',
      () => http.delete(Uri.parse('$h/api/v1/reactive/streaming/channels/$channelName'), headers: headers));

  // notifications + lifecycle (reads)
  await report.step('notifications', 'GET  /api/v1/reactive/notifications/configs',
      () => http.get(Uri.parse('$h/api/v1/reactive/notifications/configs'), headers: headers));
  await report.step('lifecycle', 'GET  /api/v1/reactive/lifecycle/hooks',
      () => http.get(Uri.parse('$h/api/v1/reactive/lifecycle/hooks'), headers: headers));

  report.print();
}
