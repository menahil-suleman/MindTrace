import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/constants.dart';
import '../../auth/services/auth_service.dart';
import '../../chat/services/chat_service.dart';

class AssessmentException implements Exception {
  final String message;
  const AssessmentException(this.message);
}

// ── Classify response ─────────────────────────────────────────────────────────

class ClassifyResult {
  final List<String> questionnaires;
  final Map<String, String> displayNames;
  final Map<String, String> conditionHints;
  final int totalQuestions;

  const ClassifyResult({
    required this.questionnaires,
    required this.displayNames,
    required this.conditionHints,
    required this.totalQuestions,
  });

  factory ClassifyResult.fromJson(Map<String, dynamic> j) => ClassifyResult(
        questionnaires: List<String>.from(j['questionnaires']),
        displayNames: Map<String, String>.from(j['display_names']),
        conditionHints: Map<String, String>.from(j['condition_hints']),
        totalQuestions: j['total_questions'] as int,
      );
}

// ── Question response ─────────────────────────────────────────────────────────

class AnswerOption {
  final String label;
  final int value;
  const AnswerOption({required this.label, required this.value});

  factory AnswerOption.fromJson(Map<String, dynamic> j) =>
      AnswerOption(label: j['label'], value: j['value']);
}

class QuestionResult {
  /// 'in_progress' | 'complete' | 'crisis'
  final String status;

  // in_progress fields
  final int? questionIndex;
  final String? questionText;
  final List<AnswerOption> options;
  final bool safetyCritical;
  final double progress;
  final int totalQuestions;

  // complete fields
  final int? score;
  final int? maxScore;
  final String? severity;
  final String? label;
  final String? clinicalNote;

  // crisis fields
  final String? crisisMessage;

  const QuestionResult({
    required this.status,
    this.questionIndex,
    this.questionText,
    this.options = const [],
    this.safetyCritical = false,
    this.progress = 0,
    this.totalQuestions = 0,
    this.score,
    this.maxScore,
    this.severity,
    this.label,
    this.clinicalNote,
    this.crisisMessage,
  });

  factory QuestionResult.fromJson(Map<String, dynamic> j) {
    final q = j['question'] as Map<String, dynamic>?;
    return QuestionResult(
      status: j['status'] as String,
      questionIndex: q?['index'] as int?,
      questionText: q?['text'] as String?,
      options: q != null
          ? (q['options'] as List)
              .map((o) => AnswerOption.fromJson(o as Map<String, dynamic>))
              .toList()
          : [],
      safetyCritical: q?['safety_critical'] as bool? ?? false,
      progress: (j['progress'] as num?)?.toDouble() ?? 0,
      totalQuestions: j['total_questions'] as int? ?? 0,
      score: j['score'] as int?,
      maxScore: j['max_score'] as int?,
      severity: j['severity'] as String?,
      label: j['label'] as String?,
      clinicalNote: j['clinical_note'] as String?,
      crisisMessage: j['crisis_message'] as String?,
    );
  }
}

// ── Complete response ─────────────────────────────────────────────────────────

class CompleteResult {
  final String primaryCondition;
  final String severity;
  final String riskLevel;
  final Map<String, dynamic> scores;
  final List<String> recommendations;
  final String framing;
  final String assessmentId;

  const CompleteResult({
    required this.primaryCondition,
    required this.severity,
    required this.riskLevel,
    required this.scores,
    required this.recommendations,
    required this.framing,
    required this.assessmentId,
  });

  factory CompleteResult.fromJson(Map<String, dynamic> j) => CompleteResult(
        primaryCondition: j['primary_condition'] as String,
        severity: j['severity'] as String,
        riskLevel: j['risk_level'] as String,
        scores: Map<String, dynamic>.from(j['scores']),
        recommendations: List<String>.from(j['recommendations']),
        framing: j['framing'] as String,
        assessmentId: j['assessment_id'] as String,
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

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

  /// POST /assessment/classify
  /// Reads the conversation history and decides which questionnaires to run.
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

  /// POST /assessment/questionnaire
  /// Returns the next question OR a scored result when all answers are in.
  Future<QuestionResult> getQuestion({
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
    return QuestionResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// POST /assessment/complete
  /// Sends all scores, saves to DB, returns results summary.
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

  /// POST /assessment/crisis-log
  Future<void> logCrisis({
    required String trigger,
    required String messageHash,
  }) async {
    await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/assessment/crisis-log'),
          headers: await _headers(),
          body: jsonEncode({
            'trigger': trigger,
            'message_hash': messageHash,
          }),
        )
        .timeout(const Duration(seconds: 10));
  }
}
