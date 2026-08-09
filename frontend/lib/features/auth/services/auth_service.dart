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

  // ── Current user ─────────────────────────────────────────────────────────
  /// Calls GET /auth/me using the saved JWT. Used by Sprint-2 screens (e.g.
  /// the Start Screen greeting) that need the logged-in user's name.
  Future<UserOut> getCurrentUser() async {
    final token = await getSavedToken();
    if (token == null) throw const AuthException('You are not logged in.');

    final uri = Uri.parse('${AppConstants.baseUrl}/auth/me');
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return UserOut.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    final body = _tryDecodeBody(response.body);
    final detail = body?['detail'];
    if (detail is String) throw AuthException(detail);
    throw AuthException('Could not load profile (${response.statusCode})');
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

  // ── Forgot password ───────────────────────────────────────────────────────
  /// Calls POST /auth/forgot-password. Always succeeds from the caller's
  /// perspective — the backend returns the same generic message whether the
  /// email is registered or not.
  Future<void> forgotPassword({required String email}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/auth/forgot-password');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) return;

    final body = _tryDecodeBody(response.body);
    final detail = body?['detail'];
    if (detail is String) throw AuthException(detail);
    throw AuthException('Request failed (${response.statusCode})');
  }

  // ── Verify reset code ─────────────────────────────────────────────────────
  /// Calls POST /auth/verify-reset-code.
  /// Returns the short-lived reset token to be passed to [resetPassword].
  Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/auth/verify-reset-code');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['reset_token'] as String;
    }

    final body = _tryDecodeBody(response.body);
    final detail = body?['detail'];
    if (detail is String) throw AuthException(detail);
    throw AuthException('Verification failed (${response.statusCode})');
  }

  // ── Reset password ────────────────────────────────────────────────────────
  /// Calls POST /auth/reset-password with the verified reset token.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/auth/reset-password');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'reset_token': resetToken,
            'new_password': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) return;

    final body = _tryDecodeBody(response.body);
    final detail = body?['detail'];
    if (detail is String) throw AuthException(detail);
    throw AuthException('Password reset failed (${response.statusCode})');
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

  /// Alias for getSavedToken — used by auth_service consumers
  Future<String?> getToken() => getSavedToken();

  /// Returns true if a token is saved — used at startup to skip login screen
  Future<bool> isLoggedIn() async {
    final token = await getSavedToken();
    return token != null && token.isNotEmpty;
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
