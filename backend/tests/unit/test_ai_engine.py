import uuid
from datetime import datetime
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.db.session import Base
from backend.models.user import User
from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.ai import AITriageResult, CaseSummary, CommunicationDraft
from backend.models.message import Message
from backend.models.enums import (
    UserRole, CasePriority, CaseStatus, CaseType,
    ConfidenceLevel, DraftStatus, DraftType, MessageVisibility
)
from backend.providers.ai.mock_provider import MockAIProvider
from backend.providers.ai.gemini_provider import GeminiAIProvider
from backend.services.ai_service import AIService
from backend.repositories.ai_repository import (
    AITriageRepository, CaseSummaryRepository, DraftRepository
)


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
        full_name="John Doe",
        role=UserRole.REQUESTER,
        email_verified=True,
    )
    operator = User(
        id=uuid.uuid4(),
        email="operator@test.com",
        full_name="Jane Operator",
        role=UserRole.OPERATOR,
        email_verified=True,
    )
    db_session.add_all([requester, operator])
    db_session.commit()
    return {"requester": requester, "operator": operator}


@pytest.fixture
def test_case(db_session, test_users):
    case = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000042",
        title="Production Database Connection Timeouts",
        description="Application microservices cannot acquire connection from PostgreSQL pool.",
        type=CaseType.INCIDENT,
        priority=CasePriority.P2,
        status=CaseStatus.NEW,
        requester_id=test_users["requester"].id,
    )
    sla = SLA(
        id=uuid.uuid4(),
        case_id=case.id,
        target_response_at=datetime.utcnow(),
        target_resolve_at=datetime.utcnow(),
    )
    db_session.add_all([case, sla])
    db_session.commit()
    return case


# --- 1. AI Intake Triage Tests ---

def test_ai_triage_generation_and_upsert(db_session, test_users, test_case):
    provider = MockAIProvider()
    result = AIService.triage_case(
        db=db_session,
        case_id=test_case.id,
        provider=provider,
        actor=test_users["operator"]
    )

    assert result.case_id == test_case.id
    assert result.suggested_category == "Software"
    assert result.suggested_severity == "High"
    assert result.suggested_priority == "P2 — High"
    assert result.confidence_level == ConfidenceLevel.HIGH
    assert result.confidence_score == 0.88
    assert len(result.supporting_factors) == 2
    assert len(result.missing_info) == 2
    assert result.suggested_team == "DevOps"

    # Verify persistence in DB
    db_triage = AITriageRepository.get_by_case_id(db_session, test_case.id)
    assert db_triage is not None
    assert db_triage.id == result.id


# --- 2. AI Continuous Summary Tests ---

def test_ai_continuous_summary_generation(db_session, test_users, test_case):
    # Add messages to the case
    msg1 = Message(
        id=uuid.uuid4(),
        case_id=test_case.id,
        author_id=test_users["requester"].id,
        body="Issue started at 10:15 UTC after the new deployment.",
        visibility=MessageVisibility.REQUESTER_VISIBLE,
        ai_generated=False
    )
    msg2 = Message(
        id=uuid.uuid4(),
        case_id=test_case.id,
        author_id=test_users["operator"].id,
        body="Checking max_connections on primary cluster.",
        visibility=MessageVisibility.INTERNAL_ONLY,
        ai_generated=False
    )
    db_session.add_all([msg1, msg2])
    db_session.commit()

    provider = MockAIProvider()
    summary = AIService.summarize_case(
        db=db_session,
        case_id=test_case.id,
        provider=provider,
        actor=test_users["operator"]
    )

    assert summary.case_id == test_case.id
    assert "Continuous Case Summary" in summary.summary_text
    assert summary.last_source_message_id == msg2.id

    # Verify persistence in DB
    db_summary = CaseSummaryRepository.get_by_case_id(db_session, test_case.id)
    assert db_summary is not None
    assert db_summary.summary_text == summary.summary_text


# --- 3. AI Communication Drafts & Human-in-the-Loop Review ---

def test_ai_draft_generation_and_hitl_send(db_session, test_users, test_case):
    provider = MockAIProvider()

    # Step 1: Generate Draft
    draft = AIService.generate_draft(
        db=db_session,
        case_id=test_case.id,
        draft_type=DraftType.INFO_REQUEST,
        custom_instruction="Ask if read replicas are impacted.",
        provider=provider,
        actor=test_users["operator"]
    )

    assert draft.case_id == test_case.id
    assert draft.draft_type == DraftType.INFO_REQUEST
    assert draft.status == DraftStatus.DRAFT
    assert "John" in draft.body

    # Step 2: Human-in-the-loop review, edit, and send
    edited_text = draft.body + "\nPS: Please also provide tenant IDs."
    sent_draft = AIService.send_draft(
        db=db_session,
        case_id=test_case.id,
        draft_id=draft.id,
        reviewer=test_users["operator"],
        edited_body=edited_text,
        internal_only=False
    )

    assert sent_draft.status == DraftStatus.SENT
    assert sent_draft.reviewed_by == test_users["operator"].id
    assert sent_draft.sent_message_id is not None

    # Verify posted message in DB
    posted_message = db_session.query(Message).filter(Message.id == sent_draft.sent_message_id).first()
    assert posted_message is not None
    assert posted_message.body == edited_text
    assert posted_message.ai_generated is True
    assert posted_message.visibility == MessageVisibility.REQUESTER_VISIBLE

    # Verify first-response SLA clock stop
    db_session.refresh(test_case)
    assert test_case.sla.first_responded_at is not None


def test_ai_draft_already_sent_rejection(db_session, test_users, test_case):
    provider = MockAIProvider()
    draft = AIService.generate_draft(
        db=db_session,
        case_id=test_case.id,
        draft_type=DraftType.PROGRESS_UPDATE,
        provider=provider
    )

    # First send succeeds
    AIService.send_draft(
        db=db_session,
        case_id=test_case.id,
        draft_id=draft.id,
        reviewer=test_users["operator"]
    )

    # Second send fails with 400
    with pytest.raises(HTTPException) as exc_info:
        AIService.send_draft(
            db=db_session,
            case_id=test_case.id,
            draft_id=draft.id,
            reviewer=test_users["operator"]
        )
    assert exc_info.value.status_code == 400
    assert "already in 'sent' state" in exc_info.value.detail


# --- 4. Graceful Fallback on Gemini Provider Failure ---

def test_gemini_provider_fallback():
    # Instantiate with dummy key / invalid client to trigger graceful degradation
    provider = GeminiAIProvider(api_key="mock-key-triggering-fallback")

    # Triage fallback test
    triage_fallback = provider.generate_triage("Test prompt")
    assert isinstance(triage_fallback, dict)
    assert triage_fallback["suggested_category"] == "Other"
    assert triage_fallback["confidence_level"] == "Low"
    assert triage_fallback["confidence_score"] == 0.50

    # Summary fallback test
    summary_fallback = provider.generate_summary("Test prompt")
    assert "Degraded Mode" in summary_fallback

    # Draft fallback test
    draft_fallback = provider.generate_draft("Test prompt")
    assert "Thank you for contacting IT Support" in draft_fallback


# --- 5. AI API Endpoints Route Tests ---

def test_ai_api_endpoints_flow(db_session, test_users, test_case):
    from fastapi.testclient import TestClient
    from backend.main import app
    from backend.api.deps import get_db, get_current_user

    op_id = test_users["operator"].id
    req_id = test_users["requester"].id

    def override_operator():
        return db_session.query(User).filter(User.id == op_id).first()

    def override_requester():
        return db_session.query(User).filter(User.id == req_id).first()

    app.dependency_overrides[get_db] = lambda: db_session
    app.dependency_overrides[get_current_user] = override_operator

    client = TestClient(app)

    try:
        # 1. Trigger Triage API
        triage_resp = client.post(f"/api/v1/cases/{test_case.id}/ai/triage")
        assert triage_resp.status_code == 200
        triage_data = triage_resp.json()
        assert triage_data["case_id"] == str(test_case.id)
        assert triage_data["suggested_category"] in ["Software", "Other"]
        assert "confidence_score" in triage_data

        # 2. Trigger Summarize API
        summary_resp = client.post(f"/api/v1/cases/{test_case.id}/ai/summarize")
        assert summary_resp.status_code == 200
        summary_data = summary_resp.json()
        assert summary_data["case_id"] == str(test_case.id)
        assert len(summary_data["summary_text"]) > 10


        # 3. Create Draft API
        draft_resp = client.post(
            f"/api/v1/cases/{test_case.id}/ai/drafts",
            json={"draft_type": "info_request", "custom_instruction": "Include ticket link."}
        )
        assert draft_resp.status_code == 201
        draft_data = draft_resp.json()
        assert draft_data["draft_type"] == "info_request"
        assert draft_data["status"] == "draft"
        draft_id = draft_data["id"]

        # 4. List Drafts API
        list_resp = client.get(f"/api/v1/cases/{test_case.id}/ai/drafts")
        assert list_resp.status_code == 200
        assert len(list_resp.json()) >= 1

        # 5. Send Draft API (HITL)
        send_resp = client.post(
            f"/api/v1/cases/{test_case.id}/ai/drafts/{draft_id}/send",
            json={"edited_body": "Approved and sent by staff.", "internal_only": False}
        )
        assert send_resp.status_code == 200
        sent_data = send_resp.json()
        assert sent_data["status"] == "sent"
        assert sent_data["reviewed_by"] == str(op_id)

        # 6. Test RBAC: Requester is blocked
        app.dependency_overrides[get_current_user] = override_requester
        forbidden_resp = client.post(f"/api/v1/cases/{test_case.id}/ai/triage")
        assert forbidden_resp.status_code == 403

    finally:
        app.dependency_overrides.clear()


