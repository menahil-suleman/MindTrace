from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.password_reset_code import PasswordResetCode

pytestmark = pytest.mark.asyncio


async def _latest_code_row(db_session: AsyncSession, user_id: str) -> PasswordResetCode:
    row = await db_session.scalar(
        select(PasswordResetCode)
        .where(PasswordResetCode.user_id == user_id)
        .order_by(PasswordResetCode.created_at.desc())
    )
    assert row is not None
    return row


async def _signup_and_get_user_id(client: AsyncClient, payload: dict) -> str:
    response = await client.post("/auth/signup", json=payload)
    assert response.status_code == 201
    return response.json()["id"]


# ── forgot-password ──────────────────────────────────────────────────────────


async def test_forgot_password_existing_email_sends_code(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)

    response = await client.post(
        "/auth/forgot-password", json={"email": adult_signup_payload["email"]}
    )
    assert response.status_code == 200
    assert "reset code" in response.json()["message"].lower()

    assert len(sent_reset_emails) == 1
    assert sent_reset_emails[0]["to"] == adult_signup_payload["email"]
    assert len(sent_reset_emails[0]["code"]) == 6
    assert sent_reset_emails[0]["code"].isdigit()


async def test_forgot_password_unknown_email_returns_identical_generic_message(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)

    known = await client.post(
        "/auth/forgot-password", json={"email": adult_signup_payload["email"]}
    )
    unknown = await client.post(
        "/auth/forgot-password", json={"email": "nobody@example.com"}
    )

    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json()
    # Only the real user's email actually got sent something.
    assert len(sent_reset_emails) == 1


async def test_forgot_password_resend_within_cooldown_does_not_send_again(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)

    first = await client.post(
        "/auth/forgot-password", json={"email": adult_signup_payload["email"]}
    )
    second = await client.post(
        "/auth/forgot-password", json={"email": adult_signup_payload["email"]}
    )

    assert first.status_code == second.status_code == 200
    assert first.json() == second.json()
    # Still just the one email — the immediate resend was silently suppressed.
    assert len(sent_reset_emails) == 1


async def test_forgot_password_resend_after_cooldown_sends_new_code(
    client: AsyncClient,
    db_session: AsyncSession,
    adult_signup_payload: dict,
    sent_reset_emails: list,
):
    user_id = await _signup_and_get_user_id(client, adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})

    # Simulate the cooldown having already passed.
    row = await _latest_code_row(db_session, user_id)
    row.created_at = datetime.now(timezone.utc) - timedelta(minutes=5)
    await db_session.commit()

    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})

    assert len(sent_reset_emails) == 2
    assert sent_reset_emails[0]["code"] != sent_reset_emails[1]["code"]


# ── verify-reset-code ────────────────────────────────────────────────────────


async def test_verify_reset_code_success_returns_reset_token(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})
    code = sent_reset_emails[0]["code"]

    response = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": code},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["reset_token"], str)
    assert len(response.json()["reset_token"]) > 0


async def test_verify_reset_code_rejects_wrong_code(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})

    response = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": "000000"},
    )
    assert response.status_code == 400


async def test_verify_reset_code_rejects_unknown_email(client: AsyncClient):
    response = await client.post(
        "/auth/verify-reset-code",
        json={"email": "nobody@example.com", "code": "123456"},
    )
    assert response.status_code == 400


async def test_verify_reset_code_locks_out_after_max_attempts(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})
    correct_code = sent_reset_emails[0]["code"]

    # Default max attempts is 5 — burn through them with wrong guesses.
    for _ in range(5):
        response = await client.post(
            "/auth/verify-reset-code",
            json={"email": adult_signup_payload["email"], "code": "000000"},
        )
        assert response.status_code == 400

    # Even the correct code is now locked out — must request a new one.
    locked_out = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": correct_code},
    )
    assert locked_out.status_code == 400


async def test_verify_reset_code_rejects_expired_code(
    client: AsyncClient,
    db_session: AsyncSession,
    adult_signup_payload: dict,
    sent_reset_emails: list,
):
    user_id = await _signup_and_get_user_id(client, adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})
    code = sent_reset_emails[0]["code"]

    row = await _latest_code_row(db_session, user_id)
    row.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
    await db_session.commit()

    response = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": code},
    )
    assert response.status_code == 400


async def test_verify_reset_code_cannot_be_reused(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})
    code = sent_reset_emails[0]["code"]

    first = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": code},
    )
    assert first.status_code == 200

    second = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": code},
    )
    assert second.status_code == 400


# ── reset-password ───────────────────────────────────────────────────────────


async def test_reset_password_success_changes_password(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})
    code = sent_reset_emails[0]["code"]

    verify_response = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": code},
    )
    reset_token = verify_response.json()["reset_token"]

    reset_response = await client.post(
        "/auth/reset-password",
        json={"reset_token": reset_token, "new_password": "brandnewpassword456"},
    )
    assert reset_response.status_code == 200

    old_login = await client.post(
        "/auth/login",
        json={
            "email": adult_signup_payload["email"],
            "password": adult_signup_payload["password"],
        },
    )
    assert old_login.status_code == 401

    new_login = await client.post(
        "/auth/login",
        json={"email": adult_signup_payload["email"], "password": "brandnewpassword456"},
    )
    assert new_login.status_code == 200


async def test_reset_password_rejects_garbage_token(client: AsyncClient):
    response = await client.post(
        "/auth/reset-password",
        json={"reset_token": "not-a-real-token", "new_password": "brandnewpassword456"},
    )
    assert response.status_code == 400


async def test_reset_password_token_is_single_use(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})
    code = sent_reset_emails[0]["code"]

    verify_response = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": code},
    )
    reset_token = verify_response.json()["reset_token"]

    first = await client.post(
        "/auth/reset-password",
        json={"reset_token": reset_token, "new_password": "brandnewpassword456"},
    )
    assert first.status_code == 200

    second = await client.post(
        "/auth/reset-password",
        json={"reset_token": reset_token, "new_password": "yetanotherpassword789"},
    )
    assert second.status_code == 400


async def test_reset_password_rejects_short_password(
    client: AsyncClient, adult_signup_payload: dict, sent_reset_emails: list
):
    await client.post("/auth/signup", json=adult_signup_payload)
    await client.post("/auth/forgot-password", json={"email": adult_signup_payload["email"]})
    code = sent_reset_emails[0]["code"]

    verify_response = await client.post(
        "/auth/verify-reset-code",
        json={"email": adult_signup_payload["email"], "code": code},
    )
    reset_token = verify_response.json()["reset_token"]

    response = await client.post(
        "/auth/reset-password",
        json={"reset_token": reset_token, "new_password": "short"},
    )
    assert response.status_code == 422
