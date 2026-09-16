import uuid
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field
from backend.models.enums import CaseType, CaseStatus, CasePriority


class BaseStrictSchema(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CaseCreateSchema(BaseStrictSchema):
    title: str = Field(min_length=3, max_length=200, description="Title ≤ 200 chars (SRS §7.2)")
    description: str = Field(min_length=5, max_length=10000, description="Description ≤ 10,000 chars (SRS §7.2)")
    type: CaseType = CaseType.INCIDENT
    priority: CasePriority = CasePriority.P3
    service_id: Optional[uuid.UUID] = None
    site: Optional[str] = None


class CaseUpdateSchema(BaseStrictSchema):
    version: int = Field(description="Optimistic locking version check (SRS §7.12)")
    title: Optional[str] = Field(default=None, min_length=3, max_length=200)
    priority: Optional[CasePriority] = None
    owner_id: Optional[uuid.UUID] = None
    team_id: Optional[uuid.UUID] = None
    service_id: Optional[uuid.UUID] = None
    site: Optional[str] = None


class CaseTransitionSchema(BaseStrictSchema):
    version: int = Field(description="Current version for optimistic locking")
    target_status: CaseStatus
    reason: Optional[str] = Field(default=None, max_length=500)


class SLAResponseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    target_response_at: datetime
    target_resolve_at: datetime
    first_responded_at: Optional[datetime] = None
    response_breached: bool
    resolve_breached: bool
    paused_reason: Optional[str] = None


class CaseResponseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    reference_number: str
    type: CaseType
    title: str
    description: str
    status: CaseStatus
    priority: CasePriority
    requester_id: uuid.UUID
    owner_id: Optional[uuid.UUID] = None
    team_id: Optional[uuid.UUID] = None
    service_id: Optional[uuid.UUID] = None
    site: Optional[str] = None
    version: int
    created_at: datetime
    updated_at: datetime
    resolved_at: Optional[datetime] = None
    closed_at: Optional[datetime] = None
    sla: Optional[SLAResponseSchema] = None


class CaseListResponseSchema(BaseStrictSchema):
    items: List[CaseResponseSchema]
    page: int
    page_size: int
    total: int
