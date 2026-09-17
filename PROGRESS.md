# AsistIQ / Paradox — Project Progress Tracker

**Last Updated:** 2026-09-16 (End of Session 1)  
**Active Phase:** Phase 1 (College Project MVP)  
**Current Active Branch:** `dev`

---

## 📊 Sprint Status Overview

| Sprint # | Module / Feature Branch | Scope & Deliverables | Status |
|---|---|---|---|
| **Sprint 1** | `feat/backend-core-db` | Project folder structure (SRS §11), `docker-compose.yml`, `requirements.txt`, `config.py` with startup env validation, 16 SQLAlchemy ORM models, Alembic migrations setup, health check API. | ✅ **Completed & Merged into `dev`** |
| **Sprint 2** | `feat/backend-auth-rbac` | Argon2id password hasher (SRS §3.3a / §7.4), JWT access/refresh token rotation, Google OAuth 2.0 / OIDC exchange with anti-takeover conflict check, User repository, RBAC dependencies (`@require_roles`), notification provider interface (Gmail SMTP local / Brevo HTTP API prod), `/api/v1/auth/` routes. | ✅ **Completed & Merged into `dev`** |
| **Sprint 3** | `feat/backend-cases-sla` | Sequential reference generator (`INC-2026-000001`), 24/7 elapsed wall-clock SLA engine (P1: 15m/4h, P2: 1h/8h, P3: 4h/72h, P4: 24h/120h), Lifecycle state machine with 7-day reopen policy, Optimistic locking (`version` check / `409 Conflict`), Append-only audit logger, `/api/v1/cases/` endpoints. | ✅ **Completed & Merged into `dev`** |
| **Sprint 4** | `feat/backend-messages-storage` | Case notes & messages, visibility rules (`requester_visible` vs `internal_only`), Supabase Storage integration for attachments (10MB/file, 50MB/case limit), magic-byte signature validation, `/api/v1/cases/{case_id}/messages` & `/attachments` endpoints. | ✅ **Completed & Merged into `dev`** |
| **Sprint 5** | `feat/backend-ai-engine` | Gemini AIProvider interface, versioned prompt templates (`backend/ai/prompts/`), AI case triage/analysis, continuous summary, missing-info detection, AI communication drafts with human-in-the-loop review. | ✅ **Completed & Merged into `dev`** |
| **Sprint 6** | `feat/backend-sweeps-scheduler` | In-process APScheduler periodic sweep (every 5 mins), SLA warning & breach detection, risk scoring (Low/Mod/High/Critical), auto-escalation triggers to Team Lead / Manager. | ⏳ **Ready to Launch (Next Sprint)** |
| **Sprint 7** | `feat/backend-insights-reports` | Manager / Admin Operational Insights aggregate SQL queries + Gemini plain-language narrative. | ⏳ **Pending** |
| **Sprint 8** | `feat/flutter-shell-shared` | Flutter multi-platform scaffold (Mobile, Desktop, Web), Design System tokens, `ApiClient`, auth state provider. | ⏳ **Pending** |
| **Sprint 9** | `feat/flutter-ui-dashboards` | Intake forms, Case workspace (Timeline, AI suggestions panel, draft review), 5 Role Dashboards (Requester, Operator, Lead, Manager, Admin). | ⏳ **Pending** |
| **Sprint 10** | `feat/seed-e2e-uat` | `scripts/seed_demo_data.py`, automated test suites, multi-user UAT signoff. | ⏳ **Pending** |

---

## 🎯 Next Steps
1. Checkout feature branch: `git checkout -b feat/backend-sweeps-scheduler`.
2. Launch **Sprint 6 (`feat/backend-sweeps-scheduler`)**:
   * Implement in-process `APScheduler` runner integrated into FastAPI lifespan (`backend/scheduler/`).
   * Implement periodic SLA sweep service (detect approaching response/resolution deadlines & breaches).
   * Implement deterministic Risk Scoring Engine (SRS §4.3) computing `RiskLevel` and persisting `CaseRiskAssessment`.
   * Implement auto-escalation triggers logging `EscalationEvent` records for Team Leads & Managers.
   * Add automated unit tests in `backend/tests/unit/test_scheduler_sweeps.py`.

