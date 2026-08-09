# MindTrace — Project Progress Log

A complete record of everything built so far, step by step.

---

## What is MindTrace?

MindTrace is a clinical mental health screening and monitoring app.
- **Backend**: Python (FastAPI) + PostgreSQL (Docker)
- **Frontend**: Flutter (targets Android, iOS, Web, Windows)
- **ML**: Planned ML layer (requirements file exists)

---

## Project Structure

```
MindTrace/
├── backend/               # FastAPI Python backend
│   ├── app/
│   │   ├── core/          # Config, security (JWT), settings, email (Brevo)
│   │   ├── db/            # Database session (SQLAlchemy async)
│   │   ├── models/        # SQLAlchemy ORM models (User, PasswordResetCode)
│   │   ├── routers/       # API route handlers (auth, password_reset, chatbot, assessment)
│   │   ├── schemas/       # Pydantic request/response schemas
│   │   ├── chatbot/       # Intake chatbot logic + questionnaire_engine.py (GAD-7/PHQ-9/DASS scoring)
│   │   ├── rag/           # Hybrid (semantic + BM25) retrieval over clinical knowledge base
│   │   ├── crisis/        # Hardcoded crisis response handler
│   │   └── main.py        # FastAPI app entry point + CORS
│   ├── alembic/           # Database migrations
│   ├── tests/             # Backend tests (pytest)
│   ├── .env               # Environment variables (not committed)
│   ├── .env.example       # Template for .env
│   ├── requirements.txt   # Python dependencies
│   └── pytest.ini         # Test config
│
├── frontend/              # Flutter app
│   ├── lib/
│   │   ├── main.dart      # Entry point → launches SignupScreen
│   │   ├── core/
│   │   │   ├── theme.dart      # All colors, fonts, input styles
│   │   │   └── constants.dart  # baseUrl, SharedPrefs keys
│   │   └── features/
│   │       ├── auth/
│   │       │   ├── models/
│   │       │   │   └── user_model.dart     # UserOut (now includes username/gender), AuthToken
│   │       │   ├── services/
│   │       │   │   └── auth_service.dart   # signup(), login(), getCurrentUser(), token storage
│   │       │   ├── widgets/
│   │       │   │   ├── auth_toggle.dart         # Login/Sign Up sliding toggle
│   │       │   │   └── clinical_text_field.dart # Reusable pill-shaped input
│   │       │   └── screens/
│   │       │       ├── signup_screen.dart  # Full signup form
│   │       │       └── login_screen.dart   # Login form → navigates to StartScreen
│   │       └── assessment/            # Sprint 2 (Feature 2 + 3)
│   │           ├── models/
│   │           │   └── assessment_models.dart   # Mirrors every chatbot/assessment endpoint schema
│   │           ├── services/
│   │           │   └── assessment_service.dart  # intake, classify, questionnaire, complete, crisis-log
│   │           ├── widgets/
│   │           │   ├── assessment_header.dart   # "Step X of Y" + progress bar, used on every screen
│   │           │   ├── chat_bubble.dart          # Bot/user chat bubbles + typing indicator
│   │           │   └── option_tiles.dart         # Radio answer tile + quick-reply chip
│   │           └── screens/
│   │               ├── start_screen.dart              # Welcome screen, entry point into Sprint 2
│   │               ├── chatbot_intake_screen.dart      # Freeform chat → POST /chatbot/intake
│   │               ├── focus_areas_screen.dart         # POST /assessment/classify results
│   │               ├── questionnaire_flow_screen.dart  # POST /assessment/questionnaire, one Q at a time
│   │               ├── crisis_screen.dart              # Dedicated crisis screen + /assessment/crisis-log
│   │               └── results_screen.dart             # POST /assessment/complete summary + gauge
│   ├── assets/images/logo.png   # MindTrace logo
│   ├── android/                 # Android platform files
│   ├── windows/                 # Windows platform files
│   ├── web/                     # Web platform files
│   └── pubspec.yaml             # Flutter dependencies (added: crypto, url_launcher)
│
├── ml/                    # ML layer (planned)
│   └── requirements.txt
│
├── docs/
│   ├── SPRINT_LOG.md      # Sprint history
│   └── PROJECT_PROGRESS.md  ← this file
│
├── docker-compose.yml     # Starts PostgreSQL container
└── .github/workflows/ci.yml  # GitHub Actions CI
```

---

## Backend — What's Built

### 1. FastAPI App (`backend/app/main.py`)
- FastAPI app with title "MindTrace API"
- CORS middleware added — allows requests from `localhost:*` (needed for Flutter web/desktop dev)
- Health check endpoint: `GET /health` → returns `{"status": "ok"}`

### 2. Configuration (`backend/app/core/config.py`)
- Reads settings from `.env` file using Pydantic BaseSettings
- Settings: `DATABASE_URL`, `JWT_SECRET_KEY`, `JWT_ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES`, `MIN_SIGNUP_AGE`
- Forgot-password settings: `BREVO_API_KEY`, `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME`, `RESET_CODE_EXPIRE_MINUTES` (10), `RESET_CODE_RESEND_COOLDOWN_SECONDS` (45), `RESET_CODE_MAX_ATTEMPTS` (5), `RESET_TOKEN_EXPIRE_MINUTES` (10)

### 3. Database (`backend/app/db/session.py`)
- Async SQLAlchemy engine + session factory
- Connects to PostgreSQL via `DATABASE_URL` from `.env`
- Database: `appdb`, user: `appuser`, password: `devpassword` (matches docker-compose)

### 4. User Model (`backend/app/models/user.py`)
- SQLAlchemy ORM model for `users` table
- Fields: `id` (UUID), `email` (unique), `username` (unique), `hashed_password`, `date_of_birth`, `gender` (optional), `is_active`, `created_at`

### 4a. Password Reset Code Model (`backend/app/models/password_reset_code.py`)
- SQLAlchemy ORM model for `password_reset_codes` table — one row per forgot-password OTP attempt
- Fields: `id`, `user_id` (FK to `users`, cascade delete), `code_hash` (bcrypt — the raw 6-digit code is never stored), `expires_at`, `attempt_count`, `verified_at`, `consumed_at`, `created_at`
- `verified_at` prevents a code being checked twice; `consumed_at` prevents the reset token it produces from being replayed

### 5. Schemas (`backend/app/schemas/user.py`)
- `UserCreate`: email, username, password, date_of_birth, gender (optional — input for signup)
  - `gender` is validated against a fixed set: `male`, `female`, `non-binary`, `prefer-not-to-say` — matches the Flutter dropdown exactly
- `UserOut`: id, email, username, gender, created_at (response after signup / `/auth/me`)
- `Token`: access_token, token_type (response after login)
- `UserLogin`: email, password (input for login)

### 5a. Password Reset Schemas (`backend/app/schemas/password_reset.py`)
- `ForgotPasswordRequest`: email
- `VerifyResetCodeRequest`: email, code (exactly 6 digits)
- `VerifyResetCodeResponse`: reset_token
- `ResetPasswordRequest`: reset_token, new_password (8+ chars — same policy as signup)
- `MessageResponse`: message (generic, enumeration-safe response used by forgot-password and reset-password)

### 6. Security (`backend/app/core/security.py`)
- Password hashing with bcrypt (`passlib`)
- JWT token creation and verification (`python-jose`)
- Forgot-password additions: `generate_reset_code()` (cryptographically random 6-digit code), `hash_reset_code()` / `verify_reset_code()` (bcrypt, same context as passwords), `create_password_reset_token()` / `decode_password_reset_token()` — a short-lived, purpose-scoped JWT (`purpose: password_reset`) distinct from the login access token, binding a specific `PasswordResetCode` row to the token so it can't be reused across different codes

### 6a. Email (`backend/app/core/email.py`)
- `send_password_reset_email(to_email, code)` — sends the OTP via Brevo's transactional email REST API (`https://api.brevo.com/v3/smtp/email`), using `httpx` (no new dependency needed)
- Branded HTML email matching the app's theme (`#163422` dark green header with the Mindtrace logo, `#EAF7EA` light-green pill for the code, Manrope-style font)
- If `BREVO_API_KEY` / `BREVO_SENDER_EMAIL` aren't set (local dev without real credentials, and CI), the code is logged instead of emailed — no real Brevo account needed to run or test the flow
- A Brevo send failure is logged, not raised — the code is already saved, so the user can just hit "Resend Code" rather than getting a 500

### 7. Auth Router (`backend/app/routers/auth.py`)
- `POST /auth/signup` — creates a new user, returns `UserOut` (201)
  - Rejects duplicate email (409) and duplicate username (409), separately
- `POST /auth/login` — verifies credentials, returns JWT token (200)
- `GET /auth/me` — returns the current user from a valid bearer token (200), or 401/403 if missing/invalid

### 7a. Password Reset Router (`backend/app/routers/password_reset.py`)
- `POST /auth/forgot-password` — request a 6-digit reset code by email. Also doubles as "Resend Code". Always returns the same generic message (`"If an account exists for that email, a password reset code has been sent."`) regardless of whether the email is registered or the request was silently suppressed by the resend cooldown — never reveals which case occurred
- `POST /auth/verify-reset-code` — checks the code, returns a short-lived `reset_token` (200) or a generic 400 for any wrong/expired/unknown case
  - Code expires after 10 minutes (`RESET_CODE_EXPIRE_MINUTES`)
  - Locks out after 5 wrong attempts (`RESET_CODE_MAX_ATTEMPTS`) — a fresh code must be requested
  - A correctly-verified code can't be verified a second time
- `POST /auth/reset-password` — exchanges the `reset_token` for actually changing the password (200), or a generic 400 if the token is invalid, expired, or already used
  - `reset_token` is single-use (enforced via `PasswordResetCode.consumed_at`)

### 8. Database Migrations (`backend/alembic/`)
- `388eb01e7055` — creates the `users` table
- `a1b2c3d4e5f6` — adds `username` (nullable → backfilled with a placeholder → set NOT NULL → unique index). Fixed to use `batch_alter_table()` and `substr()` instead of Postgres-only `alter_column()`/`SUBSTRING()`, so it now runs cleanly on SQLite as well as Postgres.
- `b7c8d9e0f1a2` — adds nullable `gender` column (no backfill needed, since it's optional)
- `6f28d851f2c7` — creates the `password_reset_codes` table (FK to `users`, cascade delete, indexed on `user_id`)

### 9. Crisis Handler (`backend/app/crisis/hardcoded_response.py`)
- Hardcoded safety responses for crisis keywords (no AI needed for this)

### 10. Tests (`backend/tests/`)
- `conftest.py` — pytest fixtures (test DB, test client, shared signup payload including `username`, and `sent_reset_emails` — intercepts the Brevo call so tests can read the generated OTP without real credentials or network access)
- `test_auth.py` — 13 tests covering signup, login, `/auth/me`, age gate, duplicate email, and duplicate username
- `test_password_reset.py` — 14 tests covering: request-code for existing/unknown email (identical generic response), resend cooldown, resend after cooldown expires, correct/wrong code, attempt lockout, code expiry, code single-use, full reset flow (old password stops working, new one works), reset-token single-use, and the reset password-length policy
- All 27 tests passing

### 11. CI (`/.github/workflows/ci.yml`)
- GitHub Actions pipeline that runs backend tests and Flutter checks on every push
- No changes needed for the forgot-password feature — no new dependencies were added

---

## Frontend — What's Built

### Design System (`lib/core/theme.dart`)
- All colors ported from the original HTML/Tailwind design
- Primary dark green: `#163422`
- Page background: white `#FFFFFF`
- Card background: white
- Input fields: light green tint `#EAF7EA`
- Font: Manrope (via google_fonts package)
- Pill-shaped inputs (border-radius 999)
- Full ThemeData with inputDecorationTheme and elevatedButtonTheme
- Uses `.withValues(alpha:)` instead of the deprecated `.withOpacity()`

### Constants (`lib/core/constants.dart`)
- `baseUrl`: points to backend
  - Android emulator: `http://10.0.2.2:8000`
  - Windows/Chrome dev: `http://localhost:8000`
- `tokenKey`: key used to store JWT in SharedPreferences

### Auth Service (`lib/features/auth/services/auth_service.dart`)
- `signup(email, username, password, dateOfBirth, gender?)` — calls `POST /auth/signup`; `gender` is optional and only included in the request body when set
- `login(email, password)` — calls `POST /auth/login`, saves token
- `getSavedToken()` — reads JWT from SharedPreferences
- `logout()` — removes JWT from SharedPreferences
- `AuthException` — custom exception that carries the server's error message

### Data Models (`lib/features/auth/models/user_model.dart`)
- `UserOut` — mirrors backend response (id, email, createdAt). **Not yet updated** to parse `username`/`gender` from the response — harmless for now since the app doesn't display them anywhere yet, but worth adding once a profile/dashboard screen needs them.
- `AuthToken` — mirrors backend token response (accessToken, tokenType)

### Reusable Widgets
- **`AuthToggle`** — animated sliding Login/Sign Up pill toggle
- **`ClinicalTextField`** — pill-shaped text field with uppercase label above

### Signup Screen (`lib/features/auth/screens/signup_screen.dart`)
Fields:
- Email (with format validation)
- Username (min 3 chars, letters/numbers/underscores only)
- Password (min 8 chars, show/hide toggle)
- Confirm Password (must match)
- Date of Birth (DD/MM/YYYY mask → converted to YYYY-MM-DD for API)
- Gender dropdown (optional) — **now sent to the backend on submit**
- Age consent checkbox (required)

On submit:
1. Validates all fields
2. Checks age consent checkbox
3. Converts DOB format
4. Calls `POST /auth/signup` with email, username, password, date_of_birth, and gender
5. On success → shows snackbar → navigates to Login
6. On error → shows red error box with server message

### Login Screen (`lib/features/auth/screens/login_screen.dart`)
Fields:
- Email
- Password (show/hide toggle)

On submit:
1. Calls `POST /auth/login`
2. On success → saves JWT → shows snackbar (dashboard TODO)
3. On error → shows red error box

---

## Sprint 2 (Feature 2 + 3) — What's Built

### Backend — 4 new endpoints (`backend/app/routers/chatbot.py`, `assessment.py`)
- `POST /chatbot/intake` — freeform intake conversation. Hardcoded crisis-keyword check runs **before** the LLM call, so a crisis is never left to the model's judgement. Uses hybrid RAG retrieval (`app/rag/engine.py`: pgvector semantic search + BM25 keyword search, merged with Reciprocal Rank Fusion) to ground replies in the clinical knowledge base.
- `POST /assessment/classify` — keyword-matches the finished intake conversation to decide which of GAD-7 / PHQ-9 / DASS-Stress to run.
- `POST /assessment/questionnaire` — stateless, one question at a time (`app/chatbot/questionnaire_engine.py` holds the question banks + scoring). PHQ-9's safety-critical item (question 9) short-circuits to a crisis response if answered above "Not at all."
- `POST /assessment/complete` — takes all questionnaire scores, returns overall risk level, per-instrument severity, and recommendations.
- `POST /assessment/crisis-log` — audit log for crisis events. Only ever stores a SHA-256 hash of the triggering text, never the raw message.

### Frontend — full Sprint 2 flow, all screens live
`StartScreen → ChatbotIntakeScreen → FocusAreasScreen → QuestionnaireFlowScreen (loops per instrument) → ResultsScreen`, with `CrisisScreen` interrupting either the chat or the questionnaire whenever the backend returns `status: "crisis"`.
- **StartScreen** — welcome screen, greeting pulled from `GET /auth/me`.
- **ChatbotIntakeScreen** — chat UI (bot/user bubbles, typing indicator) wired to `/chatbot/intake`. Free-text only — no structured quick-reply endpoint exists on the backend, so the UI doesn't fake one.
- **FocusAreasScreen** — shows the `/classify` result (which instruments will run) before the questionnaire starts.
- **QuestionnaireFlowScreen** — renders answered Q&A as a chat log with the live question's radio options below, one instrument after another, calling `/complete` once the last one finishes.
- **CrisisScreen** — dedicated full screen (not an inline banner): red warning card, "Find Help Now" (opens a helpline sheet with tappable `tel:` links — new dependency `url_launcher`), "I'm Safe, Continue." Logs via `/assessment/crisis-log` on open.
- **ResultsScreen** — overall risk gauge (custom-painted), per-instrument severity breakdown, support banner. No "Download Report" / "Book a Session" buttons — deliberately left out since neither has a backend endpoint yet, rather than shipping non-functional stubs.
- New dependencies: `crypto` (SHA-256 hashing for crisis-log), `url_launcher` (helpline dialing).

### Bugs found and fixed post-build
- **`app/rag/engine.py`** — `:paramname::vector` (a named bind parameter immediately followed by Postgres's `::` cast, no separator) silently failed to bind in SQLAlchemy's `text()`, sending a literal `:` to asyncpg and crashing app startup during knowledge-base seeding. Fixed in 3 places (the seed insert, and both the `SELECT`/`ORDER BY` in `semantic_search`) by wrapping the param in parentheses: `(:paramname)::vector`.
- **`app/rag/engine.py`** — metadata serialization used `str(dict).replace("'", '"')` as a fake JSON encoder, which doesn't handle Python's `True`/`False`/`None`. Broke on `PHQ-9`'s `"safety_critical": True` metadata. Fixed by using real `json.dumps()`.
- **`android/app/build.gradle.kts`** — Kotlin Android plugin was declared (`apply false`) in `settings.gradle.kts` but never actually applied in the app module, so the `kotlin { compilerOptions { ... } }` block was unresolvable. Fixed by adding `id("org.jetbrains.kotlin.android")` to the `plugins {}` block.
- **`flutter analyze` cleanup** — fixed a dangling library doc comment, a `catchError` handler with a mismatched return type on `CrisisScreen`'s crisis-log call (replaced with a proper try/catch), and three missing `const` constructors on `StartScreen`.

---


### Docker (`docker-compose.yml`)
- PostgreSQL 15 container
- Database: `appdb`, user: `appuser`, password: `devpassword`
- Port: 5432

### `.env` file (backend)
```
DATABASE_URL=postgresql+asyncpg://appuser:devpassword@localhost:5432/appdb
JWT_SECRET_KEY=your-secret-here
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
MIN_SIGNUP_AGE=18
BREVO_API_KEY=your-brevo-api-key-here
BREVO_SENDER_EMAIL=your-verified-sender@example.com
BREVO_SENDER_NAME=Mindtrace
```
Note: `BREVO_API_KEY` is personal to whoever's running the backend locally — each team member should use their own free Brevo account/key rather than sharing one. Leave it blank and forgot-password codes are just logged to the console instead of emailed, so the whole flow still works for local testing without any Brevo account at all.

---

## How to Run

### Prerequisites
- Python 3.11+
- Flutter SDK
- Docker Desktop (needs virtualization enabled in BIOS)

### Step 1 — Start the database
```cmd
cd F:\MindTrace1\MindTrace
docker-compose up -d
```

### Step 2 — Start the backend
```cmd
cd F:\MindTrace1\MindTrace\backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```
Verify: open `http://localhost:8000/health` → should return `{"status":"ok"}`
API docs: `http://localhost:8000/docs`

### Step 3 — Run the frontend
```cmd
cd F:\MindTrace1\MindTrace\frontend
flutter pub get
flutter run -d chrome      # browser (no extra installs)
flutter run -d windows     # desktop (needs Visual Studio C++ tools)
```

---

## What's NOT Built Yet (Next Steps)

### Backend
- [x] Forgot password flow (send OTP to email)
- [x] OTP verification endpoint
- [x] Reset password endpoint
- [x] Email sending (Brevo transactional API)
- [x] Mental health screening/assessment endpoints (intake chatbot, classify, questionnaire, complete, crisis-log)
- [ ] User profile endpoints (beyond `GET /auth/me`)
- [ ] ML model integration (risk classifier, trajectory engine — later sprints)
- [ ] Basic Dashboard endpoints (Week 3, in progress)
- [ ] Report generation / session booking endpoints (referenced by the Results screen design, not built yet)

### Frontend
- [x] Forgot Password screen
- [x] OTP verification screen
- [x] Set New Password screen
- [x] Mental health assessment screens (Start, Chatbot Intake, Focus Areas, Questionnaire Flow, Crisis, Results)
- [ ] Home / Dashboard screen (Week 3)
- [ ] Profile screen
- [ ] Navigation/routing system (go_router) — currently plain `Navigator.push`/`pushReplacement`
- [ ] State management (Provider or Riverpod) — currently per-screen `setState`
- [x] Update `UserOut` (Dart model) to parse `username`/`gender` from the signup/`/me` response

---

## Known Issues / Notes

1. **Virtualization not enabled** — Docker won't start until BIOS virtualization is turned on. The setting is usually under Advanced → CPU → Intel VT-x or AMD SVM.
2. **Windows desktop** needs Visual Studio 2022 with "Desktop development with C++" workload. Use Chrome for now.
3. ~~**Gender field**~~ **Resolved.**
4. ~~**Full Name / Username**~~ **Resolved.**
5. **JWT after login** — token is saved to SharedPreferences but there's no route guard or auto-login yet; a killed/restarted app lands back on Login even with a valid saved token.
6. ~~**Frontend `UserOut` model**~~ **Resolved** — now parses `username`/`gender`, used by the Sprint 2 Start/Results screens for the greeting.
7. **Brevo API key** — each developer needs their own free Brevo account and API key in their local `.env` (never committed) to see real forgot-password emails; without one, the OTP code is just logged to the console.
8. **Sprint 2 frontend is untested against a real device/emulator by this assistant** — all 5 phases plus the bugfixes above were written and manually reviewed for correctness, but never run through `flutter run` here (no Flutter SDK in this environment). Confirmed working via your own `flutter run`/`flutter analyze` output during Sprint 2, with the 5 lint issues above fixed.
9. **No route guard / global navigation** — every Sprint 2 screen uses direct `Navigator.push`, no `go_router` yet. Fine for now, will need revisiting once the Dashboard (Week 3) adds more entry points into the assessment flow.
10. **"Download Full Report" / "Book a Session"** — appear in the original UI reference images but intentionally not built; no backend endpoint exists for either yet.