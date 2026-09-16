import uuid
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import jwt, JWTError
from backend.core.config import settings


class JWTProvider:
    @staticmethod
    def create_access_token(
        subject: str,
        role: str,
        email: str,
        expires_delta: Optional[timedelta] = None
    ) -> str:
        """Create a short-lived access token (SRS §7.4)."""
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)

        to_encode: Dict[str, Any] = {
            "sub": str(subject),
            "role": role,
            "email": email,
            "type": "access",
            "jti": str(uuid.uuid4()),
            "exp": expire,
            "iat": datetime.utcnow()
        }
        return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

    @staticmethod
    def create_refresh_token(
        subject: str,
        expires_delta: Optional[timedelta] = None
    ) -> str:
        """Create a revocable refresh token (SRS §7.4)."""
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS)

        to_encode: Dict[str, Any] = {
            "sub": str(subject),
            "type": "refresh",
            "jti": str(uuid.uuid4()),
            "exp": expire,
            "iat": datetime.utcnow()
        }
        return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

    @staticmethod
    def create_verification_token(email: str, expires_hours: int = 24) -> str:
        """Create a signed, time-limited token for email verification (SRS §6)."""
        expire = datetime.utcnow() + timedelta(hours=expires_hours)
        to_encode: Dict[str, Any] = {
            "sub": email,
            "type": "email_verification",
            "exp": expire,
            "iat": datetime.utcnow()
        }
        return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

    @staticmethod
    def decode_token(token: str) -> Dict[str, Any]:
        """Decode and validate a JWT token signature and expiry."""
        try:
            payload = jwt.decode(
                token,
                settings.JWT_SECRET_KEY,
                algorithms=[settings.JWT_ALGORITHM]
            )
            return payload
        except JWTError as e:
            raise ValueError(f"Invalid or expired token: {str(e)}")
