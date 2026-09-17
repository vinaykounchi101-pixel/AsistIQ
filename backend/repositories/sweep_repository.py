from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID
from sqlalchemy.orm import Session

from backend.models.ai import CaseRiskAssessment, EscalationEvent
from backend.models.case import Case
from backend.models.enums import (
    CaseStatus, EscalationStatus, EscalationTriggerReason, RiskLevel
)

TERMINAL_STATUSES = [
    CaseStatus.RESOLVED,
    CaseStatus.CLOSED,
    CaseStatus.CANCELLED,
]


class SweepRepository:
    """Data access layer for Background Sweeps, SLA Audits, and Escalations."""

    @staticmethod
    def get_active_cases(db: Session) -> List[Case]:
        return (
            db.query(Case)
            .filter(
                Case.deleted_at.is_(None),
                Case.status.notin_(TERMINAL_STATUSES)
            )
            .all()
        )

    @staticmethod
    def get_risk_assessment(db: Session, case_id: UUID) -> Optional[CaseRiskAssessment]:
        return db.query(CaseRiskAssessment).filter(CaseRiskAssessment.case_id == case_id).first()

    @staticmethod
    def upsert_risk_assessment(
        db: Session,
        case_id: UUID,
        risk_level: RiskLevel,
        signals: Dict[str, Any],
        commit: bool = True
    ) -> CaseRiskAssessment:
        existing = db.query(CaseRiskAssessment).filter(CaseRiskAssessment.case_id == case_id).first()
        if existing:
            existing.risk_level = risk_level
            existing.signals = signals
            existing.computed_at = datetime.utcnow()
            result = existing
        else:
            result = CaseRiskAssessment(
                case_id=case_id,
                risk_level=risk_level,
                signals=signals,
                computed_at=datetime.utcnow()
            )
            db.add(result)

        if commit:
            db.commit()
            db.refresh(result)
        return result

    @staticmethod
    def get_escalations_by_case(db: Session, case_id: UUID) -> List[EscalationEvent]:
        return (
            db.query(EscalationEvent)
            .filter(EscalationEvent.case_id == case_id)
            .order_by(EscalationEvent.created_at.desc())
            .all()
        )

    @staticmethod
    def has_active_escalation(
        db: Session,
        case_id: UUID,
        reason: EscalationTriggerReason
    ) -> bool:
        """
        Deduplication check: Prevents duplicate open escalation events for the same trigger reason.
        """
        existing = (
            db.query(EscalationEvent)
            .filter(
                EscalationEvent.case_id == case_id,
                EscalationEvent.trigger_reason == reason,
                EscalationEvent.status == EscalationStatus.OPEN
            )
            .first()
        )
        return existing is not None

    @staticmethod
    def create_escalation(
        db: Session,
        case_id: UUID,
        trigger_reason: EscalationTriggerReason,
        escalated_to: str,
        escalated_by: str = "system",
        commit: bool = True
    ) -> EscalationEvent:
        event = EscalationEvent(
            case_id=case_id,
            trigger_reason=trigger_reason,
            escalated_to=escalated_to,
            escalated_by=escalated_by,
            status=EscalationStatus.OPEN
        )
        db.add(event)
        if commit:
            db.commit()
            db.refresh(event)
        return event
