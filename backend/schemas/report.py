from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class KPIOverview(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    total_cases: int
    active_cases: int
    resolved_cases: int
    response_compliance_pct: float = Field(..., ge=0.0, le=100.0)
    resolution_compliance_pct: float = Field(..., ge=0.0, le=100.0)
    mttr_response_hours: float = Field(..., ge=0.0)
    mttr_resolution_hours: float = Field(..., ge=0.0)
    total_response_breaches: int
    total_resolve_breaches: int
    high_critical_risk_cases: int


class PrioritySLABreakdown(BaseModel):
    priority: str
    total_count: int
    responded_count: int
    response_breached_count: int
    response_compliance_pct: float
    resolved_count: int
    resolve_breached_count: int
    resolution_compliance_pct: float


class SLAComplianceReport(BaseModel):
    overall_response_compliance_pct: float
    overall_resolution_compliance_pct: float
    by_priority: List[PrioritySLABreakdown]


class TeamPerformanceItem(BaseModel):
    team_id: Optional[UUID] = None
    team_name: str
    total_assigned: int
    resolved_count: int
    breached_count: int
    avg_resolution_hours: float


class OperatorPerformanceItem(BaseModel):
    operator_id: UUID
    operator_name: str
    email: str
    total_assigned: int
    resolved_count: int
    breached_count: int
    avg_resolution_hours: float


class TeamPerformanceReport(BaseModel):
    teams: List[TeamPerformanceItem]
    operators: List[OperatorPerformanceItem]


class TrendDataPoint(BaseModel):
    date: str
    total_created: int
    resolved_count: int
    breached_count: int


class IncidentTrendReport(BaseModel):
    granularity: str
    data_points: List[TrendDataPoint]


class ExecutiveSummaryResponse(BaseModel):
    kpis: KPIOverview
    ai_narrative: str
    generated_at: datetime
