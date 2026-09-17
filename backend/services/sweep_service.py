import logging
from datetime import datetime
from typing import Optional
from sqlalchemy.orm import Session

from backend.audit.audit_service import AuditService
from backend.models.enums import (
    EscalationTriggerReason, RiskLevel, UserRole
)
from backend.repositories.sweep_repository import SweepRepository
from backend.schemas.sweep import SweepSummaryResponse
from backend.services.risk_service import RiskScoringService

logger = logging.getLogger(__name__)


class SweepService:
    """
    Periodic SLA & Risk Sweep Service (SRS v3.3 §4.3, §4.4, §7.1).
    Audits active cases, detects deadline breaches, recalculates risk scores, and triggers auto-escalations.
    """

    @classmethod
    def execute_sweep(
        cls,
        db: Session,
        now: Optional[datetime] = None,
        triggered_by: str = "system"
    ) -> SweepSummaryResponse:
        current_time = now or datetime.utcnow()
        active_cases = SweepRepository.get_active_cases(db)

        response_breaches = 0
        resolve_breaches = 0
        high_critical_cases = 0
        escalations_count = 0

        for case in active_cases:
            sla = case.sla
            escalation_needed = False
            escalation_reason = None
            escalate_to_role = "TeamLead"

            # 1. Evaluate SLA Response Target
            if sla and sla.target_response_at and not sla.first_responded_at:
                if current_time > sla.target_response_at:
                    if not sla.response_breached:
                        sla.response_breached = True
                        response_breaches += 1
                        AuditService.log_action(
                            db=db,
                            action="SLA_RESPONSE_BREACHED",
                            target_type="case",
                            target_id=str(case.id),
                            actor_id=None,
                            after_value={
                                "target_response_at": sla.target_response_at.isoformat(),
                                "breached_at": current_time.isoformat()
                            },
                            commit=False
                        )
                    escalation_needed = True
                    escalation_reason = EscalationTriggerReason.MISSED_DEADLINE
                    escalate_to_role = "TeamLead"

            # 2. Evaluate SLA Resolve Target
            if sla and sla.target_resolve_at and not case.resolved_at:
                if current_time > sla.target_resolve_at:
                    if not sla.resolve_breached:
                        sla.resolve_breached = True
                        resolve_breaches += 1
                        AuditService.log_action(
                            db=db,
                            action="SLA_RESOLVE_BREACHED",
                            target_type="case",
                            target_id=str(case.id),
                            actor_id=None,
                            after_value={
                                "target_resolve_at": sla.target_resolve_at.isoformat(),
                                "breached_at": current_time.isoformat()
                            },
                            commit=False
                        )
                    escalation_needed = True
                    escalation_reason = EscalationTriggerReason.MISSED_DEADLINE
                    escalate_to_role = "Manager"

            # 3. Evaluate Deterministic Risk Scoring
            risk_level, signals = RiskScoringService.evaluate_case_risk(case, now=current_time)
            SweepRepository.upsert_risk_assessment(
                db=db,
                case_id=case.id,
                risk_level=risk_level,
                signals=signals,
                commit=False
            )

            if risk_level in [RiskLevel.HIGH, RiskLevel.CRITICAL]:
                high_critical_cases += 1
                if not escalation_needed:
                    escalation_needed = True
                    escalation_reason = EscalationTriggerReason.HIGH_RISK
                    escalate_to_role = "Manager" if risk_level == RiskLevel.CRITICAL else "TeamLead"

            elif signals.get("approaching_resolve_deadline") or signals.get("approaching_response_deadline"):
                if not escalation_needed:
                    escalation_needed = True
                    escalation_reason = EscalationTriggerReason.APPROACHING_DEADLINE
                    escalate_to_role = "TeamLead"

            # 4. Trigger Auto-Escalation if warranted and deduplicated
            if escalation_needed and escalation_reason:
                if not SweepRepository.has_active_escalation(db, case.id, escalation_reason):
                    event = SweepRepository.create_escalation(
                        db=db,
                        case_id=case.id,
                        trigger_reason=escalation_reason,
                        escalated_to=escalate_to_role,
                        escalated_by=triggered_by,
                        commit=False
                    )
                    escalations_count += 1
                    AuditService.log_action(
                        db=db,
                        action="CASE_AUTO_ESCALATED",
                        target_type="case",
                        target_id=str(case.id),
                        actor_id=None,
                        after_value={
                            "escalation_id": str(event.id),
                            "reason": escalation_reason.value,
                            "escalated_to": escalate_to_role
                        },
                        commit=False
                    )

        db.commit()

        logger.info(
            f"Sweep completed at {current_time.isoformat()}: {len(active_cases)} cases evaluated, "
            f"{response_breaches} response breaches, {resolve_breaches} resolve breaches, "
            f"{high_critical_cases} high/crit cases, {escalations_count} auto-escalations triggered."
        )

        return SweepSummaryResponse(
            cases_evaluated=len(active_cases),
            sla_response_breaches=response_breaches,
            sla_resolve_breaches=resolve_breaches,
            high_critical_risk_cases=high_critical_cases,
            escalations_triggered=escalations_count,
            executed_at=current_time
        )
