import secrets
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

settings = get_settings()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# bcrypt has a hard 72-byte limit on the input password. Anything longer is
# silently truncated by some backends and raises on others — we truncate
# explicitly up front so behavior is consistent and predictable.
BCRYPT_MAX_BYTES = 72


def _truncate_for_bcrypt(password: str) -> str:
    return password.encode("utf-8")[:BCRYPT_MAX_BYTES].decode("utf-8", errors="ignore")


def hash_password(password: str) -> str:
    return pwd_context.hash(_truncate_for_bcrypt(password))


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(_truncate_for_bcrypt(plain_password), hashed_password)


def create_access_token(subject: str, expires_delta: timedelta | None = None) -> str:
    """Create a signed JWT. `subject` is typically the user's id (as a string)."""
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.access_token_expire_minutes)
    )
    to_encode = {"sub": subject, "exp": expire}
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> str | None:
    """Return the subject (user id) encoded in the token, or None if invalid/expired."""
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        return payload.get("sub")
    except JWTError:
        return None


# ── Forgot-password OTP helpers ──────────────────────────────────────────────
# The 6-digit code is short and numeric, so it's hashed with the same bcrypt
# context used for passwords rather than inventing a second scheme.


def generate_reset_code() -> str:
    """A cryptographically random 6-digit code, zero-padded (e.g. '004821')."""
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_reset_code(code: str) -> str:
    return pwd_context.hash(code)


def verify_reset_code(plain_code: str, code_hash: str) -> bool:
    return pwd_context.verify(plain_code, code_hash)


RESET_TOKEN_PURPOSE = "password_reset"


def create_password_reset_token(user_id: str, code_id: str) -> str:
    """A short-lived JWT proving a specific OTP (`code_id`) was just verified for `user_id`.

    Kept separate from the login access token: different purpose claim, much
    shorter expiry, and single-use (enforced via `PasswordResetCode.consumed_at`
    in the router, not by this token alone).
    """
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.reset_token_expire_minutes)
    to_encode = {
        "sub": user_id,
        "code_id": code_id,
        "purpose": RESET_TOKEN_PURPOSE,
        "exp": expire,
    }
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_password_reset_token(token: str) -> dict | None:
    """Return {"user_id": ..., "code_id": ...} if `token` is a valid, unexpired
    password-reset token, or None otherwise."""
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None

    if payload.get("purpose") != RESET_TOKEN_PURPOSE:
        return None

    user_id = payload.get("sub")
    code_id = payload.get("code_id")
    if not user_id or not code_id:
        return None

    return {"user_id": user_id, "code_id": code_id}