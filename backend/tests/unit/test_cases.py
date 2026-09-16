from datetime import datetime, timedelta
import pytest
from backend.models.enums import CasePriority, CaseStatus, CaseType
from backend.services.sla_service import SLAService
from backend.services.case_service import CaseService


def test_24_7_sla_calculation():
    start = datetime(2026, 1, 1, 12, 0, 0)

    # P1: 15m response, 4h resolution
    r1, res1 = SLAService.calculate_deadlines(CasePriority.P1, start)
    assert r1 == start + timedelta(minutes=15)
    assert res1 == start + timedelta(hours=4)

    # P2: 1h response, 8h resolution
    r2, res2 = SLAService.calculate_deadlines(CasePriority.P2, start)
    assert r2 == start + timedelta(hours=1)
    assert res2 == start + timedelta(hours=8)

    # P3: 4h response, 72h resolution
    r3, res3 = SLAService.calculate_deadlines(CasePriority.P3, start)
    assert r3 == start + timedelta(hours=4)
    assert res3 == start + timedelta(hours=72)

    # P4: 24h response, 120h resolution
    r4, res4 = SLAService.calculate_deadlines(CasePriority.P4, start)
    assert r4 == start + timedelta(hours=24)
    assert res4 == start + timedelta(hours=120)


def test_valid_state_transitions():
    assert CaseStatus.IN_ASSESSMENT in CaseService.VALID_TRANSITIONS[CaseStatus.NEW]
    assert CaseStatus.CANCELLED in CaseService.VALID_TRANSITIONS[CaseStatus.NEW]
    assert CaseStatus.ASSIGNED in CaseService.VALID_TRANSITIONS[CaseStatus.IN_ASSESSMENT]
    assert CaseStatus.RESOLVED in CaseService.VALID_TRANSITIONS[CaseStatus.ASSIGNED]
    assert CaseStatus.CLOSED in CaseService.VALID_TRANSITIONS[CaseStatus.RESOLVED]
    assert CaseStatus.ASSIGNED in CaseService.VALID_TRANSITIONS[CaseStatus.CLOSED]


def test_invalid_state_transitions():
    assert CaseStatus.CLOSED not in CaseService.VALID_TRANSITIONS[CaseStatus.NEW]
    assert CaseStatus.RESOLVED not in CaseService.VALID_TRANSITIONS[CaseStatus.NEW]
    assert CaseStatus.NEW not in CaseService.VALID_TRANSITIONS[CaseStatus.CANCELLED]
