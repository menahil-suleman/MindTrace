import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_health_check(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


async def test_signup_success(client: AsyncClient, adult_signup_payload: dict):
    response = await client.post("/auth/signup", json=adult_signup_payload)
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == adult_signup_payload["email"]
    assert "id" in body
    assert "password" not in body
    assert "hashed_password" not in body


async def test_signup_rejects_under_18(client: AsyncClient):
    payload = {
        "email": "minor@example.com",
        "username": "minor_user",
        "password": "strongpassword123",
        "date_of_birth": "2015-01-15",
    }
    response = await client.post("/auth/signup", json=payload)
    assert response.status_code == 422
    assert "18" in str(response.json())


async def test_signup_rejects_future_dob(client: AsyncClient):
    payload = {
        "email": "future@example.com",
        "username": "future_user",
        "password": "strongpassword123",
        "date_of_birth": "2999-01-01",
    }
    response = await client.post("/auth/signup", json=payload)
    assert response.status_code == 422


async def test_signup_rejects_duplicate_email(client: AsyncClient, adult_signup_payload: dict):
    first = await client.post("/auth/signup", json=adult_signup_payload)
    assert first.status_code == 201

    # Same email, different username — should still reject as duplicate email
    duplicate = {**adult_signup_payload, "username": "different_user"}
    second = await client.post("/auth/signup", json=duplicate)
    assert second.status_code == 409


async def test_signup_rejects_duplicate_username(client: AsyncClient, adult_signup_payload: dict):
    first = await client.post("/auth/signup", json=adult_signup_payload)
    assert first.status_code == 201

    # Different email, same username — should reject as duplicate username
    duplicate = {**adult_signup_payload, "email": "other@example.com"}
    second = await client.post("/auth/signup", json=duplicate)
    assert second.status_code == 409


async def test_signup_rejects_short_password(client: AsyncClient):
    payload = {
        "email": "shortpw@example.com",
        "username": "shortpw_user",
        "password": "short",
        "date_of_birth": "2000-01-01",
    }
    response = await client.post("/auth/signup", json=payload)
    assert response.status_code == 422


async def test_login_success(client: AsyncClient, adult_signup_payload: dict):
    await client.post("/auth/signup", json=adult_signup_payload)

    response = await client.post(
        "/auth/login",
        json={
            "email": adult_signup_payload["email"],
            "password": adult_signup_payload["password"],
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert isinstance(body["access_token"], str) and len(body["access_token"]) > 0


async def test_login_rejects_wrong_password(client: AsyncClient, adult_signup_payload: dict):
    await client.post("/auth/signup", json=adult_signup_payload)

    response = await client.post(
        "/auth/login",
        json={"email": adult_signup_payload["email"], "password": "wrongpassword"},
    )
    assert response.status_code == 401


async def test_login_rejects_unknown_email(client: AsyncClient):
    response = await client.post(
        "/auth/login",
        json={"email": "doesnotexist@example.com", "password": "whatever123"},
    )
    assert response.status_code == 401


async def test_me_requires_token(client: AsyncClient):
    response = await client.get("/auth/me")
    assert response.status_code == 403


async def test_me_rejects_garbage_token(client: AsyncClient):
    response = await client.get("/auth/me", headers={"Authorization": "Bearer not-a-real-token"})
    assert response.status_code == 401


async def test_me_returns_current_user_with_valid_token(
    client: AsyncClient, adult_signup_payload: dict
):
    await client.post("/auth/signup", json=adult_signup_payload)
    login_response = await client.post(
        "/auth/login",
        json={
            "email": adult_signup_payload["email"],
            "password": adult_signup_payload["password"],
        },
    )
    token = login_response.json()["access_token"]

    response = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["email"] == adult_signup_payload["email"]
