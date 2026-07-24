from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.email import send_password_reset_email
from app.core.security import (
    create_password_reset_token,
    decode_password_reset_token,
    generate_reset_code,
    hash_password,
    hash_reset_code,
    verify_reset_code,
)
from app.db.session import get_db
from app.models.password_reset_code import PasswordResetCode
from app.models.user import User
from app.schemas.password_reset import (
    ForgotPasswordRequest,
    MessageResponse,
    ResetPasswordRequest,
    VerifyResetCodeRequest,
    VerifyResetCodeResponse,
)

router = APIRouter(prefix="/auth", tags=["password-reset"])


def _as_aware_utc(value: datetime) -> datetime:
    """SQLite (used in tests/CI) round-trips DateTime(timezone=True) values as
    naive datetimes, even though Postgres keeps them tz-aware. Normalize so
    comparisons work the same on both backends."""
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)

# Same generic message regardless of whether the email is registered, whether
# a code was actually (re)sent, or whether a resend is still in its cooldown —
# the response must never let someone tell those cases apart from the outside.
FORGOT_PASSWORD_GENERIC_MESSAGE = (
    "If an account exists for that email, a password reset code has been sent."
)

# Same generic error for "no such user", "wrong code", "expired code", and
# "too many attempts" — never reveal which one it was.
INVALID_CODE_DETAIL = "Incorrect or expired code."

# Same generic error for any problem with the reset token itself.
INVALID_RESET_TOKEN_DETAIL = "This reset session is invalid or has expired. Please request a new code."


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    payload: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)
) -> MessageResponse:
    """Request a password-reset code. Also used for "Resend Code" — calling
    this again just issues a fresh code, subject to the resend cooldown."""
    settings = get_settings()
    user = await db.scalar(select(User).where(User.email == payload.email))

    if user is not None:
        now = datetime.now(timezone.utc)
        latest = await db.scalar(
            select(PasswordResetCode)
            .where(PasswordResetCode.user_id == user.id)
            .order_by(PasswordResetCode.created_at.desc())
        )
        cooldown = timedelta(seconds=settings.reset_code_resend_cooldown_seconds)
        still_in_cooldown = latest is not None and (
            now - _as_aware_utc(latest.created_at)
        ) < cooldown

        if not still_in_cooldown:
            code = generate_reset_code()
            reset_code = PasswordResetCode(
                user_id=user.id,
                code_hash=hash_reset_code(code),
                expires_at=now + timedelta(minutes=settings.reset_code_expire_minutes),
            )
            db.add(reset_code)
            await db.commit()
            await send_password_reset_email(user.email, code)
        # If still in cooldown, do nothing — the response is identical either way.

    return MessageResponse(message=FORGOT_PASSWORD_GENERIC_MESSAGE)


@router.post("/verify-reset-code", response_model=VerifyResetCodeResponse)
async def verify_reset_code_endpoint(
    payload: VerifyResetCodeRequest, db: AsyncSession = Depends(get_db)
) -> VerifyResetCodeResponse:
    """Check a 6-digit code and, if correct, exchange it for a short-lived
    reset token to be used with /auth/reset-password."""
    settings = get_settings()
    invalid = HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=INVALID_CODE_DETAIL)

    user = await db.scalar(select(User).where(User.email == payload.email))
    if user is None:
        raise invalid

    code_row = await db.scalar(
        select(PasswordResetCode)
        .where(
            PasswordResetCode.user_id == user.id,
            PasswordResetCode.verified_at.is_(None),
            PasswordResetCode.consumed_at.is_(None),
        )
        .order_by(PasswordResetCode.created_at.desc())
    )
    if code_row is None:
        raise invalid

    now = datetime.now(timezone.utc)
    if _as_aware_utc(code_row.expires_at) < now:
        raise invalid

    if code_row.attempt_count >= settings.reset_code_max_attempts:
        raise invalid

    if not verify_reset_code(payload.code, code_row.code_hash):
        code_row.attempt_count += 1
        await db.commit()
        raise invalid

    code_row.verified_at = now
    await db.commit()

    reset_token = create_password_reset_token(user_id=user.id, code_id=code_row.id)
    return VerifyResetCodeResponse(reset_token=reset_token)


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)
) -> MessageResponse:
    """Finish the flow: exchange a verified reset token for setting a new password."""
    invalid = HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST, detail=INVALID_RESET_TOKEN_DETAIL
    )

    token_data = decode_password_reset_token(payload.reset_token)
    if token_data is None:
        raise invalid

    code_row = await db.get(PasswordResetCode, token_data["code_id"])
    if (
        code_row is None
        or code_row.user_id != token_data["user_id"]
        or code_row.verified_at is None
        or code_row.consumed_at is not None
    ):
        raise invalid

    user = await db.get(User, token_data["user_id"])
    if user is None:
        raise invalid

    user.hashed_password = hash_password(payload.new_password)
    code_row.consumed_at = datetime.now(timezone.utc)
    await db.commit()

    return MessageResponse(message="Your password has been reset. You can now log in.")
