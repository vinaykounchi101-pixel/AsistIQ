from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict

from backend.models.enums import EscalationStatus, EscalationTriggerReason, RiskLevel


class RiskAssessmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    case_id: UUID
    risk_level: RiskLevel
    signals: Dict[str, Any]
    computed_at: datetime


class EscalationEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    case_id: UUID
    trigger_reason: EscalationTriggerReason
    escalated_to: str
    escalated_by: str
    status: EscalationStatus
    created_at: datetime


class SweepSummaryResponse(BaseModel):
    cases_evaluated: int
    sla_response_breaches: int
    sla_resolve_breaches: int
    high_critical_risk_cases: int
    escalations_triggered: int
    executed_at: datetime
