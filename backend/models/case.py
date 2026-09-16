import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Text, Integer, DateTime, Enum, ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from backend.db.session import Base
from backend.models.enums import CaseType, CaseStatus, CasePriority, CaseRelationshipType


class Case(Base):
    __tablename__ = "cases"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reference_number = Column(String(50), unique=True, nullable=False, index=True)
    type = Column(Enum(CaseType), default=CaseType.INCIDENT, nullable=False, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)  # Immutable original requester wording (SRS §4)
    status = Column(Enum(CaseStatus), default=CaseStatus.NEW, nullable=False, index=True)
    priority = Column(Enum(CasePriority), default=CasePriority.P3, nullable=False, index=True)
    
    requester_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True, index=True)
    service_id = Column(UUID(as_uuid=True), ForeignKey("services.id", ondelete="SET NULL"), nullable=True, index=True)
    site = Column(String(100), nullable=True, index=True)  # Inherited from requester at creation (SRS §4)

    version = Column(Integer, default=1, nullable=False)  # Optimistic concurrency locking (SRS §7.12)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    resolved_at = Column(DateTime, nullable=True)
    closed_at = Column(DateTime, nullable=True)
    deleted_at = Column(DateTime, nullable=True)  # Soft delete only (SRS §7.10)

    # Relationships
    requester = relationship("User", foreign_keys=[requester_id], back_populates="requested_cases")
    owner = relationship("User", foreign_keys=[owner_id], back_populates="owned_cases")
    assigned_team = relationship("Team", back_populates="cases")
    service = relationship("Service", back_populates="cases")
    messages = relationship("Message", back_populates="case", cascade="all, delete-orphan")
    attachments = relationship("Attachment", back_populates="case", cascade="all, delete-orphan")
    sla = relationship("SLA", back_populates="case", uselist=False, cascade="all, delete-orphan")
    triage_result = relationship("AITriageResult", back_populates="case", uselist=False, cascade="all, delete-orphan")
    summary = relationship("CaseSummary", back_populates="case", uselist=False, cascade="all, delete-orphan")
    risk_assessment = relationship("CaseRiskAssessment", back_populates="case", uselist=False, cascade="all, delete-orphan")
    escalations = relationship("EscalationEvent", back_populates="case", cascade="all, delete-orphan")
    communication_drafts = relationship("CommunicationDraft", back_populates="case", cascade="all, delete-orphan")
    approvals = relationship("Approval", back_populates="case", cascade="all, delete-orphan")


class CaseRelationship(Base):
    __tablename__ = "case_relationships"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), nullable=False, index=True)
    related_case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), nullable=False, index=True)
    relationship_type = Column(Enum(CaseRelationshipType), default=CaseRelationshipType.RELATED_TO, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
