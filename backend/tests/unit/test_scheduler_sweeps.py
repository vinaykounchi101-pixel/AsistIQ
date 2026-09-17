import uuid
from datetime import datetime, timedelta
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.db.session import Base
from backend.models.user import User
from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.ai import CaseRiskAssessment, EscalationEvent
from backend.models.enums import (
    CasePriority, CaseStatus, CaseType, EscalationStatus,
    EscalationTriggerReason, RiskLevel, UserRole
)
from backend.services.risk_service import RiskScoringService
from backend.services.sweep_service import SweepService
from backend.repositories.sweep_repository import SweepRepository


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def test_users(db_session):
    requester = User(
        id=uuid.uuid4(),
        email="requester@test.com",
        full_name="Alice Requester",
        role=UserRole.REQUESTER,
        email_verified=True,
    )
    operator = User(
        id=uuid.uuid4(),
        email="operator@test.com",
        full_name="Bob Operator",
        role=UserRole.OPERATOR,
        email_verified=True,
    )
    manager = User(
        id=uuid.uuid4(),
        email="manager@test.com",
        full_name="Carol Manager",
        role=UserRole.MANAGER,
        email_verified=True,
    )
    db_session.add_all([requester, operator, manager])
    db_session.commit()
    return {"requester": requester, "operator": operator, "manager": manager}


# --- 1. SLA Breach Detection in Sweep Tests ---

def test_sla_response_and_resolve_breach_detection(db_session, test_users):
    now = datetime(2026, 1, 1, 12, 0, 0)

    # Case 1: Past response deadline without response
    case1 = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000101",
        title="Email Service Down",
        description="Cannot send external email.",
        type=CaseType.INCIDENT,
        priority=CasePriority.P1,
        status=CaseStatus.NEW,
        requester_id=test_users["requester"].id,
    )
    sla1 = SLA(
        id=uuid.uuid4(),
        case_id=case1.id,
        target_response_at=now - timedelta(minutes=10),  # Missed by 10 mins
        target_resolve_at=now + timedelta(hours=3),
        first_responded_at=None,
    )

    # Case 2: Past resolution deadline without resolution
    case2 = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000102",
        title="Payment Gateway Timeout",
        description="Checkout transactions failing.",
        type=CaseType.INCIDENT,
        priority=CasePriority.P2,
        status=CaseStatus.ASSIGNED,
        requester_id=test_users["requester"].id,
        owner_id=test_users["operator"].id,
    )
    sla2 = SLA(
        id=uuid.uuid4(),
        case_id=case2.id,
        target_response_at=now - timedelta(hours=2),
        target_resolve_at=now - timedelta(minutes=5),  # Missed resolve
        first_responded_at=now - timedelta(hours=2, minutes=30),  # Responded on time
    )

    db_session.add_all([case1, sla1, case2, sla2])
    db_session.commit()

    # Execute Sweep
    summary = SweepService.execute_sweep(db=db_session, now=now)

    assert summary.cases_evaluated >= 2
    assert summary.sla_response_breaches == 1
    assert summary.sla_resolve_breaches == 1

    # Verify DB flag updates
    db_session.refresh(sla1)
    db_session.refresh(sla2)
    assert sla1.response_breached is True
    assert sla2.resolve_breached is True

    # Verify Auto-Escalation creation
    escalations1 = SweepRepository.get_escalations_by_case(db_session, case1.id)
    assert len(escalations1) >= 1
    assert escalations1[0].trigger_reason in [EscalationTriggerReason.MISSED_DEADLINE, EscalationTriggerReason.HIGH_RISK]


# --- 2. Deterministic Risk Scoring Tests ---

def test_risk_scoring_matrix():
    now = datetime(2026, 1, 1, 12, 0, 0)

    # 1. Low Risk Case: Fresh, assigned, plenty of SLA time
    case_low = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000201",
        title="Low priority inquiry",
        description="Question about software license.",
        priority=CasePriority.P4,
        status=CaseStatus.ASSIGNED,
        owner_id=uuid.uuid4(),
        created_at=now - timedelta(minutes=10),
        updated_at=now - timedelta(minutes=10),
    )
    case_low.sla = SLA(
        target_response_at=now + timedelta(hours=20),
        target_resolve_at=now + timedelta(hours=100),
    )
    level_low, signals_low = RiskScoringService.evaluate_case_risk(case_low, now=now)
    assert level_low == RiskLevel.LOW
    assert signals_low["inactivity_hours"] < 1.0

    # 2. Moderate Risk Case: Unassigned + moderate inactivity
    case_mod = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000202",
        title="Unassigned ticket",
        description="Needs triage assignment.",
        priority=CasePriority.P3,
        status=CaseStatus.NEW,
        owner_id=None,
        created_at=now - timedelta(hours=25),
        updated_at=now - timedelta(hours=25),
    )
    case_mod.sla = SLA(
        target_response_at=now + timedelta(hours=2),
        target_resolve_at=now + timedelta(hours=48),
    )
    level_mod, signals_mod = RiskScoringService.evaluate_case_risk(case_mod, now=now)
    assert level_mod == RiskLevel.MODERATE
    assert signals_mod["is_unassigned"] is True

    # 3. High Risk Case: Response Breached
    case_high = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000203",
        title="Missed initial response",
        description="Nobody picked this up.",
        priority=CasePriority.P2,
        status=CaseStatus.ASSIGNED,
        owner_id=uuid.uuid4(),
        created_at=now - timedelta(hours=2),
        updated_at=now - timedelta(hours=2),
    )
    case_high.sla = SLA(
        target_response_at=now - timedelta(minutes=30),  # Breached
        target_resolve_at=now + timedelta(hours=6),
        first_responded_at=None,
        response_breached=True,
    )
    level_high, signals_high = RiskScoringService.evaluate_case_risk(case_high, now=now)
    assert level_high == RiskLevel.HIGH

    # 4. Critical Risk Case: Resolution Breached
    case_crit = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000204",
        title="Major outage resolution breached",
        description="Still down.",
        priority=CasePriority.P1,
        status=CaseStatus.ASSIGNED,
        owner_id=uuid.uuid4(),
        created_at=now - timedelta(hours=5),
        updated_at=now - timedelta(hours=5),
    )
    case_crit.sla = SLA(
        target_response_at=now - timedelta(hours=4),
        target_resolve_at=now - timedelta(minutes=10),  # Resolve missed
        first_responded_at=now - timedelta(hours=4, minutes=50),
        resolve_breached=True,
    )
    level_crit, signals_crit = RiskScoringService.evaluate_case_risk(case_crit, now=now)
    assert level_crit == RiskLevel.CRITICAL


# --- 3. Auto-Escalation Deduplication Test ---

def test_auto_escalation_deduplication(db_session, test_users):
    now = datetime(2026, 1, 1, 12, 0, 0)
    case = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000301",
        title="Breaching Ticket",
        description="Ongoing issue.",
        priority=CasePriority.P1,
        status=CaseStatus.ASSIGNED,
        requester_id=test_users["requester"].id,
        owner_id=test_users["operator"].id,
        created_at=now - timedelta(hours=2),
        updated_at=now - timedelta(hours=2),
    )
    sla = SLA(
        id=uuid.uuid4(),
        case_id=case.id,
        target_response_at=now - timedelta(minutes=30),
        target_resolve_at=now + timedelta(hours=2),
        first_responded_at=None,
    )
    db_session.add_all([case, sla])
    db_session.commit()

    # Sweep 1: triggers escalation
    sum1 = SweepService.execute_sweep(db=db_session, now=now)
    assert sum1.escalations_triggered >= 1

    # Sweep 2: should NOT trigger duplicate escalation
    sum2 = SweepService.execute_sweep(db=db_session, now=now + timedelta(minutes=5))
    assert sum2.escalations_triggered == 0

    # Total open escalations in DB remains deduplicated
    escalations = SweepRepository.get_escalations_by_case(db_session, case.id)
    assert len(escalations) == 1


# --- 4. API Endpoints (Admin Sweeps & Case Risk/Escalations) ---

def test_admin_manual_sweep_and_case_risk_api(db_session, test_users):
    from fastapi.testclient import TestClient
    from backend.main import app
    from backend.api.deps import get_db, get_current_user

    case = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000401",
        title="API Test Case",
        description="Testing sweep endpoints.",
        priority=CasePriority.P2,
        status=CaseStatus.NEW,
        requester_id=test_users["requester"].id,
    )
    sla = SLA(
        id=uuid.uuid4(),
        case_id=case.id,
        target_response_at=datetime.utcnow() + timedelta(hours=1),
        target_resolve_at=datetime.utcnow() + timedelta(hours=8),
    )
    db_session.add_all([case, sla])
    db_session.commit()

    manager_id = test_users["manager"].id
    req_id = test_users["requester"].id

    def override_manager():
        return db_session.query(User).filter(User.id == manager_id).first()

    def override_requester():
        return db_session.query(User).filter(User.id == req_id).first()

    app.dependency_overrides[get_db] = lambda: db_session
    app.dependency_overrides[get_current_user] = override_manager

    client = TestClient(app)

    try:
        # 1. Trigger Manual Sweep via Admin API
        sweep_resp = client.post("/api/v1/admin/sweeps/run")
        assert sweep_resp.status_code == 200
        sweep_data = sweep_resp.json()
        assert "cases_evaluated" in sweep_data
        assert sweep_data["cases_evaluated"] >= 1

        # 2. Get Case Risk Assessment API
        risk_resp = client.get(f"/api/v1/cases/{case.id}/risk")
        assert risk_resp.status_code == 200
        risk_data = risk_resp.json()
        assert risk_data["case_id"] == str(case.id)
        assert "risk_level" in risk_data
        assert "signals" in risk_data

        # 3. Get Case Escalations API
        esc_resp = client.get(f"/api/v1/cases/{case.id}/escalations")
        assert esc_resp.status_code == 200
        assert isinstance(esc_resp.json(), list)

        # 4. RBAC Check: Requester cannot trigger manual sweep
        app.dependency_overrides[get_current_user] = override_requester
        forbidden_resp = client.post("/api/v1/admin/sweeps/run")
        assert forbidden_resp.status_code == 403

    finally:
        app.dependency_overrides.clear()
