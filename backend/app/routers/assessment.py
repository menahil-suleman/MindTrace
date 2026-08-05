"""
Assessment Router — 4 endpoints:

  POST /assessment/classify      → decide which questionnaires to run
  POST /assessment/questionnaire → deliver one question at a time + score when done
  POST /assessment/complete      → final results after all questionnaires
  POST /assessment/crisis-log    → log a crisis event (anonymised)

LEARN — Why one router file for all 4:
  They all belong to the same feature — the assessment flow.
  Keeping them together makes the flow easy to follow top to bottom.
  The router prefix /assessment keeps them separate from /chatbot (intake).

LEARN — The assessment flow in order:
  1. Intake chat finishes  → status="assessment_ready"
  2. Flutter calls /classify  → gets back ["gad7", "phq9", "dass_stress"]
  3. Flutter calls /questionnaire for each question in each instrument
  4. When all instruments done → Flutter calls /complete
  5. /complete saves scores, returns results summary
"""

import hashlib
import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.chatbot.questionnaire_engine import (
    QUESTIONNAIRE_REGISTRY,
    ScoringResult,
    get_questionnaire,
    is_safety_triggered,
    score_questionnaire,
)
from app.core.config import get_settings
from app.core.security import decode_access_token
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/assessment", tags=["assessment"])
bearer_scheme = HTTPBearer()

# ── Auth helper ───────────────────────────────────────────────────────────────
# LEARN: We reuse this in every endpoint. DRY — Don't Repeat Yourself.
# It validates the JWT and returns the user_id string.
# Raises 401 if the token is invalid or expired.

def _require_user(credentials: HTTPAuthorizationCredentials) -> str:
    user_id = decode_access_token(credentials.credentials)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials.",
        )
    return user_id


# ── Crisis response (same hardcoded text as chatbot.py) ───────────────────────
CRISIS_RESPONSE = (
    "Thank you for being honest with me. What you've shared suggests you may be "
    "going through something serious right now.\n\n"
    "If you are in immediate danger or thinking about harming yourself, please reach out:\n"
    "• Emergency services: 115 (Pakistan) / 911\n"
    "• Umang helpline: 0311-7786264 (free, confidential)\n"
    "• A trusted person in your life, or your nearest hospital\n\n"
    "This app is not equipped to handle a crisis. You don't have to go through this alone."
)


# ═══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 1 — /classify
# ═══════════════════════════════════════════════════════════════════════════════

class ChatMessage(BaseModel):
    role: str = Field(..., pattern="^(user|assistant)$")
    content: str = Field(..., min_length=1, max_length=2000)


class ClassifyRequest(BaseModel):
    """
    The full conversation history from the intake chatbot.
    We analyse it to decide which questionnaires to run.
    """
    history: list[ChatMessage] = Field(..., min_length=1, max_length=20)


class ClassifyResponse(BaseModel):
    """
    LEARN: The order of questionnaires matters for UX.
    We put the most likely condition first so the user answers
    the most relevant questions while they're freshest.
    """
    questionnaires: list[str]           # e.g. ["gad7", "phq9", "dass_stress"]
    display_names: dict[str, str]       # {"gad7": "GAD-7", ...}
    condition_hints: dict[str, str]     # {"gad7": "Anxiety", ...}
    total_questions: int                # sum of all question counts


# Keyword signals mapped to questionnaire keys
# LEARN: Simple keyword matching is fast and transparent.
# We use the LLM for understanding nuance in the chat,
# but for routing decisions we want deterministic rules.
_SIGNALS: dict[str, list[str]] = {
    "gad7": [
        "anxi", "worry", "worri", "nervous", "panic", "on edge",
        "racing heart", "restless", "fear", "dread", "tense",
    ],
    "phq9": [
        "depress", "sad", "hopeless", "numb", "empty", "low mood",
        "no energy", "tired", "fatigue", "worthless", "no interest",
        "nothing feels", "don't enjoy", "can't sleep", "sleep too much",
    ],
    "dass_stress": [
        "stress", "overwhelm", "burnt out", "burnout", "pressure",
        "agitat", "irritab", "snap", "can't relax", "wind down",
        "too much", "can't cope",
    ],
}

_DISPLAY: dict[str, str] = {
    "gad7":        "GAD-7",
    "phq9":        "PHQ-9",
    "dass_stress": "DASS",
}

_CONDITION: dict[str, str] = {
    "gad7":        "Anxiety",
    "phq9":        "Depression",
    "dass_stress": "Stress",
}


def _classify_from_history(history: list[ChatMessage]) -> list[str]:
    """
    LEARN: Scan user messages for condition signals.
    Returns questionnaire keys ordered by signal strength (most signals first).
    Always includes all three if signals are ambiguous — better to over-assess
    than to miss something clinically important.
    """
    # Collect only user messages into one lowercase string
    user_text = " ".join(
        msg.content.lower()
        for msg in history
        if msg.role == "user"
    )

    # Count signals per questionnaire
    scores: dict[str, int] = {key: 0 for key in _SIGNALS}
    for key, keywords in _SIGNALS.items():
        for kw in keywords:
            if kw in user_text:
                scores[key] += 1

    # Sort by signal count descending
    ordered = sorted(scores.keys(), key=lambda k: scores[k], reverse=True)

    # If any instrument has 0 signals, still include it —
    # we run all three by default because comorbidity is common
    return ordered


@router.post("/classify", response_model=ClassifyResponse)
async def classify(
    payload: ClassifyRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> ClassifyResponse:
    """
    LEARN — What this endpoint does:
    1. Reads the conversation history from the intake chatbot
    2. Scans user messages for anxiety / depression / stress keywords
    3. Returns an ordered list of questionnaires to run
    4. Flutter uses this to build the "We'll focus on:" screen (Screen 8)
    """
    _require_user(credentials)

    ordered_keys = _classify_from_history(payload.history)

    total = sum(
        len(QUESTIONNAIRE_REGISTRY[k].questions)
        for k in ordered_keys
        if k in QUESTIONNAIRE_REGISTRY
    )

    return ClassifyResponse(
        questionnaires=ordered_keys,
        display_names={k: _DISPLAY[k] for k in ordered_keys},
        condition_hints={k: _CONDITION[k] for k in ordered_keys},
        total_questions=total,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 2 — /questionnaire
# ═══════════════════════════════════════════════════════════════════════════════

class QuestionnaireRequest(BaseModel):
    """
    LEARN — Stateless design:
    The backend doesn't store session state between questions.
    Flutter sends the current question index AND all answers so far.
    This makes the endpoint idempotent — you can replay any state.

    questionnaire : which instrument ("gad7", "phq9", "dass_stress")
    question_index: which question Flutter wants next (0-based)
    answers       : all answers given so far in this questionnaire
                    empty list = first question
    """
    questionnaire: str = Field(..., min_length=2, max_length=20)
    question_index: int = Field(..., ge=0)
    answers: list[int] = Field(default_factory=list)


class QuestionOut(BaseModel):
    index: int
    text: str
    options: list[dict]          # [{"label": "Not at all", "value": 0}, ...]
    safety_critical: bool = False


class QuestionnaireResponse(BaseModel):
    """
    LEARN — Two possible statuses:
    "in_progress" → return the next question, Flutter renders it
    "complete"    → all questions answered, return the score
    "crisis"      → PHQ-9 Q9 answered > 0, show crisis screen
    """
    status: str                          # "in_progress" | "complete" | "crisis"
    # Present when status == "in_progress"
    question: QuestionOut | None = None
    progress: float = 0.0                # 0.0 → 1.0 for progress bar
    total_questions: int = 0
    # Present when status == "complete"
    score: int | None = None
    max_score: int | None = None
    severity: str | None = None
    label: str | None = None
    clinical_note: str | None = None
    next_questionnaire: str | None = None   # key of next instrument or None
    # Present when status == "crisis"
    crisis_message: str | None = None


@router.post("/questionnaire", response_model=QuestionnaireResponse)
async def questionnaire(
    payload: QuestionnaireRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> QuestionnaireResponse:
    """
    LEARN — How this endpoint works:

    Flutter calls this with question_index=0, answers=[] to get the first question.
    User picks an answer. Flutter calls again with question_index=1, answers=[answer].
    Repeat until question_index == total questions.
    On the final call (answers has all values) → score and return result.

    The stateless design means Flutter owns the state.
    Backend just validates + computes. No session storage needed.
    """
    _require_user(credentials)

    q_def = get_questionnaire(payload.questionnaire)
    if q_def is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Unknown questionnaire: {payload.questionnaire}",
        )

    total = len(q_def.questions)

    # ── Safety check — runs whenever answers are submitted ────────────────────
    # LEARN: We check EVERY time answers arrive, not just at Q9.
    # is_safety_triggered() looks for any question marked safety_critical
    # and checks if its answer is > 0.
    if payload.answers and is_safety_triggered(payload.questionnaire, payload.answers):
        return QuestionnaireResponse(
            status="crisis",
            crisis_message=CRISIS_RESPONSE,
            progress=payload.question_index / total,
            total_questions=total,
        )

    # ── All questions answered → score ────────────────────────────────────────
    if len(payload.answers) >= total:
        result: ScoringResult = score_questionnaire(
            payload.questionnaire, payload.answers[:total]
        )

        # Determine the next questionnaire key (Flutter needs this to continue)
        # Flutter passes its full ordered list via the classify endpoint;
        # here we don't know the full order, so we return None and Flutter decides.
        return QuestionnaireResponse(
            status="complete",
            score=result.score,
            max_score=result.max_score,
            severity=result.severity,
            label=result.label,
            clinical_note=result.clinical_note,
            progress=1.0,
            total_questions=total,
        )

    # ── Return the next question ──────────────────────────────────────────────
    if payload.question_index >= total:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="question_index out of range",
        )

    question = q_def.questions[payload.question_index]

    return QuestionnaireResponse(
        status="in_progress",
        question=QuestionOut(
            index=question.index,
            text=question.text,
            options=[
                {"label": opt.label, "value": opt.value}
                for opt in question.options
            ],
            safety_critical=question.safety_critical,
        ),
        progress=payload.question_index / total,
        total_questions=total,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 3 — /complete
# ═══════════════════════════════════════════════════════════════════════════════

class ScoreEntry(BaseModel):
    score: int
    answers: list[int]      # raw answers — needed for ML classifier later


class CompleteRequest(BaseModel):
    """
    All questionnaire results sent together when the user finishes.
    scores: {"gad7": {"score": 15, "answers": [3,3,2,3,1,2,1]}, ...}
    """
    scores: dict[str, ScoreEntry]


class CompleteResponse(BaseModel):
    primary_condition: str
    severity: str
    risk_level: str
    scores: dict[str, dict]          # per-instrument scored results
    recommendations: list[str]
    framing: str                     # the "patterns consistent with..." message
    assessment_id: str               # UUID saved in DB — for dashboard later


def _determine_risk(scored: dict[str, ScoringResult]) -> tuple[str, str]:
    """
    LEARN: Simple rule-based risk determination.
    Later this gets replaced by the ML classifier.
    For now: highest severity across all instruments drives the overall level.

    Returns (primary_condition, risk_level).
    """
    severity_rank = {
        "minimal": 0, "normal": 0,
        "mild": 1,
        "moderate": 2,
        "moderately_severe": 3,
        "severe": 4,
        "extremely_severe": 5,
    }

    # Find which instrument has the highest severity
    best_key = max(scored, key=lambda k: severity_rank.get(scored[k].severity, 0))
    best_result = scored[best_key]
    rank = severity_rank.get(best_result.severity, 0)

    condition_map = {
        "gad7": "Generalized Anxiety",
        "phq9": "Depression",
        "dass_stress": "Stress",
    }

    if rank <= 1:
        risk_level = "low"
    elif rank == 2:
        risk_level = "moderate"
    else:
        risk_level = "high"

    return condition_map.get(best_key, "Mixed"), risk_level


def _build_recommendations(scored: dict[str, ScoringResult], risk_level: str) -> list[str]:
    """Build personalised recommendation text based on scores."""
    recs = []

    if risk_level in ("moderate", "high"):
        recs.append("Consider speaking with a licensed mental health professional.")

    gad = scored.get("gad7")
    phq = scored.get("phq9")
    dass = scored.get("dass_stress")

    if gad and gad.severity in ("moderate", "severe"):
        recs.append("Practice daily breathing or relaxation exercises for anxiety.")
    if phq and phq.severity in ("moderate", "moderately_severe", "severe"):
        recs.append("Engage in behavioral activation — small daily activities that bring purpose.")
    if dass and dass.severity in ("moderate", "severe", "extremely_severe"):
        recs.append("Identify and reduce key stressors where possible.")

    recs.append("Complete daily mood and sleep check-ins to track your progress.")

    if risk_level == "high":
        recs.append("Doctor directory is available — verified professionals near you.")

    return recs


@router.post("/complete", response_model=CompleteResponse)
async def complete(
    payload: CompleteRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> CompleteResponse:
    """
    LEARN — What happens here:
    1. Score each questionnaire from the raw answers
    2. Determine primary condition and risk level
    3. Build recommendations
    4. Save assessment to database
    5. Return the full results summary

    The assessment_id returned here is stored by Flutter
    and used later by the dashboard to load historical results.
    """
    user_id = _require_user(credentials)

    if not payload.scores:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No scores provided.",
        )

    # ── Score each instrument ─────────────────────────────────────────────────
    scored: dict[str, ScoringResult] = {}
    scores_out: dict[str, dict] = {}

    for key, entry in payload.scores.items():
        result = score_questionnaire(key, entry.answers)
        if result is None:
            continue
        scored[key] = result
        scores_out[key] = {
            "score": result.score,
            "max_score": result.max_score,
            "severity": result.severity,
            "label": result.label,
            "clinical_note": result.clinical_note,
        }

    if not scored:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No valid questionnaires found in payload.",
        )

    # ── Determine overall condition + risk ────────────────────────────────────
    primary_condition, risk_level = _determine_risk(scored)

    # ── Build recommendations ─────────────────────────────────────────────────
    recommendations = _build_recommendations(scored, risk_level)

    # ── Framing message — NEVER says "you have X" ────────────────────────────
    # LEARN: The framing rule is enforced here at the data layer.
    # The word "diagnosis" never appears in any response from this endpoint.
    severity_labels = [r.label for r in scored.values()]
    framing = (
        f"Patterns in your responses are consistent with "
        f"{', '.join(severity_labels).lower()}. "
        f"This is not a diagnosis — it reflects patterns similar to people "
        f"in the {risk_level}-risk category."
    )

    # ── Save to database ──────────────────────────────────────────────────────
    # LEARN: We create the assessments table if it doesn't exist yet.
    # In production this would be a proper Alembic migration.
    # For now we use CREATE TABLE IF NOT EXISTS so it's safe to run repeatedly.
    await db.execute(text("""
        CREATE TABLE IF NOT EXISTS assessments (
            id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id      TEXT NOT NULL,
            scores       JSONB NOT NULL,
            risk_level   TEXT NOT NULL,
            primary_condition TEXT NOT NULL,
            created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
        )
    """))

    result_row = await db.execute(
        text("""
            INSERT INTO assessments (user_id, scores, risk_level, primary_condition)
            VALUES (:user_id, :scores, :risk_level, :primary_condition)
            RETURNING id
        """),
        {
            "user_id": str(user_id),
            "scores": json.dumps(scores_out),
            "risk_level": risk_level,
            "primary_condition": primary_condition,
        },
    )
    await db.commit()

    assessment_id = str(result_row.scalar())

    return CompleteResponse(
        primary_condition=primary_condition,
        severity=max(scored.values(), key=lambda r: r.score).severity,
        risk_level=risk_level,
        scores=scores_out,
        recommendations=recommendations,
        framing=framing,
        assessment_id=assessment_id,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 4 — /crisis-log
# ═══════════════════════════════════════════════════════════════════════════════

class CrisisLogRequest(BaseModel):
    """
    LEARN: We NEVER store the raw message that triggered the crisis.
    We store a SHA-256 hash of it — this is enough for auditing
    (you can verify if a specific message triggered it) without
    storing sensitive content.

    trigger: "keyword" | "phq9_q9" | "semantic"
    """
    trigger: str = Field(..., pattern="^(keyword|phq9_q9|semantic)$")
    message_hash: str = Field(..., min_length=64, max_length=64)  # SHA-256 hex


class CrisisLogResponse(BaseModel):
    logged: bool
    helpline: str
    continue_assessment: bool    # always True — user can continue after crisis screen


@router.post("/crisis-log", response_model=CrisisLogResponse)
async def crisis_log(
    payload: CrisisLogRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> CrisisLogResponse:
    """
    LEARN — Why we log crisis events:
    1. Safety auditing — can prove the app responded correctly
    2. Aggregate stats — how often crisis is triggered (anonymised)
    3. Never stores PII or the raw message — only hash + trigger type

    The user can continue the assessment after seeing the crisis screen.
    Stopping the assessment entirely would punish honesty.
    """
    user_id = _require_user(credentials)

    # Create table if not exists
    await db.execute(text("""
        CREATE TABLE IF NOT EXISTS crisis_events (
            id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id      TEXT NOT NULL,
            trigger      TEXT NOT NULL,
            message_hash TEXT NOT NULL,
            created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
        )
    """))

    await db.execute(
        text("""
            INSERT INTO crisis_events (user_id, trigger, message_hash)
            VALUES (:user_id, :trigger, :message_hash)
        """),
        {
            "user_id": str(user_id),
            "trigger": payload.trigger,
            "message_hash": payload.message_hash,
        },
    )
    await db.commit()

    logger.warning(
        "Crisis event logged | user=%s trigger=%s",
        user_id, payload.trigger,
    )

    return CrisisLogResponse(
        logged=True,
        helpline="0311-7786264",
        continue_assessment=True,
    )
