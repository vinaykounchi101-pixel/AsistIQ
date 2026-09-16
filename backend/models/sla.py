import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, DateTime, Enum, ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from backend.db.session import Base
from backend.models.enums import ApprovalDecision


class SLA(Base):
    __tablename__ = "slas"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), unique=True, nullable=False)
    target_response_at = Column(DateTime, nullable=False, index=True)
    target_resolve_at = Column(DateTime, nullable=False, index=True)
    first_responded_at = Column(DateTime, nullable=True)
    response_breached = Column(Boolean, default=False, nullable=False, index=True)
    resolve_breached = Column(Boolean, default=False, nullable=False, index=True)
    paused_reason = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    case = relationship("Case", back_populates="sla")


class Approval(Base):
    __tablename__ = "approvals"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), nullable=False, index=True)
    approver_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    decision = Column(Enum(ApprovalDecision), default=ApprovalDecision.PENDING, nullable=False)
    reason = Column(String(500), nullable=True)
    decided_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    case = relationship("Case", back_populates="approvals")
    approver = relationship("User")
