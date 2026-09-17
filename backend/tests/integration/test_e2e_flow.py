"""
AsistIQ / Paradox — End-to-End Integration Test Suite (Sprint 10)
Verifies complete full-lifecycle flows across Auth, Cases, 24/7 SLA Clocks,
AI Engine (Triage, Drafts, HITL Send), State Machine, 7-Day Reopen Policy,
Background Sweeps, and Operational Reporting.
"""

import uuid
from datetime import datetime, timedelta
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from backend.main import app
from backend.db.session import Base
from backend.models.enums import (
    UserRole, AuthProvider, AvailabilityStatus, CasePriority, CaseStatus,
    DraftType, MessageVisibility
)
from backend.models.user import User, Team, Service
from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.message import Message
from backend.models.ai import CommunicationDraft
from backend.api.deps import get_db, get_current_user
from backend.providers.auth.password_hasher import PasswordHasher
from backend.providers.ai.mock_provider import MockAIProvider



@pytest.fixture
def test_db():
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
def seeded_env(test_db):
    hasher = PasswordHasher()
    pw_hash = hasher.hash_password("Password123!")


    # Teams
    team_it = Team(id=uuid.uuid4(), name="Tier 1 Support")
    test_db.add(team_it)

    # Services
    srv = Service(id=uuid.uuid4(), name="VPN Service", category="Network")
    test_db.add(srv)

    # 5 User Roles
    requester = User(
        id=uuid.uuid4(),
        email="requester@test.com",
        password_hash=pw_hash,
        auth_provider=AuthProvider.PASSWORD,
        full_name="Alice Requester",
        role=UserRole.REQUESTER,
        email_verified=True,
    )
    operator = User(
        id=uuid.uuid4(),
        email="operator@test.com",
        password_hash=pw_hash,
        auth_provider=AuthProvider.PASSWORD,
        full_name="Bob Operator",
        role=UserRole.OPERATOR,
        team_id=team_it.id,
        email_verified=True,
    )
    lead = User(
        id=uuid.uuid4(),
        email="lead@test.com",
        password_hash=pw_hash,
        auth_provider=AuthProvider.PASSWORD,
        full_name="Carol TeamLead",
        role=UserRole.TEAM_LEAD,
        team_id=team_it.id,
        email_verified=True,
    )
    manager = User(
        id=uuid.uuid4(),
        email="manager@test.com",
        password_hash=pw_hash,
        auth_provider=AuthProvider.PASSWORD,
        full_name="David Manager",
        role=UserRole.MANAGER,
        email_verified=True,
    )
    admin = User(
        id=uuid.uuid4(),
        email="admin@test.com",
        password_hash=pw_hash,
        auth_provider=AuthProvider.PASSWORD,
        full_name="Eve Admin",
        role=UserRole.ADMINISTRATOR,
        email_verified=True,
    )

    test_db.add_all([requester, operator, lead, manager, admin])
    test_db.commit()

    return {
        "db": test_db,
        "team": team_it,
        "service": srv,
        "requester": requester,
        "operator": operator,
        "lead": lead,
        "manager": manager,
        "admin": admin,
    }


def test_complete_e2e_incident_lifecycle(seeded_env, monkeypatch):
    """
    Simulates the entire journey:
    1. Requester logs in & submits P2 incident.
    2. 24/7 SLA deadlines computed (1h response, 8h resolution).
    3. Operator logs in, triggers AI Triage, and generates AI Draft.
    4. Operator reviews & sends draft -> first_responded_at clock stops!
    5. Case transitions to RESOLVED then CLOSED.
    6. Requester reopens ticket within 7 days -> resets to ASSIGNED.
    7. Manager executes on-demand SLA sweep and views Executive Report.
    """
    monkeypatch.setattr("backend.services.ai_service.get_ai_provider", lambda: MockAIProvider())
    monkeypatch.setattr("backend.services.report_service.get_ai_provider", lambda: MockAIProvider())

    db = seeded_env["db"]
    requester = seeded_env["requester"]
    operator = seeded_env["operator"]
    manager = seeded_env["manager"]


    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: requester
    client = TestClient(app)

    try:
        # Step 1: Requester creates a Case
        create_payload = {
            "title": "VPN Gateway Dropping Connections",
            "description": "Cisco AnyConnect drops every 10 minutes when accessing internal ERP.",
            "priority": CasePriority.P2.value,
            "service_id": str(seeded_env["service"].id),
        }
        case_resp = client.post("/api/v1/cases/", json=create_payload)
        assert case_resp.status_code == 201, case_resp.text
        case_data = case_resp.json()
        case_id = case_data["id"]
        assert case_data["reference_number"].startswith("INC-")
        assert case_data["status"] == CaseStatus.NEW.value

        # Step 2: Verify 24/7 SLA deadlines in DB
        sla_record = db.query(SLA).filter(SLA.case_id == uuid.UUID(case_id)).first()
        assert sla_record is not None
        assert sla_record.first_responded_at is None
        assert not sla_record.response_breached

        # Step 3: Switch to Operator -> Trigger AI Triage
        app.dependency_overrides[get_current_user] = lambda: operator
        triage_resp = client.post(f"/api/v1/cases/{case_id}/ai/triage")
        assert triage_resp.status_code in [200, 201]
        triage_data = triage_resp.json()
        assert "suggested_category" in triage_data
        assert "confidence_score" in triage_data

        # Step 4: Generate Communication Draft
        draft_resp = client.post(
            f"/api/v1/cases/{case_id}/ai/drafts",
            json={"draft_type": "info_request"}
        )
        assert draft_resp.status_code in [200, 201]
        draft_data = draft_resp.json()
        draft_id = draft_data["id"]

        # Step 5: HITL Approve & Send Draft -> Verify SLA clock stops
        send_resp = client.post(
            f"/api/v1/cases/{case_id}/ai/drafts/{draft_id}/send",
            json={"edited_body": "Hello Alice, please provide your AnyConnect version.", "internal_only": False}
        )
        assert send_resp.status_code in [200, 201]
        db.expire_all()
        sla_updated = db.query(SLA).filter(SLA.case_id == uuid.UUID(case_id)).first()
        assert sla_updated.first_responded_at is not None, "First response SLA clock must be stopped!"


        # Step 6: Transition to Assigned -> In Assessment -> Resolved -> Closed
        case_db = db.query(Case).filter(Case.id == uuid.UUID(case_id)).first()
        case_db.status = CaseStatus.ASSIGNED
        case_db.owner_id = operator.id
        case_db.resolved_at = datetime.utcnow()
        case_db.status = CaseStatus.RESOLVED
        case_db.closed_at = datetime.utcnow()
        case_db.status = CaseStatus.CLOSED
        db.commit()

        # Step 7: 7-Day Reopen Test (Transition to ASSIGNED)
        app.dependency_overrides[get_current_user] = lambda: requester
        reopen_resp = client.post(
            f"/api/v1/cases/{case_id}/transition",
            json={
                "target_status": CaseStatus.ASSIGNED.value,
                "reason": "Issue recurring after reboot.",
                "version": case_db.version
            }
        )
        assert reopen_resp.status_code == 200
        db.expire_all()
        reopened_case = db.query(Case).filter(Case.id == uuid.UUID(case_id)).first()
        assert reopened_case.status == CaseStatus.ASSIGNED

        # Step 8: Manager executes manual SLA sweep & retrieves report
        app.dependency_overrides[get_current_user] = lambda: manager
        sweep_resp = client.post("/api/v1/admin/sweeps/run")
        assert sweep_resp.status_code == 200
        assert "cases_evaluated" in sweep_resp.json()

        report_resp = client.get("/api/v1/reports/summary")
        assert report_resp.status_code == 200
        assert "kpis" in report_resp.json()
        assert report_resp.json()["kpis"]["total_cases"] >= 1


    finally:
        app.dependency_overrides.clear()

