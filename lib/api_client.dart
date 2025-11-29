import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  String? token;

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': role,
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> forgot(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/forgot'),
      headers: _headers(),
      body: jsonEncode({'email': email}),
    );
    return _decode(res);
  }

  Future<List<dynamic>> fetchClasses() async {
    final res = await http.get(Uri.parse('$baseUrl/classes'), headers: _headers());
    final data = _decode(res);
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> createClass(String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/classes'),
      headers: _headers(),
      body: jsonEncode({'name': name}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> joinClass(String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/classes/join'),
      headers: _headers(),
      body: jsonEncode({'code': code}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateEnrollmentStatus(int id, String status) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/classes/enrollments/$id'),
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    return _decode(res);
  }

  Future<List<dynamic>> fetchMoodEntries() async {
    final res = await http.get(Uri.parse('$baseUrl/mood'), headers: _headers());
    final data = _decode(res);
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> markMoodAsRead(int id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/mood/$id/read'),
      headers: _headers(),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> submitMood(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/mood'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    return _decode(res);
  }

  Future<List<dynamic>> fetchJustificantes() async {
    final res = await http.get(Uri.parse('$baseUrl/justificantes'), headers: _headers());
    final data = _decode(res);
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> submitJustificante(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/justificantes'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateJustificanteStatus(int id, String status) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/justificantes/$id'),
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    return _decode(res);
  }

  Future<List<dynamic>> fetchSchedules() async {
    final res = await http.get(Uri.parse('$baseUrl/schedules'), headers: _headers());
    final data = _decode(res);
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> submitSchedule(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/schedules'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? {} : jsonDecode(res.body);
    } catch (_) {
      // Respuesta no JSON (p.e. HTML de error)
      final raw = res.body;
      if (raw.contains('<!DOCTYPE html') || raw.contains('<html')) {
        body = {'raw': 'El servidor devolvió HTML (status ${res.statusCode}).'};
      } else {
        body = {'raw': raw};
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    if (body is Map && body['error'] != null) {
      throw Exception(body['error']);
    }

    final raw = body is Map && body['raw'] != null ? body['raw'] : res.body;
    throw Exception(raw.toString().isNotEmpty ? raw : 'Error ${res.statusCode}');
  }
}
