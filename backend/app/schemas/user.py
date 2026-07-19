from datetime import date, datetime, timezone

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.core.config import get_settings


class UserCreate(BaseModel):
    email: EmailStr
    username: str = Field(min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_]+$")
    password: str = Field(min_length=8, max_length=72)
    date_of_birth: date

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


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    username: str
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"