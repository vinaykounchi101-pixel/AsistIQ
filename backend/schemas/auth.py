import uuid
from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from backend.models.enums import UserRole, AuthProvider, AvailabilityStatus


class BaseStrictSchema(BaseModel):
    model_config = ConfigDict(extra="forbid")


class UserCreateSchema(BaseStrictSchema):
    email: EmailStr
    password: str = Field(min_length=8, description="Password must be at least 8 characters")
    full_name: str = Field(min_length=1, max_length=150)
    role: Optional[UserRole] = UserRole.REQUESTER
    site: Optional[str] = None


class UserLoginSchema(BaseStrictSchema):
    email: EmailStr
    password: str


class GoogleLoginSchema(BaseStrictSchema):
    code: Optional[str] = Field(default=None, description="Authorization code from Google OAuth redirect")
    id_token: Optional[str] = Field(default=None, description="Google ID Token from mobile client")
    redirect_uri: Optional[str] = Field(default=None, description="Redirect URI matching authorization request")


class RefreshTokenSchema(BaseStrictSchema):
    refresh_token: str


class VerifyEmailSchema(BaseStrictSchema):
    token: str


class TokenResponseSchema(BaseStrictSchema):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    full_name: str
    role: UserRole
    auth_provider: AuthProvider
    email_verified: bool
    availability_status: AvailabilityStatus
    site: Optional[str] = None
    created_at: datetime


class AuthResponseSchema(BaseStrictSchema):
    user: UserResponseSchema
    tokens: TokenResponseSchema


class ErrorDetailSchema(BaseModel):
    code: str
    message: str
    details: Optional[Dict[str, Any]] = None


class ErrorEnvelopeSchema(BaseModel):
    error: ErrorDetailSchema
