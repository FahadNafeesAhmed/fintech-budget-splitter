import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_models/shared_models.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'http://localhost:8080';

  Future<SplitResult> calculateSplit(Transaction transaction) async {
    final uri = Uri.parse('$_baseUrl/api/transactions');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(transaction.toJson()),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SplitResult.fromJson(json);
    }

    final error = jsonDecode(response.body) as Map<String, dynamic>;
    throw ApiException(
      statusCode: response.statusCode,
      message: error['error'] as String? ?? 'Unknown error',
    );
  }
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
