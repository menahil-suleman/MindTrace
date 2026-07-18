from fastapi import FastAPI

from app.routers import auth

app = FastAPI(
    title="MindTrace API",
    description="Backend for MindTrace — a non-diagnostic mental health screening and monitoring app.",
    version="0.1.0",
)

app.include_router(auth.router)


@app.get("/health", tags=["health"])
async def health_check() -> dict[str, str]:
    return {"status": "ok"}