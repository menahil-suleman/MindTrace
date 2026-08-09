import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/constants.dart';
import '../../auth/services/auth_service.dart';
import '../models/assessment_models.dart';

// Re-export all models so files importing this service get everything they need
export '../models/assessment_models.dart';

class AssessmentException implements Exception {
  final String message;
  const AssessmentException(this.message);

  @override
  String toString() => message;
}

class AssessmentService {
  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getSavedToken();
    if (token == null) throw const AssessmentException('Not authenticated.');
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

  void _checkError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = _tryDecode(response.body);
    final detail = body?['detail'];
    if (detail is String) throw AssessmentException(detail);
    throw AssessmentException('Request failed (${response.statusCode})');
  }

  // ── /chatbot/intake ──────────────────────────────────────────────────────
  Future<IntakeChatResponse> sendIntakeMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/chatbot/intake'),
          headers: await _headers(),
          body: jsonEncode({
            'message': message,
            'history': history.map((m) => m.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));
    _checkError(response);
    return IntakeChatResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── /assessment/classify ─────────────────────────────────────────────────
  Future<ClassifyResult> classify(List<ChatMessage> history) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/assessment/classify'),
          headers: await _headers(),
          body: jsonEncode({
            'history': history.map((m) => m.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    _checkError(response);
    return ClassifyResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── /assessment/questionnaire ─────────────────────────────────────────────
  /// Primary method name used by the teammate's screens
  Future<QuestionnaireStepResult> fetchQuestionnaireStep({
    required String questionnaire,
    required int questionIndex,
    required List<int> answers,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/assessment/questionnaire'),
          headers: await _headers(),
          body: jsonEncode({
            'questionnaire': questionnaire,
            'question_index': questionIndex,
            'answers': answers,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _checkError(response);
    return QuestionnaireStepResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Alias used by our questionnaire_screen.dart
  Future<QuestionnaireStepResult> getQuestion({
    required String questionnaire,
    required int questionIndex,
    required List<int> answers,
  }) => fetchQuestionnaireStep(
        questionnaire: questionnaire,
        questionIndex: questionIndex,
        answers: answers,
      );

  // ── /assessment/complete ──────────────────────────────────────────────────
  /// Primary method name used by the teammate's screens
  Future<CompleteResult> completeAssessment(
      Map<String, ScoreEntry> scores) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/assessment/complete'),
          headers: await _headers(),
          body: jsonEncode({
            'scores': scores.map((k, v) => MapEntry(k, v.toJson())),
          }),
        )
        .timeout(const Duration(seconds: 15));
    _checkError(response);
    return CompleteResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Alias used by our questionnaire_screen.dart (takes raw Map)
  Future<CompleteResult> complete(
      Map<String, Map<String, dynamic>> scores) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/assessment/complete'),
          headers: await _headers(),
          body: jsonEncode({'scores': scores}),
        )
        .timeout(const Duration(seconds: 15));
    _checkError(response);
    return CompleteResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── /assessment/crisis-log ────────────────────────────────────────────────
  Future<CrisisLogResult> logCrisis({
    required String trigger,
    String? messageHash,
    String? triggerMessage,
  }) async {
    // Accept either a pre-hashed value or a raw message to hash here
    final hash = messageHash ??
        triggerMessage.hashCode.toRadixString(16).padLeft(64, '0');
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/assessment/crisis-log'),
          headers: await _headers(),
          body: jsonEncode({
            'trigger': trigger,
            'message_hash': hash,
          }),
        )
        .timeout(const Duration(seconds: 10));
    _checkError(response);
    return CrisisLogResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
}
