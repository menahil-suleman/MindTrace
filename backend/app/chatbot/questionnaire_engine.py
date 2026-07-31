"""
Questionnaire Engine

LEARN — What this file is:
───────────────────────────
This is the single source of truth for all questionnaire content and scoring.
It knows:
  - Every question in GAD-7, PHQ-9, DASS-21
  - The exact answer options and their numeric values
  - How to score a completed set of answers
  - What severity label a score maps to
  - Which question is a safety-critical question (PHQ-9 Q9)

WHY this is a separate file and not inside the router:
  The router handles HTTP — request in, response out.
  The engine handles clinical logic — questions, scoring, thresholds.
  Keeping them separate means you can unit test the scoring logic
  without running a web server.

LEARN — The scoring rules:
  GAD-7:  0-4 minimal | 5-9 mild | 10-14 moderate | 15-21 severe
  PHQ-9:  0-4 minimal | 5-9 mild | 10-14 moderate | 15-19 mod-severe | 20-27 severe
  DASS:   multiply subscale total x2 for DASS-42 equivalent
          stress:     0-14 normal | 15-18 mild | 19-25 moderate | 26-33 severe
          depression: 0-9 normal  | 10-13 mild | 14-20 moderate | 21-27 severe
          anxiety:    0-7 normal  | 8-9 mild   | 10-14 moderate | 15-19 severe
"""

from dataclasses import dataclass, field
from enum import Enum


# ── Answer option ─────────────────────────────────────────────────────────────

@dataclass
class AnswerOption:
    label: str    # "Not at all"
    value: int    # 0


# ── Question ──────────────────────────────────────────────────────────────────

@dataclass
class Question:
    index: int                          # 0-based position in the questionnaire
    text: str                           # exact validated wording
    options: list[AnswerOption]
    safety_critical: bool = False       # True only for PHQ-9 Q9


# ── Questionnaire definition ──────────────────────────────────────────────────

@dataclass
class QuestionnaireDefinition:
    key: str                            # 'gad7' | 'phq9' | 'dass_stress' etc
    display_name: str                   # 'GAD-7'
    full_name: str                      # 'Generalized Anxiety Disorder Scale'
    time_window: str                    # 'Over the last 2 weeks'
    questions: list[Question]
    score_fn: object                    # callable — takes list[int] → ScoringResult


# ── Scoring result ────────────────────────────────────────────────────────────

@dataclass
class ScoringResult:
    score: int
    severity: str          # 'minimal' | 'mild' | 'moderate' | 'severe' etc
    label: str             # human readable: "Mild anxiety"
    max_score: int
    clinical_note: str     # one line used in the results screen


# ── Standard answer options ───────────────────────────────────────────────────
# LEARN: GAD-7 and PHQ-9 use the same 4-point frequency scale.
# We define them once and reuse.

FREQUENCY_OPTIONS = [
    AnswerOption("Not at all", 0),
    AnswerOption("Several days", 1),
    AnswerOption("More than half the days", 2),
    AnswerOption("Nearly every day", 3),
]

# DASS uses a different scale — applied to me over the past week
DASS_OPTIONS = [
    AnswerOption("Did not apply to me at all", 0),
    AnswerOption("Applied to me to some degree", 1),
    AnswerOption("Applied to me to a considerable degree", 2),
    AnswerOption("Applied to me very much or most of the time", 3),
]


# ── Scoring functions ─────────────────────────────────────────────────────────

def _score_gad7(answers: list[int]) -> ScoringResult:
    score = sum(answers)
    if score <= 4:
        return ScoringResult(score, "minimal", "Minimal anxiety", 21,
                             "Your responses suggest minimal anxiety at this time.")
    elif score <= 9:
        return ScoringResult(score, "mild", "Mild anxiety", 21,
                             "Your responses are consistent with mild anxiety.")
    elif score <= 14:
        return ScoringResult(score, "moderate", "Moderate anxiety", 21,
                             "Your responses are consistent with moderate anxiety. "
                             "Consider speaking with a healthcare provider.")
    else:
        return ScoringResult(score, "severe", "Severe anxiety", 21,
                             "Your responses are consistent with severe anxiety. "
                             "Professional evaluation is recommended.")


def _score_phq9(answers: list[int]) -> ScoringResult:
    score = sum(answers)
    if score <= 4:
        return ScoringResult(score, "minimal", "Minimal depression", 27,
                             "Your responses suggest minimal depression symptoms.")
    elif score <= 9:
        return ScoringResult(score, "mild", "Mild depression", 27,
                             "Your responses are consistent with mild depression symptoms.")
    elif score <= 14:
        return ScoringResult(score, "moderate", "Moderate depression", 27,
                             "Your responses are consistent with moderate depression. "
                             "Consider professional consultation.")
    elif score <= 19:
        return ScoringResult(score, "moderately_severe", "Moderately severe depression", 27,
                             "Your responses are consistent with moderately severe depression. "
                             "Professional evaluation is strongly recommended.")
    else:
        return ScoringResult(score, "severe", "Severe depression", 27,
                             "Your responses are consistent with severe depression. "
                             "Prompt professional evaluation is strongly recommended.")


def _score_dass_stress(answers: list[int]) -> ScoringResult:
    # Multiply by 2 for DASS-42 equivalent
    score = sum(answers)
    dass42 = score * 2
    if dass42 <= 14:
        return ScoringResult(score, "normal", "Normal stress", 21,
                             "Your stress levels appear to be within normal range.")
    elif dass42 <= 18:
        return ScoringResult(score, "mild", "Mild stress", 21,
                             "Your responses are consistent with mild stress.")
    elif dass42 <= 25:
        return ScoringResult(score, "moderate", "Moderate stress", 21,
                             "Your responses are consistent with moderate stress.")
    elif dass42 <= 33:
        return ScoringResult(score, "severe", "Severe stress", 21,
                             "Your responses are consistent with severe stress.")
    else:
        return ScoringResult(score, "extremely_severe", "Extremely severe stress", 21,
                             "Your responses indicate extremely severe stress levels.")


# ── GAD-7 questions ───────────────────────────────────────────────────────────

GAD7 = QuestionnaireDefinition(
    key="gad7",
    display_name="GAD-7",
    full_name="Generalized Anxiety Disorder Scale",
    time_window="Over the last 2 weeks, how often have you been bothered by the following?",
    score_fn=_score_gad7,
    questions=[
        Question(0,
                 "Feeling nervous, anxious, or on edge",
                 FREQUENCY_OPTIONS),
        Question(1,
                 "Not being able to stop or control worrying",
                 FREQUENCY_OPTIONS),
        Question(2,
                 "Worrying too much about different things",
                 FREQUENCY_OPTIONS),
        Question(3,
                 "Trouble relaxing",
                 FREQUENCY_OPTIONS),
        Question(4,
                 "Being so restless that it is hard to sit still",
                 FREQUENCY_OPTIONS),
        Question(5,
                 "Becoming easily annoyed or irritable",
                 FREQUENCY_OPTIONS),
        Question(6,
                 "Feeling afraid as if something awful might happen",
                 FREQUENCY_OPTIONS),
    ],
)

# ── PHQ-9 questions ───────────────────────────────────────────────────────────

PHQ9 = QuestionnaireDefinition(
    key="phq9",
    display_name="PHQ-9",
    full_name="Patient Health Questionnaire",
    time_window="Over the last 2 weeks, how often have you been bothered by the following?",
    score_fn=_score_phq9,
    questions=[
        Question(0,
                 "Little interest or pleasure in doing things",
                 FREQUENCY_OPTIONS),
        Question(1,
                 "Feeling down, depressed, or hopeless",
                 FREQUENCY_OPTIONS),
        Question(2,
                 "Trouble falling or staying asleep, or sleeping too much",
                 FREQUENCY_OPTIONS),
        Question(3,
                 "Feeling tired or having little energy",
                 FREQUENCY_OPTIONS),
        Question(4,
                 "Poor appetite or overeating",
                 FREQUENCY_OPTIONS),
        Question(5,
                 "Feeling bad about yourself — or that you are a failure or "
                 "have let yourself or your family down",
                 FREQUENCY_OPTIONS),
        Question(6,
                 "Trouble concentrating on things, such as reading or watching television",
                 FREQUENCY_OPTIONS),
        Question(7,
                 "Moving or speaking so slowly that other people could have noticed. "
                 "Or being so fidgety or restless that you have been moving around "
                 "a lot more than usual",
                 FREQUENCY_OPTIONS),
        Question(8,
                 "Thoughts that you would be better off dead, or thoughts of "
                 "hurting yourself in some way",
                 FREQUENCY_OPTIONS,
                 safety_critical=True),   # ← PHQ-9 Q9 — hardcoded crisis if > 0
    ],
)

# ── DASS-21 Stress subscale ───────────────────────────────────────────────────

DASS_STRESS = QuestionnaireDefinition(
    key="dass_stress",
    display_name="DASS",
    full_name="Depression Anxiety Stress Scale — Stress",
    time_window="Please rate how much each statement applied to you over the past week.",
    score_fn=_score_dass_stress,
    questions=[
        Question(0, "I found it hard to wind down", DASS_OPTIONS),
        Question(1, "I tended to over-react to situations", DASS_OPTIONS),
        Question(2, "I felt that I was using a lot of nervous energy", DASS_OPTIONS),
        Question(3, "I found myself getting agitated", DASS_OPTIONS),
        Question(4, "I found it difficult to relax", DASS_OPTIONS),
        Question(5,
                 "I was intolerant of anything that kept me from "
                 "getting on with what I was doing",
                 DASS_OPTIONS),
        Question(6, "I felt that I was rather touchy", DASS_OPTIONS),
    ],
)

# ── Registry ──────────────────────────────────────────────────────────────────
# LEARN: A registry is just a dict that maps a string key to an object.
# Instead of a long if/elif chain, you do: REGISTRY[key]
# This is a common pattern — easy to extend (just add a new entry).

QUESTIONNAIRE_REGISTRY: dict[str, QuestionnaireDefinition] = {
    "gad7":       GAD7,
    "phq9":       PHQ9,
    "dass_stress": DASS_STRESS,
}


def get_questionnaire(key: str) -> QuestionnaireDefinition | None:
    return QUESTIONNAIRE_REGISTRY.get(key)


def score_questionnaire(key: str, answers: list[int]) -> ScoringResult | None:
    """
    Score a completed questionnaire.
    answers: list of integer values, one per question, in order.
    Returns None if the key is unknown.
    """
    q = get_questionnaire(key)
    if q is None:
        return None
    return q.score_fn(answers)


def is_safety_triggered(key: str, answers: list[int]) -> bool:
    """
    LEARN: The safety check happens AFTER the user answers each question.
    For PHQ-9: if Q9 (index 8) is answered with anything > 0 → crisis.
    We check this here so the router can intercept before proceeding.
    """
    q = get_questionnaire(key)
    if q is None:
        return False
    for question in q.questions:
        if question.safety_critical:
            idx = question.index
            if idx < len(answers) and answers[idx] > 0:
                return True
    return False
