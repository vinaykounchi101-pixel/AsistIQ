"""
AsistIQ / Paradox — Comprehensive Demo Database Seeder (Sprint 10)
Seeds realistic data covering all 5 User Roles, Teams, Services, SLAs,
Cases across all lifecycle states, AI Triage & Drafts, and Audit Logs.
"""

import os
import sys
import uuid
from datetime import datetime, timedelta, timezone

# Ensure backend root is on Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from backend.db.session import SessionLocal
from backend.models.enums import (
    UserRole, AuthProvider, AvailabilityStatus, CaseType, CaseStatus,
    CasePriority, MessageVisibility, ConfidenceLevel, RiskLevel,
    DraftType, DraftStatus
)
from backend.models.user import User, Team, Service
from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.message import Message
from backend.models.ai import AITriageResult, CaseSummary, CaseRiskAssessment, CommunicationDraft
from backend.models.audit import AuditLog
from backend.providers.auth.password_hasher import PasswordHasher
def seed_database():
    print(">> Starting Paradox / AsistIQ Demo Database Seeding...")
    db = SessionLocal()
    hasher = PasswordHasher()
    default_password_hash = hasher.hash_password("Password123!")

    try:
        # 1. Seed Teams
        teams_data = [
            ("Tier 1 Support", "First-response triage and general IT support"),
            ("Network Operations", "Routing, VPN, firewalls, and connectivity"),
            ("Security & Access", "IAM, credentials, MFA, and access control"),
            ("Enterprise Applications", "ERP, database, and business tools support"),
        ]
        teams = {}
        for name, desc in teams_data:
            team = db.query(Team).filter(Team.name == name).first()
            if not team:
                team = Team(id=uuid.uuid4(), name=name, description=desc)
                db.add(team)
                db.flush()
                print(f"  [+] Created Team: {name}")
            teams[name] = team

        # 2. Seed Services
        services_data = [
            ("Corporate VPN Access", "Network", "Remote workforce secure tunnel access"),
            ("Hardware & Workstation", "Hardware", "Laptops, monitors, and peripherals"),
            ("Email & Collaboration", "Software", "Office365, Slack, and email access"),
            ("ERP & Database Systems", "Software", "SAP, PostgreSQL, and enterprise data tools"),
        ]
        services = {}
        for name, cat, desc in services_data:
            service = db.query(Service).filter(Service.name == name).first()
            if not service:
                service = Service(id=uuid.uuid4(), name=name, category=cat, description=desc)
                db.add(service)
                db.flush()
                print(f"  [+] Created Service: {name}")
            services[name] = service

        # 3. Seed Users across all 5 RBAC roles
        users_data = [
            ("requester@paradox.com", "Alice Requester", UserRole.REQUESTER, None),
            ("operator@paradox.com", "Bob Operator", UserRole.OPERATOR, teams["Tier 1 Support"].id),
            ("lead@paradox.com", "Carol TeamLead", UserRole.TEAM_LEAD, teams["Tier 1 Support"].id),
            ("manager@paradox.com", "David Manager", UserRole.MANAGER, None),
            ("admin@paradox.com", "Eve SystemAdmin", UserRole.ADMINISTRATOR, None),
        ]
        users = {}
        for email, full_name, role, team_id in users_data:
            user = db.query(User).filter(User.email == email).first()
            if not user:
                user = User(
                    id=uuid.uuid4(),
                    email=email,
                    password_hash=default_password_hash,
                    auth_provider=AuthProvider.PASSWORD,
                    full_name=full_name,
                    role=role,
                    team_id=team_id,
                    email_verified=True,
                    availability_status=AvailabilityStatus.AVAILABLE,
                )
                db.add(user)
                db.flush()
                print(f"  [+] Created User ({role.value}): {email}")
            users[email] = user

        # 4. Seed Cases covering all Priorities & Lifecycle States
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        cases_data = [
            {
                "ref": "INC-2026-000001",
                "title": "Global VPN Gateway Outage",
                "desc": "Unable to connect to US-East VPN server. Authentication times out immediately.",
                "priority": CasePriority.P1,
                "status": CaseStatus.NEW,
                "risk": RiskLevel.CRITICAL,
                "category": "Network",
                "service": services["Corporate VPN Access"],
                "owner": None,
                "created_at": now - timedelta(minutes=10),
                "resp_sla_mins": 15,
                "res_sla_hrs": 4,
            },
            {
                "ref": "INC-2026-000002",
                "title": "SAP ERP Account Locked Out",
                "desc": "User entered wrong password 3 times and is locked out from month-end closing ledger.",
                "priority": CasePriority.P2,
                "status": CaseStatus.IN_ASSESSMENT,
                "risk": RiskLevel.HIGH,
                "category": "Software",
                "service": services["ERP & Database Systems"],
                "owner": users["operator@paradox.com"],
                "created_at": now - timedelta(minutes=45),
                "resp_sla_mins": 60,
                "res_sla_hrs": 8,
            },
            {
                "ref": "INC-2026-000003",
                "title": "Secondary Monitor Flickering",
                "desc": "Dell 4K monitor intermittently blacks out when connected via Thunderbolt dock.",
                "priority": CasePriority.P3,
                "status": CaseStatus.ASSIGNED,
                "risk": RiskLevel.MODERATE,
                "category": "Hardware",
                "service": services["Hardware & Workstation"],
                "owner": users["operator@paradox.com"],
                "created_at": now - timedelta(hours=3),
                "resp_sla_mins": 240,
                "res_sla_hrs": 72,
            },
            {
                "ref": "INC-2026-000004",
                "title": "Office 365 Shared Mailbox Access",
                "desc": "Need read/write access to marketing-leads@paradox.com for new campaign manager.",
                "priority": CasePriority.P4,
                "status": CaseStatus.RESOLVED,
                "risk": RiskLevel.LOW,
                "category": "Software",
                "service": services["Email & Collaboration"],
                "owner": users["operator@paradox.com"],
                "created_at": now - timedelta(days=1),
                "resolved_at": now - timedelta(hours=2),
                "resp_sla_mins": 1440,
                "res_sla_hrs": 120,
            },
            {
                "ref": "INC-2026-000005",
                "title": "Slack Integration Webhook Bug",
                "desc": "Alert bot failing to post notifications to #dev-ops channel.",
                "priority": CasePriority.P3,
                "status": CaseStatus.CLOSED,
                "risk": RiskLevel.LOW,
                "category": "Software",
                "service": services["Email & Collaboration"],
                "owner": users["operator@paradox.com"],
                "created_at": now - timedelta(days=4),
                "resolved_at": now - timedelta(days=3),
                "closed_at": now - timedelta(days=2),  # <= 7 days (Reopenable)
                "resp_sla_mins": 240,
                "res_sla_hrs": 72,
            },
            {
                "ref": "INC-2026-000006",
                "title": "Legacy Printer Driver Replacement",
                "desc": "HP LaserJet 4000 driver update across 2nd floor workstations.",
                "priority": CasePriority.P4,
                "status": CaseStatus.CLOSED,
                "risk": RiskLevel.LOW,
                "category": "Hardware",
                "service": services["Hardware & Workstation"],
                "owner": users["operator@paradox.com"],
                "created_at": now - timedelta(days=25),
                "resolved_at": now - timedelta(days=20),
                "closed_at": now - timedelta(days=18),  # > 7 days (Non-reopenable)
                "resp_sla_mins": 1440,
                "res_sla_hrs": 120,
            },
        ]

        for c_data in cases_data:
            existing = db.query(Case).filter(Case.reference_number == c_data["ref"]).first()
            if not existing:
                case_id = uuid.uuid4()
                c = Case(
                    id=case_id,
                    reference_number=c_data["ref"],
                    type=CaseType.INCIDENT,
                    title=c_data["title"],
                    description=c_data["desc"],
                    status=c_data["status"],
                    priority=c_data["priority"],
                    requester_id=users["requester@paradox.com"].id,
                    owner_id=c_data["owner"].id if c_data["owner"] else None,
                    team_id=teams["Tier 1 Support"].id,
                    service_id=c_data["service"].id if c_data["service"] else None,
                    version=1,
                    created_at=c_data["created_at"],
                    updated_at=c_data["created_at"],
                    resolved_at=c_data.get("resolved_at"),
                    closed_at=c_data.get("closed_at"),
                )
                db.add(c)
                db.flush()

                # SLA entity
                sla = SLA(
                    id=uuid.uuid4(),
                    case_id=case_id,
                    target_response_at=c_data["created_at"] + timedelta(minutes=c_data["resp_sla_mins"]),
                    target_resolve_at=c_data["created_at"] + timedelta(hours=c_data["res_sla_hrs"]),
                    first_responded_at=c_data["created_at"] + timedelta(minutes=5) if c_data["status"] != CaseStatus.NEW else None,
                    response_breached=False,
                    resolve_breached=False,
                    created_at=c_data["created_at"],
                )
                db.add(sla)

                # Risk Assessment
                risk = CaseRiskAssessment(
                    id=uuid.uuid4(),
                    case_id=case_id,
                    risk_level=c_data["risk"],
                    signals={"reasons": [f"Calculated {c_data['risk'].value} priority risk based on SLA timeline"]},
                    computed_at=c_data["created_at"],
                )
                db.add(risk)

                # AI Triage Result
                triage = AITriageResult(
                    id=uuid.uuid4(),
                    case_id=case_id,
                    suggested_category=c_data["category"],
                    suggested_priority=c_data["priority"].value,
                    confidence_score=0.92,
                    confidence_level=ConfidenceLevel.HIGH,
                    supporting_factors=[f"Automated AI classification for {c_data['title']}"],
                    missing_info=["System logs", "Device hostname"] if c_data["priority"] == CasePriority.P1 else [],
                    created_at=c_data["created_at"],
                )
                db.add(triage)

                # Messages & Notes
                msg1 = Message(
                    id=uuid.uuid4(),
                    case_id=case_id,
                    author_id=users["requester@paradox.com"].id,
                    body=c_data["desc"],
                    visibility=MessageVisibility.REQUESTER_VISIBLE,
                    ai_generated=False,
                    created_at=c_data["created_at"],
                )
                db.add(msg1)

                if c_data["status"] != CaseStatus.NEW:
                    msg2 = Message(
                        id=uuid.uuid4(),
                        case_id=case_id,
                        author_id=users["operator@paradox.com"].id,
                        body="Investigating issue with network operations team.",
                        visibility=MessageVisibility.INTERNAL_ONLY,
                        ai_generated=False,
                        created_at=c_data["created_at"] + timedelta(minutes=15),
                    )
                    db.add(msg2)

                # AI Draft for P2 Case
                if c_data["ref"] == "INC-2026-000002":
                    draft = CommunicationDraft(
                        id=uuid.uuid4(),
                        case_id=case_id,
                        draft_type=DraftType.INFO_REQUEST,
                        body="Hello Alice, could you confirm your SAP user ID and department cost center?",
                        status=DraftStatus.DRAFT,
                        created_at=now,
                    )
                    db.add(draft)

                # Audit Log
                audit = AuditLog(
                    id=uuid.uuid4(),
                    actor_id=users["requester@paradox.com"].id,
                    action="case_created",
                    target_type="Case",
                    target_id=str(case_id),
                    before_value=None,
                    after_value={"status": c_data["status"].value, "priority": c_data["priority"].value},
                    created_at=c_data["created_at"],
                )
                db.add(audit)


                print(f"  [+] Created Case: {c_data['ref']} ({c_data['priority'].value}, {c_data['status'].value})")

        db.commit()
        print("\n[OK] Database Seeding Completed Successfully! All 5 roles and test cases are ready.\n")
    except Exception as e:
        db.rollback()
        print(f"\n[ERROR] Error during seeding: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()

