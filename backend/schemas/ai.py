from datetime import datetime
from typing import Any, List, Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field

from backend.models.enums import ConfidenceLevel, DraftStatus, DraftType


class AITriageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    case_id: UUID
    suggested_category: Optional[str] = None
    suggested_severity: Optional[str] = None
    suggested_priority: Optional[str] = None
    confidence_level: ConfidenceLevel
    confidence_score: float = Field(..., ge=0.0, le=1.0)
    supporting_factors: List[str] = Field(default_factory=list)
    missing_info: List[str] = Field(default_factory=list)
    suggested_team: Optional[str] = None
    recommended_next_action: Optional[str] = None
    related_case_ids: List[Any] = Field(default_factory=list)
    created_at: datetime


class CaseSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    case_id: UUID
    summary_text: str
    last_source_message_id: Optional[UUID] = None
    updated_at: datetime


class DraftCreateRequest(BaseModel):
    draft_type: DraftType
    custom_instruction: Optional[str] = Field(
        None, max_length=1000, description="Optional custom guidance for the draft tone or specific details."
    )


class DraftResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    case_id: UUID
    draft_type: DraftType
    body: str
    status: DraftStatus
    reviewed_by: Optional[UUID] = None
    sent_message_id: Optional[UUID] = None
    created_at: datetime


class DraftSendRequest(BaseModel):
    edited_body: Optional[str] = Field(
        None, description="Optional final edits made by the operator/lead before sending."
    )
    internal_only: bool = Field(
        False, description="Whether the posted message is strictly for internal staff or requester visible."
    )
