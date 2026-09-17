import os
from datetime import datetime
from typing import Optional
from sqlalchemy.orm import Session

from backend.providers.ai import get_ai_provider
from backend.providers.ai.base import AIProvider
from backend.repositories.report_repository import ReportRepository
from backend.schemas.report import (
    ExecutiveSummaryResponse, IncidentTrendReport, KPIOverview,
    SLAComplianceReport, TeamPerformanceReport
)

PROMPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ai", "prompts")


def _read_prompt(filename: str) -> str:
    path = os.path.join(PROMPTS_DIR, filename)
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class ReportService:
    """Business service for Manager/Admin Operational Insights and Executive AI Briefings."""

    @classmethod
    def get_executive_summary(
        cls,
        db: Session,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        provider: Optional[AIProvider] = None
    ) -> ExecutiveSummaryResponse:
        kpis = ReportRepository.get_kpi_overview(db, start_date=start_date, end_date=end_date)
        sla_comp = ReportRepository.get_sla_compliance(db, start_date=start_date, end_date=end_date)

        priority_strs = [
            f"{p.priority}: {p.total_count} cases ({p.resolution_compliance_pct}% compliance)"
            for p in sla_comp.by_priority
        ]
        priority_breakdown = ", ".join(priority_strs) if priority_strs else "No priority data recorded."

        period_str = "All Time"
        if start_date and end_date:
            period_str = f"{start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}"
        elif start_date:
            period_str = f"Since {start_date.strftime('%Y-%m-%d')}"

        ai = provider or get_ai_provider()
        template = _read_prompt("operational_summary_v1.txt")
        prompt = template.format(
            period=period_str,
            total_cases=kpis.total_cases,
            active_cases=kpis.active_cases,
            resolved_cases=kpis.resolved_cases,
            response_compliance_pct=kpis.response_compliance_pct,
            resolution_compliance_pct=kpis.resolution_compliance_pct,
            mttr_response_hours=kpis.mttr_response_hours,
            mttr_resolution_hours=kpis.mttr_resolution_hours,
            total_breached_cases=kpis.total_response_breaches + kpis.total_resolve_breaches,
            high_risk_cases=kpis.high_critical_risk_cases,
            priority_breakdown=priority_breakdown
        )

        ai_narrative = ai.generate_summary(prompt)

        return ExecutiveSummaryResponse(
            kpis=kpis,
            ai_narrative=ai_narrative,
            generated_at=datetime.utcnow()
        )

    @classmethod
    def get_sla_compliance(
        cls,
        db: Session,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> SLAComplianceReport:
        return ReportRepository.get_sla_compliance(db, start_date=start_date, end_date=end_date)

    @classmethod
    def get_team_performance(
        cls,
        db: Session,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> TeamPerformanceReport:
        return ReportRepository.get_team_and_operator_performance(db, start_date=start_date, end_date=end_date)

    @classmethod
    def get_trends(cls, db: Session, days: int = 14) -> IncidentTrendReport:
        return ReportRepository.get_incident_trends(db, days=days)
