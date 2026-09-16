from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from backend.core.config import settings

# Create database engine
# If using SQLite for testing or PostgreSQL for dev/prod:
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

# Session local factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

# Declarative base for ORM models
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency yielding a database session per request
    and ensuring cleanup on completion.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
