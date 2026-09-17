from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy import func, and_, or_
from sqlalchemy.orm import Session

from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.user import User
from backend.models.user import Team
from backend.models.ai import CaseRiskAssessment
from backend.models.enums import (
    CasePriority, CaseStatus, RiskLevel, UserRole
)
from backend.schemas.report import (
    KPIOverview, OperatorPerformanceItem, PrioritySLABreakdown,
    SLAComplianceReport, TeamPerformanceItem, TeamPerformanceReport,
    TrendDataPoint, IncidentTrendReport
)

TERMINAL_STATUSES = [CaseStatus.RESOLVED, CaseStatus.CLOSED, CaseStatus.CANCELLED]
RESOLVED_STATUSES = [CaseStatus.RESOLVED, CaseStatus.CLOSED]


class ReportRepository:
    """High-efficiency SQL aggregation repository for Manager/Admin analytics."""

    @staticmethod
    def get_kpi_overview(
        db: Session,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> KPIOverview:
        case_query = db.query(Case).filter(Case.deleted_at.is_(None))
        if start_date:
            case_query = case_query.filter(Case.created_at >= start_date)
        if end_date:
            case_query = case_query.filter(Case.created_at <= end_date)

        all_cases = case_query.all()
        total_cases = len(all_cases)

        active_cases = sum(1 for c in all_cases if c.status not in TERMINAL_STATUSES)
        resolved_cases = sum(1 for c in all_cases if c.status in RESOLVED_STATUSES)

        # SLA calculations
        responded_cases = [c for c in all_cases if c.sla and c.sla.first_responded_at]
        response_breaches = sum(1 for c in all_cases if c.sla and c.sla.response_breached)
        
        response_compliance_pct = (
            round(((len(responded_cases) - response_breaches) / len(responded_cases)) * 100.0, 2)
            if responded_cases else 100.0
        )
        response_compliance_pct = max(0.0, min(100.0, response_compliance_pct))

        resolved_with_sla = [c for c in all_cases if c.status in RESOLVED_STATUSES and c.sla]
        resolve_breaches = sum(1 for c in all_cases if c.sla and c.sla.resolve_breached)

        resolution_compliance_pct = (
            round(((len(resolved_with_sla) - resolve_breaches) / len(resolved_with_sla)) * 100.0, 2)
            if resolved_with_sla else 100.0
        )
        resolution_compliance_pct = max(0.0, min(100.0, resolution_compliance_pct))

        # MTTR calculations in hours
        resp_durations = [
            (c.sla.first_responded_at - c.created_at).total_seconds() / 3600.0
            for c in responded_cases
            if c.sla.first_responded_at >= c.created_at
        ]
        mttr_response_hours = round(sum(resp_durations) / len(resp_durations), 2) if resp_durations else 0.0

        res_durations = [
            (c.resolved_at - c.created_at).total_seconds() / 3600.0
            for c in all_cases
            if c.resolved_at and c.resolved_at >= c.created_at
        ]
        mttr_resolution_hours = round(sum(res_durations) / len(res_durations), 2) if res_durations else 0.0

        # Risk metrics
        active_case_ids = [c.id for c in all_cases if c.status not in TERMINAL_STATUSES]
        high_critical_risk_cases = (
            db.query(CaseRiskAssessment)
            .filter(
                CaseRiskAssessment.case_id.in_(active_case_ids),
                CaseRiskAssessment.risk_level.in_([RiskLevel.HIGH, RiskLevel.CRITICAL])
            )
            .count()
            if active_case_ids else 0
        )

        return KPIOverview(
            total_cases=total_cases,
            active_cases=active_cases,
            resolved_cases=resolved_cases,
            response_compliance_pct=response_compliance_pct,
            resolution_compliance_pct=resolution_compliance_pct,
            mttr_response_hours=mttr_response_hours,
            mttr_resolution_hours=mttr_resolution_hours,
            total_response_breaches=response_breaches,
            total_resolve_breaches=resolve_breaches,
            high_critical_risk_cases=high_critical_risk_cases,
        )

    @staticmethod
    def get_sla_compliance(
        db: Session,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> SLAComplianceReport:
        case_query = db.query(Case).filter(Case.deleted_at.is_(None))
        if start_date:
            case_query = case_query.filter(Case.created_at >= start_date)
        if end_date:
            case_query = case_query.filter(Case.created_at <= end_date)

        all_cases = case_query.all()

        priorities = [CasePriority.P1, CasePriority.P2, CasePriority.P3, CasePriority.P4]
        breakdowns: List[PrioritySLABreakdown] = []

        total_resp_targets = 0
        total_resp_compliant = 0
        total_res_targets = 0
        total_res_compliant = 0

        for p in priorities:
            p_cases = [c for c in all_cases if c.priority == p]
            p_total = len(p_cases)

            p_responded = [c for c in p_cases if c.sla and c.sla.first_responded_at]
            p_resp_breached = sum(1 for c in p_cases if c.sla and c.sla.response_breached)
            p_resp_comp = (
                round(((len(p_responded) - p_resp_breached) / len(p_responded)) * 100.0, 2)
                if p_responded else 100.0
            )

            p_resolved = [c for c in p_cases if c.status in RESOLVED_STATUSES and c.sla]
            p_res_breached = sum(1 for c in p_cases if c.sla and c.sla.resolve_breached)
            p_res_comp = (
                round(((len(p_resolved) - p_res_breached) / len(p_resolved)) * 100.0, 2)
                if p_resolved else 100.0
            )

            total_resp_targets += len(p_responded)
            total_resp_compliant += (len(p_responded) - p_resp_breached)
            total_res_targets += len(p_resolved)
            total_res_compliant += (len(p_resolved) - p_res_breached)

            breakdowns.append(
                PrioritySLABreakdown(
                    priority=p.value,
                    total_count=p_total,
                    responded_count=len(p_responded),
                    response_breached_count=p_resp_breached,
                    response_compliance_pct=max(0.0, min(100.0, p_resp_comp)),
                    resolved_count=len(p_resolved),
                    resolve_breached_count=p_res_breached,
                    resolution_compliance_pct=max(0.0, min(100.0, p_res_comp)),
                )
            )

        overall_resp = (
            round((total_resp_compliant / total_resp_targets) * 100.0, 2)
            if total_resp_targets else 100.0
        )
        overall_res = (
            round((total_res_compliant / total_res_targets) * 100.0, 2)
            if total_res_targets else 100.0
        )

        return SLAComplianceReport(
            overall_response_compliance_pct=max(0.0, min(100.0, overall_resp)),
            overall_resolution_compliance_pct=max(0.0, min(100.0, overall_res)),
            by_priority=breakdowns
        )

    @staticmethod
    def get_team_and_operator_performance(
        db: Session,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> TeamPerformanceReport:
        case_query = db.query(Case).filter(Case.deleted_at.is_(None))
        if start_date:
            case_query = case_query.filter(Case.created_at >= start_date)
        if end_date:
            case_query = case_query.filter(Case.created_at <= end_date)

        all_cases = case_query.all()

        # 1. Team aggregations
        teams = db.query(Team).all()
        team_items: List[TeamPerformanceItem] = []
        for t in teams:
            t_cases = [c for c in all_cases if c.team_id == t.id]
            t_resolved = [c for c in t_cases if c.status in RESOLVED_STATUSES]
            t_breached = sum(1 for c in t_cases if c.sla and (c.sla.response_breached or c.sla.resolve_breached))
            
            res_hours = [
                (c.resolved_at - c.created_at).total_seconds() / 3600.0
                for c in t_resolved
                if c.resolved_at and c.resolved_at >= c.created_at
            ]
            avg_res = round(sum(res_hours) / len(res_hours), 2) if res_hours else 0.0

            team_items.append(
                TeamPerformanceItem(
                    team_id=t.id,
                    team_name=t.name,
                    total_assigned=len(t_cases),
                    resolved_count=len(t_resolved),
                    breached_count=t_breached,
                    avg_resolution_hours=avg_res
                )
            )

        # 2. Operator aggregations
        operators = (
            db.query(User)
            .filter(
                User.role.in_([UserRole.OPERATOR, UserRole.TEAM_LEAD]),
                User.deleted_at.is_(None)
            )
            .all()
        )
        operator_items: List[OperatorPerformanceItem] = []
        for op in operators:
            op_cases = [c for c in all_cases if c.owner_id == op.id]
            op_resolved = [c for c in op_cases if c.status in RESOLVED_STATUSES]
            op_breached = sum(1 for c in op_cases if c.sla and (c.sla.response_breached or c.sla.resolve_breached))

            res_hours = [
                (c.resolved_at - c.created_at).total_seconds() / 3600.0
                for c in op_resolved
                if c.resolved_at and c.resolved_at >= c.created_at
            ]
            avg_res = round(sum(res_hours) / len(res_hours), 2) if res_hours else 0.0

            operator_items.append(
                OperatorPerformanceItem(
                    operator_id=op.id,
                    operator_name=op.full_name,
                    email=op.email,
                    total_assigned=len(op_cases),
                    resolved_count=len(op_resolved),
                    breached_count=op_breached,
                    avg_resolution_hours=avg_res
                )
            )

        return TeamPerformanceReport(teams=team_items, operators=operator_items)

    @staticmethod
    def get_incident_trends(db: Session, days: int = 14) -> IncidentTrendReport:
        cutoff = datetime.utcnow() - timedelta(days=days)
        cases = (
            db.query(Case)
            .filter(Case.deleted_at.is_(None), Case.created_at >= cutoff)
            .order_by(Case.created_at.asc())
            .all()
        )

        # Group by Date string YYYY-MM-DD
        day_map = {}
        for i in range(days + 1):
            d_str = (cutoff + timedelta(days=i)).strftime("%Y-%m-%d")
            day_map[d_str] = {"created": 0, "resolved": 0, "breached": 0}

        for c in cases:
            c_date = c.created_at.strftime("%Y-%m-%d")
            if c_date in day_map:
                day_map[c_date]["created"] += 1
                if c.status in RESOLVED_STATUSES:
                    day_map[c_date]["resolved"] += 1
                if c.sla and (c.sla.response_breached or c.sla.resolve_breached):
                    day_map[c_date]["breached"] += 1

        points = [
            TrendDataPoint(
                date=k,
                total_created=v["created"],
                resolved_count=v["resolved"],
                breached_count=v["breached"]
            )
            for k, v in sorted(day_map.items())
        ]

        return IncidentTrendReport(granularity="daily", data_points=points)
