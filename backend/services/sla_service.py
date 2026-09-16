from datetime import datetime, timedelta
from typing import Tuple, Optional
from backend.models.enums import CasePriority
from backend.models.sla import SLA


class SLAService:
    """
    24/7 Elapsed Wall-Clock SLA Calculation Engine (SRS v3.3 §4.3).
    All deadlines are computed from creation/reopen time in UTC.
    """

    # SLA Matrix: (Response Delta, Resolution Delta)
    SLA_MATRIX = {
        CasePriority.P1: (timedelta(minutes=15), timedelta(hours=4)),
        CasePriority.P2: (timedelta(hours=1), timedelta(hours=8)),
        CasePriority.P3: (timedelta(hours=4), timedelta(hours=72)),     # 3 days
        CasePriority.P4: (timedelta(hours=24), timedelta(hours=120)),   # 5 days
    }

    @classmethod
    def calculate_deadlines(
        cls,
        priority: CasePriority,
        start_time: Optional[datetime] = None
    ) -> Tuple[datetime, datetime]:
        """
        Calculate target response and resolution timestamps in UTC.
        """
        base_time = start_time or datetime.utcnow()
        response_delta, resolve_delta = cls.SLA_MATRIX.get(
            priority,
            (timedelta(hours=4), timedelta(hours=72))
        )
        target_response_at = base_time + response_delta
        target_resolve_at = base_time + resolve_delta
        return target_response_at, target_resolve_at

    @staticmethod
    def evaluate_breach_status(
        sla: SLA,
        now: Optional[datetime] = None
    ) -> Tuple[bool, bool]:
        """
        Evaluate whether the SLA response or resolution window is breached.
        """
        current_time = now or datetime.utcnow()
        response_breached = sla.response_breached
        resolve_breached = sla.resolve_breached

        # If not yet responded and target response time passed
        if not sla.first_responded_at and current_time > sla.target_response_at:
            response_breached = True

        # If target resolve time passed
        if current_time > sla.target_resolve_at:
            resolve_breached = True

        return response_breached, resolve_breached
