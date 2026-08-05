import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants.dart';
import '../../auth/services/auth_service.dart';
import '../models/assessment_models.dart';

/// Exception carrying the human-readable server message.
class AssessmentException implements Exception {
  final String message;
  const AssessmentException(this.message);

  @override
  String toString() => message;
}

/// Talks to the four Sprint-2 endpoints:
/// POST /chatbot/intake, /assessment/classify, /assessment/questionnaire,
/// /assessment/complete, /assessment/crisis-log.
///
/// Every call is JWT-authenticated using the token AuthService already
/// persisted at login (same pattern as AuthService itself).
class AssessmentService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getSavedToken();
    if (token == null) {
      throw const AssessmentException('You are not logged in.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Never _throwFromResponse(http.Response response) {
    final body = _tryDecode(response.body);
    final detail = body?['detail'];
    if (detail is String) throw AssessmentException(detail);
    throw AssessmentException('Request failed (${response.statusCode})');
  }

  // ── POST /chatbot/intake ────────────────────────────────────────────────
  Future<IntakeChatResponse> sendIntakeMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConstants.baseUrl}/chatbot/intake');

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'message': message,
        'history': history.map((m) => m.toJson()).toList(),
      }),
    );

    if (response.statusCode == 200) {
      return IntakeChatResponse.fromJson(jsonDecode(response.body));
    }
    _throwFromResponse(response);
  }

  // ── POST /assessment/classify ───────────────────────────────────────────
  Future<ClassifyResult> classify(List<ChatMessage> history) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConstants.baseUrl}/assessment/classify');

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'history': history.map((m) => m.toJson()).toList()}),
    );

    if (response.statusCode == 200) {
      return ClassifyResult.fromJson(jsonDecode(response.body));
    }
    _throwFromResponse(response);
  }

  // ── POST /assessment/questionnaire ──────────────────────────────────────
  /// Fetches the next question, or the final score once [answers] covers
  /// every question in [questionnaire]. Stateless — caller (Flutter) owns
  /// the running answer list, matching the backend's design.
  Future<QuestionnaireStepResult> fetchQuestionnaireStep({
    required String questionnaire,
    required int questionIndex,
    required List<int> answers,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConstants.baseUrl}/assessment/questionnaire');

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'questionnaire': questionnaire,
        'question_index': questionIndex,
        'answers': answers,
      }),
    );

    if (response.statusCode == 200) {
      return QuestionnaireStepResult.fromJson(jsonDecode(response.body));
    }
    _throwFromResponse(response);
  }

  // ── POST /assessment/complete ───────────────────────────────────────────
  Future<CompleteResult> completeAssessment(
    Map<String, ScoreEntry> scores,
  ) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConstants.baseUrl}/assessment/complete');

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'scores': scores.map((k, v) => MapEntry(k, v.toJson())),
      }),
    );

    if (response.statusCode == 200) {
      return CompleteResult.fromJson(jsonDecode(response.body));
    }
    _throwFromResponse(response);
  }

  // ── POST /assessment/crisis-log ─────────────────────────────────────────
  /// [triggerMessage] is hashed locally (SHA-256) before it ever leaves the
  /// device — the backend only ever sees the hash, never the raw text.
  Future<CrisisLogResult> logCrisis({
    required String trigger, // "keyword" | "phq9_q9" | "semantic"
    required String triggerMessage,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConstants.baseUrl}/assessment/crisis-log');
    final messageHash = sha256.convert(utf8.encode(triggerMessage)).toString();

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'trigger': trigger, 'message_hash': messageHash}),
    );

    if (response.statusCode == 200) {
      return CrisisLogResult.fromJson(jsonDecode(response.body));
    }
    _throwFromResponse(response);
  }
}
