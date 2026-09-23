import uuid
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from backend.core.config import settings
from backend.models.user import User
from backend.models.enums import UserRole, AuthProvider
from backend.repositories.user_repository import UserRepository
from backend.providers.auth.password_hasher import PasswordHasher
from backend.providers.auth.jwt_provider import JWTProvider
from backend.providers.auth.google_oauth import GoogleOAuthProvider, GoogleUserProfile
from backend.providers.notifications.email_provider import get_notification_provider
from backend.schemas.auth import (
    UserCreateSchema, UserLoginSchema, GoogleLoginSchema,
    TokenResponseSchema, UserResponseSchema, AuthResponseSchema
)


class AuthService:
    @classmethod
    async def signup(cls, db: Session, data: UserCreateSchema) -> AuthResponseSchema:
        """Register a new password-based account (SRS v3.3 §3.3a, §6)."""
        existing_user = UserRepository.get_by_email(db, data.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "ACCOUNT_EXISTS",
                    "message": "An account with this email address already exists."
                }
            )

        hashed_password = PasswordHasher.hash_password(data.password)
        # Pre-verify accounts for seamless Phase 1 onboarding across multi-platform clients
        is_verified = True

        user = UserRepository.create(
            db=db,
            email=data.email,
            full_name=data.full_name,
            password_hash=hashed_password,
            auth_provider=AuthProvider.PASSWORD,
            role=data.role or UserRole.REQUESTER,
            site=data.site,
            email_verified=is_verified
        )

        # In production, dispatch verification email
        if not is_verified:
            verify_token = JWTProvider.create_verification_token(user.email)
            verify_url = f"http://{settings.HOST}:{settings.PORT}/api/v1/auth/verify-email?token={verify_token}"
            email_provider = get_notification_provider()
            await email_provider.send_email(
                to_email=user.email,
                subject="Verify your AsistIQ account",
                body_text=f"Welcome {user.full_name},\n\nPlease verify your email by clicking: {verify_url}\n\nThank you,\nAsistIQ Support",
                body_html=f"<p>Welcome <strong>{user.full_name}</strong>,</p><p>Please verify your email: <a href='{verify_url}'>Verify Account</a></p>"
            )

        tokens = cls._generate_token_bundle(user)
        return AuthResponseSchema(
            user=UserResponseSchema.model_validate(user),
            tokens=tokens
        )

    @classmethod
    def login(cls, db: Session, data: UserLoginSchema) -> AuthResponseSchema:
        """Authenticate user via password credentials (SRS v3.3 §7.4)."""
        user = UserRepository.get_by_email(db, data.email)
        if not user or not user.password_hash:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "code": "INVALID_CREDENTIALS",
                    "message": "Invalid email or password."
                }
            )

        if not PasswordHasher.verify_password(data.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "code": "INVALID_CREDENTIALS",
                    "message": "Invalid email or password."
                }
            )

        if settings.ENVIRONMENT != "local" and not user.email_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "EMAIL_NOT_VERIFIED",
                    "message": "Please verify your email address before logging in."
                }
            )

        tokens = cls._generate_token_bundle(user)
        return AuthResponseSchema(
            user=UserResponseSchema.model_validate(user),
            tokens=tokens
        )

    @classmethod
    async def google_auth(cls, db: Session, data: GoogleLoginSchema) -> AuthResponseSchema:
        """
        Authenticate or register user via Google OAuth 2.0 / OIDC (SRS v3.3 §3.1, §7.4).
        """
        profile: GoogleUserProfile
        if data.code:
            profile = await GoogleOAuthProvider.exchange_code_for_profile(data.code, data.redirect_uri)
        elif data.id_token:
            profile = await GoogleOAuthProvider.verify_id_token(data.id_token)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"code": "INVALID_REQUEST", "message": "Either 'code' or 'id_token' must be supplied."}
            )

        # 1. Lookup by oauth subject
        user = UserRepository.get_by_oauth_subject(db, profile.subject_id)
        if not user:
            # 2. Check email collision with password account
            existing_email_user = UserRepository.get_by_email(db, profile.email)
            if existing_email_user:
                if existing_email_user.auth_provider == AuthProvider.PASSWORD:
                    # Explicit conflict error to prevent account takeover (SRS §7.4)
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail={
                            "code": "AUTH_PROVIDER_CONFLICT",
                            "message": "An account with this email already exists with password login. Please log in with your password."
                        }
                    )
                user = existing_email_user
            else:
                # 3. Create new OAuth user (pre-verified by Google per SRS §3.3a / §6)
                user = UserRepository.create(
                    db=db,
                    email=profile.email,
                    full_name=profile.name,
                    password_hash=None,
                    auth_provider=AuthProvider.GOOGLE,
                    oauth_subject_id=profile.subject_id,
                    role=UserRole.REQUESTER,
                    email_verified=True,
                )

        tokens = cls._generate_token_bundle(user)
        return AuthResponseSchema(
            user=UserResponseSchema.model_validate(user),
            tokens=tokens
        )

    @classmethod
    def refresh(cls, db: Session, refresh_token: str) -> TokenResponseSchema:
        """Rotate refresh token and issue new access token (SRS v3.3 §7.4)."""
        try:
            payload = JWTProvider.decode_token(refresh_token)
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={"code": "INVALID_TOKEN", "message": str(e)}
            )

        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={"code": "INVALID_TOKEN_TYPE", "message": "Expected a refresh token."}
            )

        user_id = payload.get("sub")
        user = UserRepository.get_by_id(db, uuid.UUID(user_id))
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={"code": "USER_NOT_FOUND", "message": "User associated with token not found or deleted."}
            )

        return cls._generate_token_bundle(user)

    @classmethod
    def verify_email(cls, db: Session, token: str) -> bool:
        """Validate email verification token and mark account verified."""
        try:
            payload = JWTProvider.decode_token(token)
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"code": "INVALID_VERIFICATION_TOKEN", "message": str(e)}
            )

        if payload.get("type") != "email_verification":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"code": "INVALID_TOKEN_TYPE", "message": "Token is not an email verification token."}
            )

        email = payload.get("sub")
        user = UserRepository.get_by_email(db, email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "USER_NOT_FOUND", "message": "User not found."}
            )

        UserRepository.update(db, user, email_verified=True)
        return True

    @staticmethod
    def _generate_token_bundle(user: User) -> TokenResponseSchema:
        access_token = JWTProvider.create_access_token(
            subject=str(user.id),
            role=user.role.value,
            email=user.email
        )
        refresh_token = JWTProvider.create_refresh_token(subject=str(user.id))
        return TokenResponseSchema(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60
        )
