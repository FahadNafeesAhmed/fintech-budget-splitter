import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_models/shared_models.dart' as models;

import '../config.dart';

class SignupResult {
  SignupResult({required this.userId, required this.tenantId});
  final String userId;
  final String tenantId;
}

class DartstreamApiException implements Exception {
  DartstreamApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'DartstreamApiException($statusCode): $body';
}

/// DartStream API client for the FinTech Budget Splitter.
///
/// Follows the contract proven by the founder's sample app against the
/// deployed DartStream dev backend. All requests carry a Firebase ID token
/// as a Bearer header — DartStream's ds-auth service verifies it server-side.
///
/// Service surface used:
///   auth        → signup / login / me / user management
///   platform    → feature flags (e.g. enable_rounding, split_history)
///   persistence → transaction history (cloud save per user)
///   reactive    → event logging (split_calculated, error events)
class DartstreamApi {
  DartstreamApi({required this.idToken});

  final String idToken;

  Map<String, String> _baseHeaders({String? tenantId, bool json = false}) {
    final h = <String, String>{'authorization': 'Bearer $idToken'};
    if (tenantId != null) h['x-tenant-id'] = tenantId;
    if (json) h['content-type'] = 'application/json';
    return h;
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  Future<SignupResult> signup() async {
    final resp = await http.post(
      Uri.parse('${AppConfig.authHost}/api/v1/auth/signup'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (resp.statusCode == 409) {
      // Already onboarded — retry via /login.
      final login = await http.post(
        Uri.parse('${AppConfig.authHost}/api/v1/auth/login'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      return _parseSignup(login);
    }
    return _parseSignup(resp);
  }

  SignupResult _parseSignup(http.Response resp) {
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw DartstreamApiException(resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body);
    final user = (decoded is Map && decoded['data'] is Map)
        ? decoded['data']['user']
        : (decoded is Map ? decoded['user'] : null);

    String? str(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final uid = user is Map ? str(user, ['id', 'user_id', 'uid']) : null;
    String? tid;
    if (user is Map) {
      tid = str(user, ['tenant_id', 'tenantId', 'active_tenant_id']);
    }
    if (tid == null && decoded is Map) {
      tid = decoded['active_tenant_id'] as String? ??
          decoded['tenant_id'] as String?;
    }
    if (uid == null || tid == null) {
      throw DartstreamApiException(
        resp.statusCode,
        'Could not extract userId/tenantId from: ${resp.body}',
      );
    }
    return SignupResult(userId: uid, tenantId: tid);
  }

  Future<Map<String, dynamic>> me() async {
    final resp = await http.get(
      Uri.parse('${AppConfig.authHost}/api/v1/auth/me'),
      headers: _baseHeaders(),
    );
    return _jsonOrThrow(resp);
  }

  // ---------------------------------------------------------------------------
  // Platform — Feature Flags
  //
  // FinTech flags used:
  //   enable_rounding   → when true, backend rounds to 2 decimal places
  //   split_history     → when true, history panel is shown in the UI
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> listFeatureFlags({required String tenantId}) async {
    final resp = await http.get(
      Uri.parse('${AppConfig.platformHost}/api/v1/platform/feature-flags'),
      headers: _baseHeaders(tenantId: tenantId),
    );
    final json = _jsonOrThrow(resp);
    if (json['flags'] is List) return json['flags'] as List;
    if (json['data'] is List) return json['data'] as List;
    return const [];
  }

  Future<bool> isFlagEnabled({
    required String tenantId,
    required String flagKey,
  }) async {
    final flags = await listFeatureFlags(tenantId: tenantId);
    for (final f in flags) {
      if (f is Map && f['key'] == flagKey) {
        return f['enabled'] == true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Persistence — Transaction History
  //
  // Saves every split calculation to the user's DartStream persistence layer.
  // Slot key: 'split_history' — one slot per user, append-style payload.
  // ---------------------------------------------------------------------------

  Future<void> saveSplitTransaction({
    required String userId,
    required String tenantId,
    required models.Transaction transaction,
    required models.SplitResult result,
  }) async {
    final payload = {
      'total_amount': transaction.totalAmount,
      'number_of_people': transaction.numberOfPeople,
      'description': transaction.description,
      'amount_per_person': result.amountPerPerson,
      'calculated_at': DateTime.now().toIso8601String(),
    };

    final resp = await http.post(
      Uri.parse(
        '${AppConfig.experienceHost}/api/v1/experience/cloud-save/snapshot'
        '?userId=${Uri.encodeQueryComponent(userId)}'
        '&tenantId=${Uri.encodeQueryComponent(tenantId)}'
        '&slotKey=split_history'
        '&projectId=${Uri.encodeQueryComponent(AppConfig.projectId)}'
        '&environmentId=${Uri.encodeQueryComponent(AppConfig.environmentId)}',
      ),
      headers: _baseHeaders(tenantId: tenantId, json: true),
      body: jsonEncode({'payload': payload}),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw DartstreamApiException(resp.statusCode, resp.body);
    }
  }

  Future<List<Map<String, dynamic>>> loadSplitHistory({
    required String userId,
    required String tenantId,
  }) async {
    final resp = await http.get(
      Uri.parse(
        '${AppConfig.experienceHost}/api/v1/experience/cloud-save/snapshot'
        '?userId=${Uri.encodeQueryComponent(userId)}'
        '&tenantId=${Uri.encodeQueryComponent(tenantId)}'
        '&slotKey=split_history'
        '&projectId=${Uri.encodeQueryComponent(AppConfig.projectId)}'
        '&environmentId=${Uri.encodeQueryComponent(AppConfig.environmentId)}',
      ),
      headers: _baseHeaders(tenantId: tenantId),
    );
    if (resp.statusCode == 404) return [];
    final json = _jsonOrThrow(resp);
    final data = json['payload'] ?? json['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  // ---------------------------------------------------------------------------
  // Reactive — Event Logging
  //
  // Logs split_calculated and split_error events to DartStream's reactive
  // event pipeline for analytics and DartCodeAI ingestion.
  // ---------------------------------------------------------------------------

  Future<void> logSplitCalculated({
    required String tenantId,
    required models.Transaction transaction,
    required models.SplitResult result,
  }) async {
    await logEvent(
      tenantId: tenantId,
      eventType: 'split_calculated',
      payload: {
        'total_amount': transaction.totalAmount,
        'number_of_people': transaction.numberOfPeople,
        'amount_per_person': result.amountPerPerson,
        'description': transaction.description,
      },
    );
  }

  Future<void> logSplitError({
    required String tenantId,
    required String error,
  }) async {
    await logEvent(
      tenantId: tenantId,
      eventType: 'split_error',
      payload: {'error': error},
    );
  }

  Future<void> logEvent({
    required String tenantId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    final resp = await http.post(
      Uri.parse('${AppConfig.reactiveHost}/api/v1/reactive/events/log'),
      headers: _baseHeaders(tenantId: tenantId, json: true),
      body: jsonEncode({'event_type': eventType, 'payload': payload}),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw DartstreamApiException(resp.statusCode, resp.body);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _jsonOrThrow(http.Response resp) {
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw DartstreamApiException(resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }
}
