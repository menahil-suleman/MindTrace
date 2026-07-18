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
│   │   ├── core/          # Config, security (JWT), settings
│   │   ├── db/            # Database session (SQLAlchemy async)
│   │   ├── models/        # SQLAlchemy ORM models (User)
│   │   ├── routers/       # API route handlers (auth)
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

### 3. Database (`backend/app/db/session.py`)
- Async SQLAlchemy engine + session factory
- Connects to PostgreSQL via `DATABASE_URL` from `.env`
- Database: `appdb`, user: `appuser`, password: `devpassword` (matches docker-compose)

### 4. User Model (`backend/app/models/user.py`)
- SQLAlchemy ORM model for `users` table
- Fields: `id` (UUID), `email` (unique), `hashed_password`, `date_of_birth`, `created_at`

### 5. Schemas (`backend/app/schemas/user.py`)
- `UserCreate`: email, password, date_of_birth (input for signup)
- `UserOut`: id, email, created_at (response after signup)
- `Token`: access_token, token_type (response after login)
- `LoginRequest`: email, password (input for login)

### 6. Security (`backend/app/core/security.py`)
- Password hashing with bcrypt (`passlib`)
- JWT token creation and verification (`python-jose`)

### 7. Auth Router (`backend/app/routers/auth.py`)
- `POST /auth/signup` — creates a new user, returns `UserOut` (201)
- `POST /auth/login` — verifies credentials, returns JWT token (200)

### 8. Database Migrations (`backend/alembic/`)
- Alembic set up for schema migrations
- Migration `388eb01e7055` — creates the `users` table

### 9. Crisis Handler (`backend/app/crisis/hardcoded_response.py`)
- Hardcoded safety responses for crisis keywords (no AI needed for this)

### 10. Tests (`backend/tests/`)
- `conftest.py` — pytest fixtures (test DB, test client)
- `test_auth.py` — tests for signup and login endpoints

### 11. CI (`/.github/workflows/ci.yml`)
- GitHub Actions pipeline that runs backend tests on every push

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

### Constants (`lib/core/constants.dart`)
- `baseUrl`: points to backend
  - Android emulator: `http://10.0.2.2:8000`
  - Windows/Chrome dev: `http://localhost:8000`
- `tokenKey`: key used to store JWT in SharedPreferences

### Auth Service (`lib/features/auth/services/auth_service.dart`)
- `signup(email, password, dateOfBirth)` — calls `POST /auth/signup`
- `login(email, password)` — calls `POST /auth/login`, saves token
- `getSavedToken()` — reads JWT from SharedPreferences
- `logout()` — removes JWT from SharedPreferences
- `AuthException` — custom exception that carries the server's error message

### Data Models (`lib/features/auth/models/user_model.dart`)
- `UserOut` — mirrors backend response (id, email, createdAt)
- `AuthToken` — mirrors backend token response (accessToken, tokenType)

### Reusable Widgets
- **`AuthToggle`** — animated sliding Login/Sign Up pill toggle
- **`ClinicalTextField`** — pill-shaped text field with uppercase label above

### Signup Screen (`lib/features/auth/screens/signup_screen.dart`)
Fields:
- Email (with format validation)
- Password (min 8 chars, show/hide toggle)
- Confirm Password (must match)
- Date of Birth (DD/MM/YYYY mask → converted to YYYY-MM-DD for API)
- Gender dropdown (optional, not sent to backend yet)
- Age consent checkbox (required)

On submit:
1. Validates all fields
2. Checks age consent checkbox
3. Converts DOB format
4. Calls `POST /auth/signup`
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
```

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
- [ ] Forgot password flow (send OTP to email)
- [ ] OTP verification endpoint
- [ ] Reset password endpoint
- [ ] Email sending (fastapi-mail or SendGrid)
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

---

## Known Issues / Notes

1. **Virtualization not enabled** — Docker won't start until BIOS virtualization is turned on. The setting is usually under Advanced → CPU → Intel VT-x or AMD SVM.
2. **Windows desktop** needs Visual Studio 2022 with "Desktop development with C++" workload. Use Chrome for now.
3. **Gender field** — exists in the signup UI but is not sent to the backend (no column in DB yet).
4. **Full Name / Username** — exist in the original design mockup but are not in the backend model yet.
5. **JWT after login** — token is saved to SharedPreferences but there's no route guard or auto-login yet.
