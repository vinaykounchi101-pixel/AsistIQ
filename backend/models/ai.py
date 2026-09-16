import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Text, Float, DateTime, Enum, ForeignKey, JSON
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from backend.db.session import Base
from backend.models.enums import (
    ConfidenceLevel, RiskLevel, EscalationTriggerReason,
    EscalationStatus, DraftType, DraftStatus
)


class AITriageResult(Base):
    __tablename__ = "ai_triage_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), unique=True, nullable=False)
    suggested_category = Column(String(100), nullable=True)
    suggested_severity = Column(String(50), nullable=True)
    suggested_priority = Column(String(50), nullable=True)
    confidence_level = Column(Enum(ConfidenceLevel), default=ConfidenceLevel.MODERATE, nullable=False)
    confidence_score = Column(Float, nullable=False)  # Internal only (SRS §4)
    supporting_factors = Column(JSON, default=list, nullable=False)  # List of supporting facts/reasons
    missing_info = Column(JSON, default=list, nullable=False)        # List of missing info questions
    suggested_team = Column(String(100), nullable=True)
    recommended_next_action = Column(String(255), nullable=True)
    related_case_ids = Column(JSON, default=list, nullable=False)    # Suggested duplicate/related case IDs
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    case = relationship("Case", back_populates="triage_result")


class CaseSummary(Base):
    __tablename__ = "case_summaries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), unique=True, nullable=False)
    summary_text = Column(Text, nullable=False)
    last_source_message_id = Column(UUID(as_uuid=True), nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    case = relationship("Case", back_populates="summary")


class CaseRiskAssessment(Base):
    __tablename__ = "case_risk_assessments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), unique=True, nullable=False)
    risk_level = Column(Enum(RiskLevel), default=RiskLevel.LOW, nullable=False, index=True)
    signals = Column(JSON, default=dict, nullable=False)  # inactivity_hours, follow_up_count, etc.
    computed_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    case = relationship("Case", back_populates="risk_assessment")


class EscalationEvent(Base):
    __tablename__ = "escalation_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), nullable=False, index=True)
    trigger_reason = Column(Enum(EscalationTriggerReason), nullable=False)
    escalated_to = Column(String(100), nullable=False)  # User ID or Role name
    escalated_by = Column(String(100), default="system", nullable=False)  # 'system' or user ID
    status = Column(Enum(EscalationStatus), default=EscalationStatus.OPEN, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    case = relationship("Case", back_populates="escalations")


class CommunicationDraft(Base):
    __tablename__ = "communication_drafts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), nullable=False, index=True)
    draft_type = Column(Enum(DraftType), nullable=False)
    body = Column(Text, nullable=False)
    status = Column(Enum(DraftStatus), default=DraftStatus.DRAFT, nullable=False)
    reviewed_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    sent_message_id = Column(UUID(as_uuid=True), ForeignKey("messages.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    case = relationship("Case", back_populates="communication_drafts")
    reviewer = relationship("User")
