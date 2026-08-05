from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, password_reset, chatbot, assessment
from app.db.session import AsyncSessionLocal
from app.rag.engine import ensure_rag_schema, seed_knowledge_base


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    LEARN: lifespan runs startup code before the server accepts requests,
    and teardown code after it stops.
    We use it to set up the RAG schema and seed the knowledge base once.
    This way the first request is never slow waiting for schema creation.
    """
    async with AsyncSessionLocal() as db:
        await ensure_rag_schema(db)
        await seed_knowledge_base(db)
    yield   # server runs here


app = FastAPI(
    title="MindTrace API",
    description="Backend for MindTrace — a non-diagnostic mental health screening and monitoring app.",
    version="0.1.0",
    lifespan=lifespan,
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
app.include_router(chatbot.router)
app.include_router(assessment.router)


@app.get("/health", tags=["health"])
async def health_check() -> dict[str, str]:
    return {"status": "ok"}