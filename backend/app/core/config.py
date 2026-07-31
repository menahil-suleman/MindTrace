from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central app configuration, loaded from environment variables / .env file."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    min_signup_age: int = 18

    # Brevo (transactional email) — used to send password-reset codes.
    # If brevo_api_key is unset (e.g. in tests/CI), emails are logged instead of sent.
    brevo_api_key: str | None = None
    brevo_sender_email: str | None = None
    brevo_sender_name: str = "Mindtrace"

    # Forgot-password / OTP settings
    reset_code_expire_minutes: int = 10
    reset_code_resend_cooldown_seconds: int = 45
    reset_code_max_attempts: int = 5
    reset_token_expire_minutes: int = 10

    # LLM — Groq (https://console.groq.com → API Keys → free tier available)
    # If unset, the chatbot endpoint will return a 503 with a clear error message.
    groq_api_key: str | None = None
    # Model to use — llama-3.3-70b-versatile is free on Groq's free tier
    groq_model: str = "llama-3.3-70b-versatile"


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance — .env is only read once per process."""
    return Settings()