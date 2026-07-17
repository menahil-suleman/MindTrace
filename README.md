# MindTrace

**AI-assisted mental health screening and monitoring platform** — a mobile-first tool that combines validated clinical questionnaires, conversational AI, and machine learning to help people understand patterns in their mental health over time.

> ⚠️ **MindTrace is a screening and monitoring tool. It is not a diagnostic device and does not replace professional medical advice.** See the in-app Limitations page for details on what each module can and cannot tell you.

## Status

🚧 **Planning phase.** Development has not yet started. See [`docs/PROJECT_PLAN.md`](docs/PROJECT_PLAN.md) for the full project plan and [`docs/SPRINT_LOG.md`](docs/SPRINT_LOG.md) for sprint-by-sprint progress.

## What It Does

- Delivers validated clinical questionnaires (GAD-7, PHQ-9, DASS, and condition-specific instruments) through a conversational interface
- Produces a per-condition risk category and confidence score using a trained classifier
- Detects meaningful behavioral change over time via a longitudinal trajectory engine
- Surfaces verified mental health professionals when risk indicators cross a defined threshold
- Provides ongoing self-guided exercises (CBT-based: thought records, breathing, grounding, journaling)
- Includes a hardcoded, non-AI crisis safety response that fires independently of any model output

## Architecture

Three independently deployable services:

| Service | Stack | Responsibility |
|---|---|---|
| **Mobile App** | Flutter / Dart | UI, on-device camera task, local notifications |
| **Backend API** | FastAPI, PostgreSQL, SQLAlchemy | Auth, questionnaire scoring, data storage, Claude API integration |
| **ML Service** | scikit-learn, Ruptures | Risk classification, changepoint/trajectory detection |

## Tech Stack

- **Mobile:** Flutter, Dart, Provider, Dio, fl_chart, Firebase Cloud Messaging
- **Backend:** FastAPI, SQLAlchemy, Alembic, PostgreSQL, JWT auth
- **ML:** scikit-learn, pandas, Ruptures, scipy
- **AI:** Claude API (Anthropic)
- **Infra:** Railway, Neon, Firebase, GitHub Actions (CI/CD)

## Getting Started

_Setup instructions will be added once the initial scaffolding is in place._

## Documentation

- [`docs/PROJECT_PLAN.md`](docs/PROJECT_PLAN.md) — full SDLC plan: scope, sprint timeline, workflow, testing strategy, risk assessment
- [`docs/SPRINT_LOG.md`](docs/SPRINT_LOG.md) — weekly progress tracker

## Non-Functional Principles

- No raw camera footage or chat transcripts are ever stored — only extracted structured data
- Every AI/ML output is framed as a risk category, never a diagnosis
- Secrets and credentials are never committed to this repository

## License

_To be determined._