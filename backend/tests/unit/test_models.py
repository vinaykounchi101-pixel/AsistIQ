import pytest
from backend.core.config import Settings
from backend.models.enums import UserRole, CaseStatus, CasePriority, CaseType
from backend.models import User, Case, SLA, AITriageResult, AuditLog


def test_settings_initialization():
    settings = Settings(ENVIRONMENT="local")
    assert settings.APP_NAME == "AsistIQ"
    assert settings.API_V1_PREFIX == "/api/v1"
    assert "/api/v1" in settings.API_V1_PREFIX
    assert len(settings.cors_origins) > 0


def test_enums_integrity():
    assert UserRole.REQUESTER == "Requester"
    assert UserRole.OPERATOR == "Operator"
    assert UserRole.TEAM_LEAD == "TeamLead"
    assert UserRole.MANAGER == "Manager"
    assert UserRole.ADMINISTRATOR == "Administrator"

    assert CaseType.INCIDENT == "Incident"
    assert CaseType.SERVICE_REQUEST == "Service Request"

    assert CaseStatus.NEW == "New"
    assert CaseStatus.RESOLVED == "Resolved"
    assert CaseStatus.CLOSED == "Closed"

    assert CasePriority.P1 == "P1 — Critical"
    assert CasePriority.P4 == "P4 — Low"


def test_model_tables_metadata():
    assert User.__tablename__ == "users"
    assert Case.__tablename__ == "cases"
    assert SLA.__tablename__ == "slas"
    assert AITriageResult.__tablename__ == "ai_triage_results"
    assert AuditLog.__tablename__ == "audit_logs"
