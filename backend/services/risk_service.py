from datetime import datetime, timedelta
from typing import Any, Dict, Tuple
from sqlalchemy.orm import Session

from backend.models.case import Case
from backend.models.enums import CasePriority, RiskLevel
from backend.repositories.sweep_repository import SweepRepository


class RiskScoringService:
    """
    Deterministic Risk Scoring Engine (SRS v3.3 §4.3).
    Calculates multi-dimensional operational risk signals and determines categorical RiskLevel.
    """

    @staticmethod
    def evaluate_case_risk(case: Case, now: datetime = None) -> Tuple[RiskLevel, Dict[str, Any]]:
        current_time = now or datetime.utcnow()

        # 1. Inactivity evaluation
        last_activity = case.updated_at or case.created_at
        inactivity_delta = current_time - last_activity
        inactivity_hours = round(max(0.0, inactivity_delta.total_seconds() / 3600.0), 2)

        # 2. SLA Deadlines & Breach status
        sla = case.sla
        response_breached = bool(sla and sla.response_breached)
        resolve_breached = bool(sla and sla.resolve_breached)

        approaching_response = False
        approaching_resolve = False

        if sla:
            # Check response deadline warning
            if sla.target_response_at and not sla.first_responded_at:
                remaining_resp = sla.target_response_at - current_time
                # Approaching if < 30 mins remaining
                if timedelta(seconds=0) < remaining_resp <= timedelta(minutes=30):
                    approaching_response = True
                elif current_time > sla.target_response_at:
                    response_breached = True

            # Check resolve deadline warning
            if sla.target_resolve_at and not case.resolved_at:
                remaining_resolve = sla.target_resolve_at - current_time
                # Approaching if < 2 hours or < 20% remaining
                if timedelta(seconds=0) < remaining_resolve <= timedelta(hours=2):
                    approaching_resolve = True
                elif current_time > sla.target_resolve_at:
                    resolve_breached = True

        # 3. Assignment Status
        is_unassigned = case.owner_id is None

        # 4. Signals Dictionary
        signals = {
            "inactivity_hours": inactivity_hours,
            "is_unassigned": is_unassigned,
            "response_breached": response_breached,
            "resolve_breached": resolve_breached,
            "approaching_response_deadline": approaching_response,
            "approaching_resolve_deadline": approaching_resolve,
            "priority": case.priority.value if case.priority else "Unset",
        }

        # 5. Deterministic Risk Level Assessment (SRS §4.3)
        if resolve_breached or (response_breached and case.priority == CasePriority.P1) or (approaching_resolve and case.priority == CasePriority.P1):
            risk_level = RiskLevel.CRITICAL
        elif response_breached or approaching_resolve or (inactivity_hours >= 48.0 and is_unassigned):
            risk_level = RiskLevel.HIGH
        elif approaching_response or inactivity_hours >= 24.0 or is_unassigned:
            risk_level = RiskLevel.MODERATE
        else:
            risk_level = RiskLevel.LOW

        return risk_level, signals

    @classmethod
    def compute_and_persist(cls, db: Session, case: Case, now: datetime = None):
        risk_level, signals = cls.evaluate_case_risk(case, now=now)
        return SweepRepository.upsert_risk_assessment(
            db=db,
            case_id=case.id,
            risk_level=risk_level,
            signals=signals,
            commit=True
        )
