import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import select, and_
from backend.models.user import User
from backend.models.enums import UserRole, AuthProvider, AvailabilityStatus


class UserRepository:
    @staticmethod
    def get_by_id(db: Session, user_id: uuid.UUID) -> Optional[User]:
        """Fetch active user by primary ID (SRS §7.10)."""
        stmt = select(User).where(and_(User.id == user_id, User.deleted_at.is_(None)))
        return db.execute(stmt).scalar_one_or_none()

    @staticmethod
    def get_by_email(db: Session, email: str) -> Optional[User]:
        """Fetch active user by email address."""
        stmt = select(User).where(and_(User.email == email.lower().strip(), User.deleted_at.is_(None)))
        return db.execute(stmt).scalar_one_or_none()

    @staticmethod
    def get_by_oauth_subject(db: Session, subject_id: str) -> Optional[User]:
        """Fetch active user by Google OAuth subject ID."""
        stmt = select(User).where(and_(User.oauth_subject_id == subject_id, User.deleted_at.is_(None)))
        return db.execute(stmt).scalar_one_or_none()

    @staticmethod
    def create(
        db: Session,
        email: str,
        full_name: str,
        password_hash: Optional[str] = None,
        auth_provider: AuthProvider = AuthProvider.PASSWORD,
        oauth_subject_id: Optional[str] = None,
        role: UserRole = UserRole.REQUESTER,
        site: Optional[str] = None,
        email_verified: bool = False
    ) -> User:
        """Create and persist a new user record."""
        user = User(
            email=email.lower().strip(),
            full_name=full_name.strip(),
            password_hash=password_hash,
            auth_provider=auth_provider,
            oauth_subject_id=oauth_subject_id,
            role=role,
            site=site,
            email_verified=email_verified,
            availability_status=AvailabilityStatus.AVAILABLE,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def update(db: Session, user: User, **kwargs) -> User:
        """Update fields on a user record."""
        for key, value in kwargs.items():
            if hasattr(user, key) and value is not None:
                setattr(user, key, value)
        user.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def soft_delete(db: Session, user_id: uuid.UUID) -> bool:
        """Soft delete a user record (SRS §7.10)."""
        user = UserRepository.get_by_id(db, user_id)
        if not user:
            return False
        user.deleted_at = datetime.utcnow()
        db.commit()
        return True

    @staticmethod
    def list_users(
        db: Session,
        skip: int = 0,
        limit: int = 50,
        role: Optional[UserRole] = None,
        team_id: Optional[uuid.UUID] = None
    ) -> List[User]:
        """List active users with optional filtering."""
        conditions = [User.deleted_at.is_(None)]
        if role:
            conditions.append(User.role == role)
        if team_id:
            conditions.append(User.team_id == team_id)

        stmt = select(User).where(and_(*conditions)).offset(skip).limit(limit)
        return list(db.execute(stmt).scalars().all())
