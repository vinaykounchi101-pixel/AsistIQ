from passlib.context import CryptContext
from backend.core.config import settings

# Configure passlib CryptContext
# Supports argon2 as default and bcrypt as fallback
pwd_context = CryptContext(
    schemes=["argon2", "bcrypt"],
    deprecated="auto",
    argon2__memory_cost=8192 if settings.ENVIRONMENT == "local" else 19456,  # 8 MiB local, 19 MiB prod (SRS §3.3a / §7.4)
    argon2__rounds=1 if settings.ENVIRONMENT == "local" else 2,             # 1 iteration local, 2 iterations prod
    argon2__parallelism=1,
)


class PasswordHasher:
    @staticmethod
    def hash_password(password: str) -> str:
        """Hash a plaintext password using Argon2id."""
        return pwd_context.hash(password)

    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify a plaintext password against an Argon2id hash."""
        if not hashed_password:
            return False
        return pwd_context.verify(plain_password, hashed_password)
