"""
Chatbot 1 — Intake & Triage

WHAT THIS FILE DOES (learn this):
──────────────────────────────────
1. Receives a message from the user + their conversation history
2. Runs a CRISIS CHECK first — hardcoded, never goes to the LLM
3. If safe → sends the conversation to Groq (the LLM) with our system prompt
4. The LLM generates a natural response, constrained by the system prompt
5. Returns the response to Flutter

KEY CONCEPT — Why the crisis check comes BEFORE the LLM:
   The LLM might respond empathetically but inconsistently to crisis signals.
   We never let the LLM decide what to do in a crisis. We intercept it first,
   return a hardcoded string, and stop. No LLM involved. No exceptions.

KEY CONCEPT — What the system prompt does:
   The system prompt is a set of instructions the LLM receives before the
   conversation starts. The user never sees it. It defines the bot's role,
   what it can and cannot do, and its personality. It's the "rules" layer.

KEY CONCEPT — Message history:
   LLMs have no memory between API calls. Every call is stateless.
   To give the bot "memory", we send the entire conversation history
   with every request. The LLM reads all of it and generates the next reply.
   This is why the context window (max tokens) matters — long conversations
   eventually hit the limit.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import decode_access_token
from app.db.session import get_db
from app.rag.engine import format_retrieved_chunks, retrieve
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

router = APIRouter(prefix="/chatbot", tags=["chatbot"])
bearer_scheme = HTTPBearer()


# ── Crisis detection ──────────────────────────────────────────────────────────
# LEARN: This is the "keyword layer" of the crisis classifier.
# It's fast, cheap, and catches obvious cases before we even call the LLM.
# We check every single user message — no exceptions.
# In production you'd also add a semantic layer (embedding similarity)
# but keyword matching is the non-negotiable safety baseline.

CRISIS_KEYWORDS: set[str] = {
    # Self-harm
    "kill myself", "killing myself", "end my life", "end it all",
    "want to die", "better off dead", "take my own life",
    "hurt myself", "cutting myself", "self harm", "self-harm",
    # Suicide
    "suicide", "suicidal", "hang myself", "overdose",
    # Harm to others
    "hurt someone", "kill someone", "harm others",
}

# LEARN: This is the hardcoded crisis response.
# It NEVER changes. The LLM NEVER generates this. It's a fixed string.
# Why? Because when someone is in crisis, consistency and clarity matter
# more than empathy. An LLM might say something well-meaning but wrong.
CRISIS_RESPONSE = """Thank you for being honest with me. What you've shared suggests \
you may be going through something serious right now, and I want to make sure you get \
real support, not just an app response.

If you are in immediate danger or thinking about harming yourself, please reach out now:
• Emergency services: 115 (Pakistan) / 911
• Umang helpline: 0311-7786264 (free, confidential)
• A trusted person in your life, or your nearest hospital emergency department

This app is not equipped to handle a crisis, and a real person can help in a way I can't. \
You don't have to go through this alone."""


def _is_crisis(text: str) -> bool:
    """
    LEARN: Simple keyword check.
    We lowercase the text and check if any crisis phrase is a substring.
    This is O(n*m) but messages are short so it's fast enough.
    In production: also run a semantic similarity check using embeddings.
    """
    text_lower = text.lower()
    return any(keyword in text_lower for keyword in CRISIS_KEYWORDS)


# ── System prompt ─────────────────────────────────────────────────────────────
# LEARN: The system prompt is the most important part of the chatbot.
# It runs BEFORE every conversation. The user never sees it.
# It defines:
#   - WHO the bot is (Mira, clinical intake assistant)
#   - WHAT it does (triage conversation only)
#   - WHAT it never does (therapy, diagnosis, advice)
#   - HOW many turns to take before handing off
#   - EXACTLY what to say during the handoff
#
# The tighter and more specific this prompt, the more predictable the bot.
# Vague prompts = unpredictable, potentially dangerous responses.

SYSTEM_PROMPT = """You are Mira, a clinical intake assistant for MindTrace, a mental health \
monitoring platform. You are NOT a therapist, counsellor, or doctor.

YOUR ONLY JOB:
Have a brief, warm, professional conversation to understand what the user is going \
through — then hand them off to a structured assessment. Nothing more.

STRICT RULES — violating these is not allowed under any circumstances:
1. Never say "you have [condition]" or "this sounds like [diagnosis]" or imply a diagnosis
2. Never give therapy, coping strategies, or mental health advice
3. Never ask more than one question per response
4. Never continue the conversation after delivering the handoff message
5. Never make up or paraphrase questionnaire questions — you don't administer them
6. Never promise confidentiality, specific outcomes, or what happens next
7. Maximum 4 conversation turns before transitioning to assessment

PERSONALITY:
Warm but clinical. Calm. Professional. Like a skilled intake nurse on their first \
meeting with a patient — not a friend, not a therapist. Brief responses. No filler phrases \
like "I hear you" repeated constantly. No excessive validation.

CONVERSATION FLOW:
- Turn 1: Ask the opening question exactly as written below
- Turn 2-4: ONE targeted follow-up question based on what they share
- Turn 5 (or earlier if you have enough): Deliver the handoff message exactly as written

OPENING QUESTION (use this exactly on turn 1):
"Hi, I'm Mira. Before we get started, I'd like to understand a bit about what's been \
going on for you lately. Can you tell me — in your own words — what's brought you here today?"

HANDOFF MESSAGE (use this exactly when ready to transition):
"Thank you for sharing that with me. To understand your situation more precisely, I'd like \
to ask you a short series of structured questions. There are no right or wrong answers — \
just answer as honestly as you can."

After delivering the handoff message, set your next response status to "assessment_ready" \
by ending your message with the exact token: [ASSESSMENT_READY]

IMPORTANT REMINDER:
You are the intake layer only. The real analysis happens after you. \
Your job is to make the user feel heard enough to proceed — not to solve their problem."""


# ── Request / Response schemas ────────────────────────────────────────────────
# LEARN: Pydantic schemas define the shape of data coming in and going out.
# FastAPI validates every incoming request against these automatically.
# If the data doesn't match, it returns a 422 error before your code even runs.

class ChatMessage(BaseModel):
    """A single message in the conversation."""
    # LEARN: 'role' is one of "user" or "assistant"
    # This matches the OpenAI/Groq message format exactly
    role: str = Field(..., pattern="^(user|assistant)$")
    content: str = Field(..., min_length=1, max_length=2000)


class ChatRequest(BaseModel):
    """
    What Flutter sends to this endpoint.
    
    LEARN: We send the ENTIRE message history every time — not just the latest message.
    The LLM has no memory between calls. Sending history gives it context.
    history = all previous messages
    message = the new message the user just typed
    """
    message: str = Field(..., min_length=1, max_length=2000)
    history: list[ChatMessage] = Field(default_factory=list, max_length=20)


class ChatResponse(BaseModel):
    """What this endpoint sends back to Flutter."""
    reply: str
    # LEARN: We use a status flag so Flutter knows what phase we're in
    # "chatting"         → still in intake conversation
    # "assessment_ready" → chatbot is done, time to start questionnaires
    # "crisis"           → crisis detected, show emergency resources
    status: str = Field(default="chatting")


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post("/intake", response_model=ChatResponse)
async def intake_chat(
    payload: ChatRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> ChatResponse:
    """
    LEARN — How this endpoint works step by step:

    1. Validate the JWT token (user must be logged in)
    2. Run crisis check on the user's message
    3. If crisis → return hardcoded response immediately, never call LLM
    4. Build the message list: [system_prompt] + [history] + [new_message]
    5. Send to Groq API → get response
    6. Check if response contains [ASSESSMENT_READY] token
    7. Return the response + status to Flutter

    LEARN — Why we require authentication (JWT):
    We need to know WHO is sending the message so we can eventually
    store conversation context per user. Also prevents anonymous abuse.
    """
    settings = get_settings()

    # ── Step 1: validate JWT ──────────────────────────────────────────────────
    # LEARN: decode_access_token extracts the user_id from the JWT.
    # If the token is expired, tampered with, or missing — it returns None.
    user_id = decode_access_token(credentials.credentials)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials.",
        )

    # ── Step 2: crisis check ──────────────────────────────────────────────────
    # LEARN: This runs BEFORE anything else. Before the LLM. Always.
    # If crisis detected → return immediately. LLM is never called.
    if _is_crisis(payload.message):
        return ChatResponse(reply=CRISIS_RESPONSE, status="crisis")

    # ── Step 3: check LLM is configured ──────────────────────────────────────
    if not settings.groq_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Chatbot is not configured. Add GROQ_API_KEY to .env",
        )

    # ── Step 4: build the message list ───────────────────────────────────────
    # LEARN: RAG injection happens here.
    # We retrieve the most relevant clinical chunks for the user's message,
    # then append them to the system prompt BEFORE sending to the LLM.
    # The LLM now has accurate clinical content to reference — not its memory.
    retrieved_chunks = await retrieve(db, payload.message, top_n=4)
    rag_context = format_retrieved_chunks(retrieved_chunks)

    # Build the enriched system prompt
    enriched_system = SYSTEM_PROMPT
    if rag_context:
        enriched_system = f"{SYSTEM_PROMPT}\n\n{rag_context}"

    messages = [{"role": "system", "content": enriched_system}]

    for msg in payload.history:
        # Also run crisis check on history — in case we missed something
        if msg.role == "user" and _is_crisis(msg.content):
            return ChatResponse(reply=CRISIS_RESPONSE, status="crisis")
        messages.append({"role": msg.role, "content": msg.content})

    messages.append({"role": "user", "content": payload.message})

    # ── Step 5: call Groq ─────────────────────────────────────────────────────
    # LEARN: The Groq SDK is a thin wrapper around an HTTP call.
    # client.chat.completions.create() sends our messages to the LLM
    # and returns the generated response.
    # temperature=0.4 means "fairly consistent" — lower = more predictable,
    # higher = more creative. For a clinical intake bot, we want consistency.
    # max_tokens=400 limits the response length — prevents walls of text.
    try:
        from groq import Groq  # imported here to avoid startup error if not installed

        client = Groq(api_key=settings.groq_api_key)
        completion = client.chat.completions.create(
            model=settings.groq_model,
            messages=messages,  # type: ignore[arg-type]
            temperature=0.4,
            max_tokens=400,
        )
        reply: str = completion.choices[0].message.content or ""

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"LLM call failed: {str(e)}",
        )

    # ── Step 6: detect handoff ────────────────────────────────────────────────
    # LEARN: We look for our sentinel token [ASSESSMENT_READY] in the reply.
    # If found → strip it out before sending to Flutter, set status flag.
    # Flutter checks the status field and navigates to the questionnaire screen.
    chat_status = "chatting"
    if "[ASSESSMENT_READY]" in reply:
        reply = reply.replace("[ASSESSMENT_READY]", "").strip()
        chat_status = "assessment_ready"

    return ChatResponse(reply=reply, status=chat_status)
