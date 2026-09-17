import uuid
from datetime import datetime, timedelta
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.db.session import Base
from backend.models.user import User, Team
from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.ai import CaseRiskAssessment
from backend.models.enums import (
    CasePriority, CaseStatus, CaseType, RiskLevel, UserRole
)
from backend.providers.ai.mock_provider import MockAIProvider
from backend.repositories.report_repository import ReportRepository
from backend.services.report_service import ReportService


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
def test_setup(db_session):
    # Teams
    team_it = Team(id=uuid.uuid4(), name="IT Helpdesk")
    team_net = Team(id=uuid.uuid4(), name="Network Operations")
    db_session.add_all([team_it, team_net])

    # Users
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
        team_id=team_it.id,
        email_verified=True,
    )
    manager = User(
        id=uuid.uuid4(),
        email="manager@test.com",
        full_name="Carol Manager",
        role=UserRole.MANAGER,
        team_id=team_it.id,
        email_verified=True,
    )
    db_session.add_all([requester, operator, manager])
    db_session.commit()

    # Create test cases
    now = datetime(2026, 1, 1, 12, 0, 0)

    # Case 1: Resolved on time
    case1 = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000501",
        title="Password Reset",
        description="Cannot log in.",
        type=CaseType.SERVICE_REQUEST,
        priority=CasePriority.P3,
        status=CaseStatus.RESOLVED,
        requester_id=requester.id,
        owner_id=operator.id,
        team_id=team_it.id,
        created_at=now - timedelta(hours=5),
        resolved_at=now - timedelta(hours=3),  # 2 hours resolution
    )
    sla1 = SLA(
        id=uuid.uuid4(),
        case_id=case1.id,
        target_response_at=now - timedelta(hours=4),
        target_resolve_at=now + timedelta(hours=20),
        first_responded_at=now - timedelta(hours=4, minutes=30),  # 30 min response
        response_breached=False,
        resolve_breached=False,
    )

    # Case 2: Resolved with breach
    case2 = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000502",
        title="VPN Gateway Outage",
        description="Network tunnel dropped.",
        type=CaseType.INCIDENT,
        priority=CasePriority.P1,
        status=CaseStatus.CLOSED,
        requester_id=requester.id,
        owner_id=operator.id,
        team_id=team_net.id,
        created_at=now - timedelta(hours=10),
        resolved_at=now - timedelta(hours=2),  # 8 hours resolution
    )
    sla2 = SLA(
        id=uuid.uuid4(),
        case_id=case2.id,
        target_response_at=now - timedelta(hours=9, minutes=45),
        target_resolve_at=now - timedelta(hours=6),
        first_responded_at=now - timedelta(hours=9),  # 1 hour response (breached 15m target)
        response_breached=True,
        resolve_breached=True,
    )

    # Case 3: Active high risk case
    case3 = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000503",
        title="Database Latency",
        description="Slow queries on billing db.",
        type=CaseType.INCIDENT,
        priority=CasePriority.P2,
        status=CaseStatus.ASSIGNED,
        requester_id=requester.id,
        owner_id=operator.id,
        team_id=team_it.id,
        created_at=now - timedelta(hours=1),
    )
    sla3 = SLA(
        id=uuid.uuid4(),
        case_id=case3.id,
        target_response_at=now - timedelta(minutes=10),
        target_resolve_at=now + timedelta(hours=7),
        first_responded_at=None,
        response_breached=True,
    )
    risk3 = CaseRiskAssessment(
        id=uuid.uuid4(),
        case_id=case3.id,
        risk_level=RiskLevel.HIGH,
        signals={"inactivity_hours": 1.0, "response_breached": True},
        computed_at=now
    )

    db_session.add_all([case1, sla1, case2, sla2, case3, sla3, risk3])
    db_session.commit()

    return {
        "requester": requester,
        "operator": operator,
        "manager": manager,
        "team_it": team_it,
        "team_net": team_net,
        "case1": case1,
        "case2": case2,
        "case3": case3,
    }


# --- 1. SQL Aggregation Unit Tests ---

def test_kpi_overview_calculations(db_session, test_setup):
    kpis = ReportRepository.get_kpi_overview(db_session)

    assert kpis.total_cases == 3
    assert kpis.active_cases == 1
    assert kpis.resolved_cases == 2
    assert kpis.total_response_breaches == 2
    assert kpis.total_resolve_breaches == 1
    assert kpis.high_critical_risk_cases == 1

    # MTTR calculations
    assert kpis.mttr_response_hours > 0.0
    assert kpis.mttr_resolution_hours == 5.0  # (2h + 8h) / 2


def test_sla_compliance_by_priority(db_session, test_setup):
    compliance = ReportRepository.get_sla_compliance(db_session)

    assert len(compliance.by_priority) == 4
    # P1 breakdown
    p1 = next(p for p in compliance.by_priority if "P1" in p.priority)
    assert p1.total_count == 1
    assert p1.response_breached_count == 1
    assert p1.resolve_breached_count == 1
    assert p1.resolution_compliance_pct == 0.0

    # P3 breakdown
    p3 = next(p for p in compliance.by_priority if "P3" in p.priority)
    assert p3.total_count == 1
    assert p3.response_breached_count == 0
    assert p3.resolution_compliance_pct == 100.0


def test_team_and_operator_performance(db_session, test_setup):
    perf = ReportRepository.get_team_and_operator_performance(db_session)

    assert len(perf.teams) >= 2
    assert len(perf.operators) >= 1

    op = perf.operators[0]
    assert op.total_assigned == 3
    assert op.resolved_count == 2
    assert op.avg_resolution_hours == 5.0


def test_incident_trends(db_session, test_setup):
    trends = ReportRepository.get_incident_trends(db_session, days=7)
    assert trends.granularity == "daily"
    assert len(trends.data_points) >= 7


# --- 2. Executive Summary AI Briefing Service Test ---

def test_executive_summary_service_with_mock_ai(db_session, test_setup):
    provider = MockAIProvider()
    resp = ReportService.get_executive_summary(db=db_session, provider=provider)

    assert resp.kpis.total_cases == 3
    assert resp.ai_narrative is not None
    assert len(resp.ai_narrative) > 10


# --- 3. Reports API Endpoints & Role Authorization Tests ---

def test_reports_api_endpoints_and_rbac(db_session, test_setup):
    from fastapi.testclient import TestClient
    from backend.main import app
    from backend.api.deps import get_db, get_current_user

    manager_id = test_setup["manager"].id
    operator_id = test_setup["operator"].id
    requester_id = test_setup["requester"].id

    def override_manager():
        return db_session.query(User).filter(User.id == manager_id).first()

    def override_operator():
        return db_session.query(User).filter(User.id == operator_id).first()

    def override_requester():
        return db_session.query(User).filter(User.id == requester_id).first()

    app.dependency_overrides[get_db] = lambda: db_session
    app.dependency_overrides[get_current_user] = override_manager

    client = TestClient(app)

    try:
        # 1. Executive Summary API (Manager allowed)
        sum_resp = client.get("/api/v1/reports/summary")
        assert sum_resp.status_code == 200
        sum_data = sum_resp.json()
        assert "kpis" in sum_data
        assert "ai_narrative" in sum_data
        assert sum_data["kpis"]["total_cases"] == 3

        # 2. SLA Compliance API
        sla_resp = client.get("/api/v1/reports/sla-compliance")
        assert sla_resp.status_code == 200
        assert "by_priority" in sla_resp.json()

        # 3. Team Performance API
        team_resp = client.get("/api/v1/reports/team-performance")
        assert team_resp.status_code == 200
        assert "teams" in team_resp.json()

        # 4. Trends API
        trends_resp = client.get("/api/v1/reports/trends?days=7")
        assert trends_resp.status_code == 200
        assert len(trends_resp.json()["data_points"]) >= 7

        # 5. RBAC Check: Operator is blocked (403)
        app.dependency_overrides[get_current_user] = override_operator
        op_forbidden = client.get("/api/v1/reports/summary")
        assert op_forbidden.status_code == 403

        # 6. RBAC Check: Requester is blocked (403)
        app.dependency_overrides[get_current_user] = override_requester
        req_forbidden = client.get("/api/v1/reports/summary")
        assert req_forbidden.status_code == 403

    finally:
        app.dependency_overrides.clear()
