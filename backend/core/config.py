import os
from typing import List, Literal, Optional
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ROOT_DIR = os.path.dirname(_BACKEND_DIR)

_CUSTOM_ENV = os.environ.get("ENV_FILE")
_ENV_TYPE = os.environ.get("ENVIRONMENT", "local")

if _CUSTOM_ENV:
    _CANDIDATES = [
        _CUSTOM_ENV,
        os.path.join(_BACKEND_DIR, _CUSTOM_ENV),
        os.path.join(_ROOT_DIR, _CUSTOM_ENV),
        os.path.join(_BACKEND_DIR, f"{_CUSTOM_ENV}.txt"),
        os.path.join(_BACKEND_DIR, ".env.prod.txt"),
    ]
elif _ENV_TYPE in ("production", "staging"):
    _CANDIDATES = [
        os.path.join(_BACKEND_DIR, ".env.prod"),
        os.path.join(_BACKEND_DIR, ".env.prod.txt"),
        os.path.join(_ROOT_DIR, ".env.prod"),
        os.path.join(_ROOT_DIR, ".env.prod.txt"),
    ]
else:
    _CANDIDATES = []

_MATCHED_CUSTOM = next((p for p in _CANDIDATES if p and os.path.exists(p)), None)

if _MATCHED_CUSTOM:
    _ENV_FILES = (_MATCHED_CUSTOM,)
else:
    _ENV_FILES = (
        os.path.join(_BACKEND_DIR, ".env"),
        os.path.join(_ROOT_DIR, ".env"),
        ".env",
        "backend/.env",
    )


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=_ENV_FILES,
        env_file_encoding="utf-8",
        extra="ignore"
    )



    # Core Environment
    ENVIRONMENT: Literal["local", "staging", "production"] = "local"

    @field_validator("ENVIRONMENT", mode="before")
    @classmethod
    def normalize_environment(cls, v: Optional[str]) -> str:
        if isinstance(v, str):
            val = v.strip().lower()
            if val in ("prod", "production"):
                return "production"
            if val in ("stage", "staging"):
                return "staging"
            if val in ("dev", "local", "development"):
                return "local"
        return v or "local"
    APP_NAME: str = "AsistIQ"
    API_V1_PREFIX: str = "/api/v1"
    PORT: int = 8000
    HOST: str = "0.0.0.0"

    # Database
    DATABASE_URL: str = Field(default="postgresql://postgres:postgres@localhost:5432/asistiq_db")

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def normalize_database_url(cls, v: Optional[str]) -> Optional[str]:
        if isinstance(v, str) and v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql://", 1)
        return v

    # JWT Authentication
    JWT_SECRET_KEY: str = Field(default="change-this-to-a-secure-random-32-plus-character-secret-key")
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24h local default, 15m in prod
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Google OAuth 2.0 / OIDC
    GOOGLE_OAUTH_CLIENT_ID: str = Field(default="mock-google-client-id")
    GOOGLE_OAUTH_CLIENT_SECRET: str = Field(default="mock-google-client-secret")
    GOOGLE_OAUTH_REDIRECT_URI: str = "http://localhost:8000/api/v1/auth/google/callback"

    # Gemini AI
    GEMINI_API_KEY: str = Field(default="mock-gemini-key")
    GEMINI_MODEL: str = Field(default="gemini-3.6-flash")

    # Supabase Storage
    SUPABASE_URL: str = Field(default="https://mock.supabase.co")
    SUPABASE_KEY: str = Field(default="mock-supabase-key")
    SUPABASE_STORAGE_BUCKET: str = "case-attachments"

    # CORS
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://127.0.0.1:3000,http://localhost:8000,http://127.0.0.1:8000,http://localhost:8080,http://127.0.0.1:8080"

    # Email - Local Dev (Gmail SMTP)
    GMAIL_SMTP_ADDRESS: Optional[str] = None
    GMAIL_SMTP_APP_PASSWORD: Optional[str] = None

    # Email - Staging & Production (Brevo HTTP API)
    BREVO_API_KEY: Optional[str] = None
    EMAIL_FROM_ADDRESS: str = "support@asistiq.com"
    EMAIL_FROM_NAME: str = "AsistIQ IT Support"

    @property
    def cors_origins(self) -> List[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]

    def validate_startup_secrets(self) -> None:
        """
        Validates that all required environment variables for the active environment
        are present and non-empty (SRS v3.3 §3.3). Fails fast if any are missing.
        """
        missing_vars: List[str] = []

        if not self.DATABASE_URL:
            missing_vars.append("DATABASE_URL")
        if not self.JWT_SECRET_KEY or self.JWT_SECRET_KEY.startswith("change-this"):
            if self.ENVIRONMENT != "local":
                missing_vars.append("JWT_SECRET_KEY")

        if not self.GEMINI_API_KEY or self.GEMINI_API_KEY.startswith("mock-"):
            if self.ENVIRONMENT != "local":
                missing_vars.append("GEMINI_API_KEY")

        if not self.GOOGLE_OAUTH_CLIENT_ID or self.GOOGLE_OAUTH_CLIENT_ID.startswith("mock-"):
            if self.ENVIRONMENT != "local":
                missing_vars.append("GOOGLE_OAUTH_CLIENT_ID")

        if not self.GOOGLE_OAUTH_CLIENT_SECRET or self.GOOGLE_OAUTH_CLIENT_SECRET.startswith("mock-"):
            if self.ENVIRONMENT != "local":
                missing_vars.append("GOOGLE_OAUTH_CLIENT_SECRET")

        if self.ENVIRONMENT == "local":
            # In local dev, either Gmail SMTP or mock is acceptable
            pass
        else:
            # Staging and Production MUST have BREVO_API_KEY
            if not self.BREVO_API_KEY:
                missing_vars.append("BREVO_API_KEY")

        if missing_vars:
            raise ValueError(
                f"[STARTUP ERROR] Missing or unconfigured required environment variables for environment '{self.ENVIRONMENT}': "
                f"{', '.join(missing_vars)}. Please populate them in the environment or .env file."
            )


settings = Settings()
