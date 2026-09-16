import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Text, DateTime, Enum, ForeignKey, JSON
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from backend.db.session import Base
from backend.models.enums import KnowledgeState


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    action = Column(String(100), nullable=False, index=True)  # e.g. case_created, priority_overridden, ai_triage_generated
    target_type = Column(String(50), nullable=False, index=True)  # e.g. Case, User, SLA
    target_id = Column(String(100), nullable=False, index=True)
    before_value = Column(JSON, nullable=True)
    after_value = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    # Relationships
    actor = relationship("User")


class KnowledgeArticle(Base):
    __tablename__ = "knowledge_articles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(255), nullable=False, index=True)
    body = Column(Text, nullable=False)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    state = Column(Enum(KnowledgeState), default=KnowledgeState.PUBLISHED, nullable=False, index=True)
    review_date = Column(DateTime, nullable=True)
    source_case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    owner = relationship("User")
    source_case = relationship("Case")
