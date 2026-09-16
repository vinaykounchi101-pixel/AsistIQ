from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.orm import Session
from backend.db.session import get_db
from backend.models.user import User
from backend.services.auth_service import AuthService
from backend.api.deps import get_current_user
from backend.schemas.auth import (
    UserCreateSchema, UserLoginSchema, GoogleLoginSchema,
    RefreshTokenSchema, AuthResponseSchema, TokenResponseSchema,
    UserResponseSchema
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/signup", response_model=AuthResponseSchema, status_code=status.HTTP_201_CREATED)
async def signup(data: UserCreateSchema, db: Session = Depends(get_db)):
    """
    Register a new password-based account (SRS v3.3 §3.3a, §6).
    """
    return await AuthService.signup(db, data)


@router.post("/login", response_model=AuthResponseSchema, status_code=status.HTTP_200_OK)
def login(data: UserLoginSchema, db: Session = Depends(get_db)):
    """
    Authenticate via email and password (SRS v3.3 §7.4).
    """
    return AuthService.login(db, data)


@router.post("/google", response_model=AuthResponseSchema, status_code=status.HTTP_200_OK)
async def google_auth(data: GoogleLoginSchema, db: Session = Depends(get_db)):
    """
    Authenticate or register via Google OAuth 2.0 / OIDC (SRS v3.3 §3.1, §7.4).
    """
    return await AuthService.google_auth(db, data)


@router.post("/refresh", response_model=TokenResponseSchema, status_code=status.HTTP_200_OK)
def refresh_token(data: RefreshTokenSchema, db: Session = Depends(get_db)):
    """
    Rotate refresh token and issue new access token (SRS v3.3 §7.4).
    """
    return AuthService.refresh(db, data.refresh_token)


@router.get("/verify-email", status_code=status.HTTP_200_OK)
def verify_email(token: str = Query(...), db: Session = Depends(get_db)):
    """
    Verify email address from emailed link (SRS v3.3 §6).
    """
    AuthService.verify_email(db, token)
    return {"status": "ok", "message": "Email verified successfully."}


@router.get("/me", response_model=UserResponseSchema, status_code=status.HTTP_200_OK)
def get_me(current_user: User = Depends(get_current_user)):
    """
    Get profile information of currently authenticated user.
    """
    return UserResponseSchema.model_validate(current_user)


@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(current_user: User = Depends(get_current_user)):
    """
    Log out active user session.
    """
    return {"status": "ok", "message": "Logged out successfully."}
