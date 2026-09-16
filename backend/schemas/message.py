import uuid
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field, field_validator
import bleach
from backend.models.enums import MessageVisibility


class CreateMessageRequest(BaseModel):
    body: str = Field(..., min_length=1, max_length=10000, description="Message or internal note body text")
    visibility: MessageVisibility = Field(default=MessageVisibility.REQUESTER_VISIBLE, description="Visibility partition")

    @field_validator("body")
    @classmethod
    def sanitize_body(cls, v: str) -> str:
        cleaned = bleach.clean(v.strip(), tags=[], strip=True)
        if not cleaned:
            raise ValueError("Message body cannot be blank or contain only stripped HTML tags.")
        return cleaned


class MessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    case_id: uuid.UUID
    author_id: uuid.UUID
    author_name: Optional[str] = None
    author_role: Optional[str] = None
    body: str
    visibility: MessageVisibility
    ai_generated: bool
    created_at: datetime


class MessageListResponse(BaseModel):
    items: List[MessageResponse]
    total: int


class AttachmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    case_id: uuid.UUID
    uploaded_by: uuid.UUID
    uploader_name: Optional[str] = None
    file_name: str
    file_type: str
    size_bytes: int
    download_url: Optional[str] = None
    created_at: datetime


class AttachmentListResponse(BaseModel):
    items: List[AttachmentResponse]
    total_bytes_used: int
    quota_bytes: int
