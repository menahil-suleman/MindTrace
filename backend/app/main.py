from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, password_reset

app = FastAPI(
    title="MindTrace API",
    description="Backend for MindTrace — a non-diagnostic mental health screening and monitoring app.",
    version="0.1.0",
)

# Allow the Flutter web/desktop app to call the API during development.
# Tighten origins before deploying to production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:*",
        "http://127.0.0.1:*",
        # Flutter web dev server default port
        "http://localhost:5000",
        "http://localhost:8080",
        "http://localhost:52942",  # flutter run picks a random port — wildcard covers it
    ],
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(password_reset.router)


@app.get("/health", tags=["health"])
async def health_check() -> dict[str, str]:
    return {"status": "ok"}