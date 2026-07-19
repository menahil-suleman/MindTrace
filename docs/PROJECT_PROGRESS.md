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
│   │   ├── routers/       # API route handlers (auth, password_reset)
│   │   ├── schemas/       # Pydantic request/response schemas
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
│   │   └── features/auth/
│   │       ├── models/
│   │       │   └── user_model.dart     # UserOut, AuthToken data classes
│   │       ├── services/
│   │       │   └── auth_service.dart   # signup(), login(), token storage
│   │       ├── widgets/
│   │       │   ├── auth_toggle.dart         # Login/Sign Up sliding toggle
│   │       │   └── clinical_text_field.dart # Reusable pill-shaped input
│   │       └── screens/
│   │           ├── signup_screen.dart  # Full signup form
│   │           └── login_screen.dart   # Login form
│   ├── assets/images/logo.png   # MindTrace logo
│   ├── android/                 # Android platform files
│   ├── windows/                 # Windows platform files
│   ├── web/                     # Web platform files
│   └── pubspec.yaml             # Flutter dependencies
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

## Infrastructure

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
- [ ] User profile endpoints
- [ ] Mental health screening/assessment endpoints
- [ ] ML model integration

### Frontend
- [ ] Forgot Password screen
- [ ] OTP verification screen
- [ ] Set New Password screen
- [ ] Home / Dashboard screen
- [ ] Mental health assessment screens
- [ ] Profile screen
- [ ] Navigation/routing system (go_router)
- [ ] State management (Provider or Riverpod)
- [ ] Update `UserOut` (Dart model) to parse `username`/`gender` from the signup/`/me` response, once a screen needs to display them

---

## Known Issues / Notes

1. **Virtualization not enabled** — Docker won't start until BIOS virtualization is turned on. The setting is usually under Advanced → CPU → Intel VT-x or AMD SVM.
2. **Windows desktop** needs Visual Studio 2022 with "Desktop development with C++" workload. Use Chrome for now.
3. ~~**Gender field** — exists in the signup UI but is not sent to the backend (no column in DB yet).~~ **Resolved** — `gender` is now a column on `User`, part of `UserCreate`/`UserOut`, and sent from the signup form.
4. ~~**Full Name / Username** — exist in the original design mockup but are not in the backend model yet.~~ **Resolved** — `username` is now a required column on `User`, unique, validated, and checked for duplicates on signup.
5. **JWT after login** — token is saved to SharedPreferences but there's no route guard or auto-login yet.
6. **Frontend `UserOut` model** — doesn't yet parse `username`/`gender` out of the backend response (see Frontend Next Steps above). Not currently causing any bugs, since nothing in the UI reads those fields yet.
7. **Brevo API key** — each developer needs their own free Brevo account and API key in their local `.env` (never committed) to see real forgot-password emails; without one, the OTP code is just logged to the console, which is enough to test the flow end-to-end.