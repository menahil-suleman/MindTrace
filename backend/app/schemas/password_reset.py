from pydantic import BaseModel, EmailStr, Field


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyResetCodeRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


class VerifyResetCodeResponse(BaseModel):
    reset_token: str


class ResetPasswordRequest(BaseModel):
    reset_token: str
    # Matches the signup password policy (UserCreate) — kept identical on purpose.
    new_password: str = Field(min_length=8, max_length=72)


class MessageResponse(BaseModel):
    message: str
