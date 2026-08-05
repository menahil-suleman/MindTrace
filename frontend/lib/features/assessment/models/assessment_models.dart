// Models mirroring the Sprint-2 backend schemas exactly
// (see backend/app/routers/chatbot.py and assessment.py).

// ── /chatbot/intake ─────────────────────────────────────────────────────────

class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class IntakeChatResponse {
  final String reply;
  final String status; // "chatting" | "assessment_ready" | "crisis"

  const IntakeChatResponse({required this.reply, required this.status});

  factory IntakeChatResponse.fromJson(Map<String, dynamic> json) =>
      IntakeChatResponse(
        reply: json['reply'] as String,
        status: json['status'] as String? ?? 'chatting',
      );
}

// ── /assessment/classify ────────────────────────────────────────────────────

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

  factory ClassifyResult.fromJson(Map<String, dynamic> json) => ClassifyResult(
        questionnaires: List<String>.from(json['questionnaires'] as List),
        displayNames: Map<String, String>.from(json['display_names'] as Map),
        conditionHints: Map<String, String>.from(json['condition_hints'] as Map),
        totalQuestions: json['total_questions'] as int,
      );
}

// ── /assessment/questionnaire ───────────────────────────────────────────────

class AnswerOption {
  final String label;
  final int value;

  const AnswerOption({required this.label, required this.value});

  factory AnswerOption.fromJson(Map<String, dynamic> json) => AnswerOption(
        label: json['label'] as String,
        value: json['value'] as int,
      );
}

class QuestionOut {
  final int index;
  final String text;
  final List<AnswerOption> options;
  final bool safetyCritical;

  const QuestionOut({
    required this.index,
    required this.text,
    required this.options,
    required this.safetyCritical,
  });

  factory QuestionOut.fromJson(Map<String, dynamic> json) => QuestionOut(
        index: json['index'] as int,
        text: json['text'] as String,
        options: (json['options'] as List)
            .map((o) => AnswerOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        safetyCritical: json['safety_critical'] as bool? ?? false,
      );
}

class QuestionnaireStepResult {
  final String status; // "in_progress" | "complete" | "crisis"
  final QuestionOut? question;
  final double progress;
  final int totalQuestions;
  // complete
  final int? score;
  final int? maxScore;
  final String? severity;
  final String? label;
  final String? clinicalNote;
  // crisis
  final String? crisisMessage;

  const QuestionnaireStepResult({
    required this.status,
    this.question,
    this.progress = 0.0,
    this.totalQuestions = 0,
    this.score,
    this.maxScore,
    this.severity,
    this.label,
    this.clinicalNote,
    this.crisisMessage,
  });

  factory QuestionnaireStepResult.fromJson(Map<String, dynamic> json) =>
      QuestionnaireStepResult(
        status: json['status'] as String,
        question: json['question'] != null
            ? QuestionOut.fromJson(json['question'] as Map<String, dynamic>)
            : null,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        totalQuestions: json['total_questions'] as int? ?? 0,
        score: json['score'] as int?,
        maxScore: json['max_score'] as int?,
        severity: json['severity'] as String?,
        label: json['label'] as String?,
        clinicalNote: json['clinical_note'] as String?,
        crisisMessage: json['crisis_message'] as String?,
      );
}

/// Local (Flutter-side) record of one finished questionnaire —
/// matches the backend's `ScoreEntry` shape for /assessment/complete.
class ScoreEntry {
  final int score;
  final List<int> answers;

  const ScoreEntry({required this.score, required this.answers});

  Map<String, dynamic> toJson() => {'score': score, 'answers': answers};
}

// ── /assessment/complete ────────────────────────────────────────────────────

class InstrumentResult {
  final int score;
  final int maxScore;
  final String severity;
  final String label;
  final String clinicalNote;

  const InstrumentResult({
    required this.score,
    required this.maxScore,
    required this.severity,
    required this.label,
    required this.clinicalNote,
  });

  factory InstrumentResult.fromJson(Map<String, dynamic> json) =>
      InstrumentResult(
        score: json['score'] as int,
        maxScore: json['max_score'] as int,
        severity: json['severity'] as String,
        label: json['label'] as String,
        clinicalNote: json['clinical_note'] as String? ?? '',
      );
}

class CompleteResult {
  final String primaryCondition;
  final String severity;
  final String riskLevel; // "low" | "moderate" | "high"
  final Map<String, InstrumentResult> scores;
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

  factory CompleteResult.fromJson(Map<String, dynamic> json) => CompleteResult(
        primaryCondition: json['primary_condition'] as String,
        severity: json['severity'] as String,
        riskLevel: json['risk_level'] as String,
        scores: (json['scores'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, InstrumentResult.fromJson(v as Map<String, dynamic>)),
        ),
        recommendations: List<String>.from(json['recommendations'] as List),
        framing: json['framing'] as String,
        assessmentId: json['assessment_id'] as String,
      );
}

// ── /assessment/crisis-log ──────────────────────────────────────────────────

class CrisisLogResult {
  final bool logged;
  final String helpline;
  final bool continueAssessment;

  const CrisisLogResult({
    required this.logged,
    required this.helpline,
    required this.continueAssessment,
  });

  factory CrisisLogResult.fromJson(Map<String, dynamic> json) => CrisisLogResult(
        logged: json['logged'] as bool,
        helpline: json['helpline'] as String,
        continueAssessment: json['continue_assessment'] as bool,
      );
}
