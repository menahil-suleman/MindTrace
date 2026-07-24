from datetime import date, datetime, timezone

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.core.config import get_settings

# Must match the values sent by the Flutter signup screen's gender dropdown.
ALLOWED_GENDERS = {"male", "female", "non-binary", "prefer-not-to-say"}


class UserCreate(BaseModel):
    email: EmailStr
    username: str = Field(min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_]+$")
    password: str = Field(min_length=8, max_length=72)
    date_of_birth: date
    # Optional — the signup form's gender dropdown isn't a required field.
    gender: str | None = None

    @field_validator("date_of_birth")
    @classmethod
    def must_meet_minimum_age(cls, value: date) -> date:
        min_age = get_settings().min_signup_age
        today = datetime.now(timezone.utc).date()
        age = today.year - value.year - ((today.month, today.day) < (value.month, value.day))
        if value > today:
            raise ValueError("date_of_birth cannot be in the future")
        if age < min_age:
            raise ValueError(f"you must be at least {min_age} years old to sign up")
        return value

    @field_validator("gender")
    @classmethod
    def gender_must_be_known_value(cls, value: str | None) -> str | None:
        if value is None:
            return value
        if value not in ALLOWED_GENDERS:
            raise ValueError(f"gender must be one of: {', '.join(sorted(ALLOWED_GENDERS))}")
        return value


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    username: str
    gender: str | None = None
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"