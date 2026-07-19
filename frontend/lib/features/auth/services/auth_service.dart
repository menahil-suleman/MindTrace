import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';
import '../models/user_model.dart';

/// Exception carrying the human-readable server message.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  // ── Signup ────────────────────────────────────────────────────────────────
  /// Calls POST /auth/signup.
  /// [dateOfBirth] must be formatted as "YYYY-MM-DD".
  Future<UserOut> signup({
    required String email,
    required String username,
    required String password,
    required String dateOfBirth,
    String? gender,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/auth/signup');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'username': username,
            'password': password,
            'date_of_birth': dateOfBirth,
            if (gender != null) 'gender': gender,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 201) {
      return UserOut.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }

    // Extract detail from FastAPI error response
    final body = _tryDecodeBody(response.body);
    final detail = body?['detail'];
    if (detail is String) throw AuthException(detail);
    if (detail is List && detail.isNotEmpty) {
      // Pydantic validation errors come as a list of objects
      final first = detail.first as Map<String, dynamic>;
      throw AuthException(first['msg'] as String? ?? 'Validation error');
    }
    throw AuthException('Signup failed (${response.statusCode})');
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  /// Calls POST /auth/login and persists the JWT in SharedPreferences.
  Future<AuthToken> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/auth/login');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final token =
          AuthToken.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      await _persistToken(token.accessToken);
      return token;
    }

    final body = _tryDecodeBody(response.body);
    final detail = body?['detail'];
    if (detail is String) throw AuthException(detail);
    throw AuthException('Login failed (${response.statusCode})');
  }

  // ── Token helpers ─────────────────────────────────────────────────────────
  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────
  Map<String, dynamic>? _tryDecodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
