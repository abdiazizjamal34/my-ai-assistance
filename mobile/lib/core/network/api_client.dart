import 'dart:convert';

import 'package:http/http.dart' as http;

class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.service,
    required this.database,
  });

  final String status;
  final String service;
  final String database;

  bool get isHealthy => status == 'ok' && database == 'ok';

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      service: json['service'] as String? ?? 'unknown',
      database: json['database'] as String? ?? 'unknown',
    );
  }
}

class ApiClient {
  ApiClient({required String baseUrl, required this.userId, http.Client? client})
      : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final String userId;
  final http.Client _client;

  String? _authToken;

  void setAuthToken(String? token) => _authToken = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-user-id': userId,
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        
      };

  Future<HealthStatus> getHealth() async {
    final response = await _client.get(Uri.parse('$baseUrl/health'));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final health = HealthStatus.fromJson(body);
    if (response.statusCode >= 400) {
      throw Exception('Backend returned ${response.statusCode}.');
    }
    return health;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> data) async {
    final response = await _client.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> data) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _client.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(body['error'] as String? ?? 'Request failed.');
    }
    return body;
  }
}