import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Text, Boolean, Integer, DateTime, Enum, ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from backend.db.session import Base
from backend.models.enums import MessageVisibility


class Message(Base):
    __tablename__ = "messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), nullable=False, index=True)
    author_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    body = Column(Text, nullable=False)
    visibility = Column(Enum(MessageVisibility), default=MessageVisibility.REQUESTER_VISIBLE, nullable=False, index=True)
    ai_generated = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    # Relationships
    case = relationship("Case", back_populates="messages")
    author = relationship("User", back_populates="messages")


class Attachment(Base):
    __tablename__ = "attachments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="CASCADE"), nullable=False, index=True)
    uploaded_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    storage_path = Column(String(500), nullable=False)  # Supabase Storage path
    file_name = Column(String(255), nullable=False)
    file_type = Column(String(100), nullable=False)
    size_bytes = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    case = relationship("Case", back_populates="attachments")
    uploader = relationship("User", back_populates="attachments")
