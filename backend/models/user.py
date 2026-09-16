import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, DateTime, Enum, ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from backend.db.session import Base
from backend.models.enums import UserRole, AuthProvider, AvailabilityStatus


class Team(Base):
    __tablename__ = "teams"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), unique=True, nullable=False, index=True)
    description = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    members = relationship("User", back_populates="team")
    cases = relationship("Case", back_populates="assigned_team")


class Service(Base):
    __tablename__ = "services"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), unique=True, nullable=False, index=True)
    category = Column(String(100), nullable=False, index=True)
    description = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    cases = relationship("Case", back_populates="service")


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=True)  # Nullable for Google OAuth accounts (SRS §4)
    auth_provider = Column(Enum(AuthProvider), default=AuthProvider.PASSWORD, nullable=False)
    oauth_subject_id = Column(String(255), unique=True, nullable=True, index=True)  # Google sub claim
    full_name = Column(String(150), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.REQUESTER, nullable=False, index=True)
    team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True)
    site = Column(String(100), nullable=True, index=True)  # Feeds Smart Assignment (SRS §5.6)
    availability_status = Column(Enum(AvailabilityStatus), default=AvailabilityStatus.AVAILABLE, nullable=False)
    email_verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    deleted_at = Column(DateTime, nullable=True)  # Soft delete only (SRS §7.10)

    # Relationships
    team = relationship("Team", back_populates="members")
    owned_cases = relationship("Case", foreign_keys="Case.owner_id", back_populates="owner")
    requested_cases = relationship("Case", foreign_keys="Case.requester_id", back_populates="requester")
    messages = relationship("Message", back_populates="author")
    attachments = relationship("Attachment", back_populates="uploader")
