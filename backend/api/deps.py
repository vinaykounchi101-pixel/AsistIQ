import uuid
from typing import List, Callable
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from backend.core.config import settings
from backend.db.session import get_db
from backend.models.user import User
from backend.models.enums import UserRole
from backend.repositories.user_repository import UserRepository
from backend.providers.auth.jwt_provider import JWTProvider

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_PREFIX}/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    """
    Extract and validate JWT access token, resolving active User (SRS v3.3 §7.6).
    """
    try:
        payload = JWTProvider.decode_token(token)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN", "message": str(e)},
            headers={"WWW-Authenticate": "Bearer"},
        )

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN_TYPE", "message": "Expected an access token."},
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN_PAYLOAD", "message": "Token missing subject claim."},
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = UserRepository.get_by_id(db, uuid.UUID(user_id_str))
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "USER_NOT_FOUND", "message": "User not found or deleted."},
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


def get_current_verified_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Ensure the current user's email has been verified before allowing access (SRS §6).
    """
    if settings.ENVIRONMENT != "local" and not current_user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "EMAIL_NOT_VERIFIED", "message": "Verified email required for this action."}
        )
    return current_user


def require_roles(*allowed_roles: UserRole) -> Callable[[User], User]:
    """
    RBAC Dependency factory enforcing role authorization (SRS v3.3 §2.2, §7.6).
    """
    def role_checker(current_user: User = Depends(get_current_verified_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "PERMISSION_DENIED",
                    "message": f"User role '{current_user.role.value}' does not have permission to perform this action."
                }
            )
        return current_user

    return role_checker
