import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class PasswordResetCode(Base):
    """A single "forgot password" OTP attempt for a user.

    Lifecycle: created (unverified) -> verified (code checked out, reset token
    issued) -> consumed (password actually changed). Both `verified_at` and
    `consumed_at` exist so that neither the 6-digit code nor the reset token
    it produces can ever be replayed.
    """

    __tablename__ = "password_reset_codes"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Never store the raw 6-digit code — only its bcrypt hash.
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempt_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    # Set once the correct code has been entered (code itself can't be reused after this).
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Set once the password has actually been changed via this code's reset token.
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    def __repr__(self) -> str:
        return f"<PasswordResetCode id={self.id} user_id={self.user_id}>"
