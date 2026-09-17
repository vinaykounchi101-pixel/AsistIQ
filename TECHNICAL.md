# AsistIQ / Paradox — Technical Architecture Document

**Specification Version:** SRS v3.3 / PRD Revised  
**Architecture:** Layered Clean Architecture (FastAPI) + Feature-Driven Multi-Platform Client (Flutter)  
**Backend Port:** 8000  
**API Base Prefix:** `/api/v1`  
**UI Framework & Design System:** Flutter Web/Desktop/Mobile + Stitch Nordic Calm Light Pastel Tokens

---

## 1. System Architecture & Layering

```text
HTTP Clients (Flutter Mobile / Desktop / Web)
       │ (JSON over HTTPS / Idempotency-Key)
       ▼
FastAPI Routes (backend/api/)             <-- Thin controllers, input validation
       │
Services Layer (backend/services/)        <-- Authoritative business logic, state machines, SLA math
       │
Repositories (backend/repositories/)      <-- Data access layer, SQLAlchemy ORM queries, soft-delete filtering
       │
PostgreSQL Database (Supabase / Local)    <-- Relational persistence, Alembic migrations
```

### Swappable Providers (`backend/providers/`)
* **AI Provider (`providers/ai/`):** Gemini API client with graceful fallback handling and configurable `GEMINI_MODEL`.
* **Storage Provider (`providers/storage/`):** Supabase Storage for attachments.
* **Auth Provider (`providers/auth/`):** Argon2id/bcrypt password hasher, JWT access/refresh token generator, Google OAuth 2.0 / OIDC code & ID token exchange.
* **Notification Provider (`providers/notifications/`):** `GmailSmtpNotificationProvider` for local dev; `BrevoNotificationProvider` (HTTP API) for staging/production to bypass Render SMTP port blocking.

---

## 2. Core Technical Specifications

### Authentication & RBAC Engine
* **Dual Auth:** Password + Argon2id/bcrypt and Google OAuth 2.0 / OIDC.
* **Anti-Takeover Policy (SRS §7.4):** Google sign-in colliding with an existing password account returns `409 Conflict` (`AUTH_PROVIDER_CONFLICT`).
* **Tokens:**
  * Access Token: 15 minutes (prod) / 24 hours (local dev default).
  * Refresh Token: 7 days, rotated on use, revocable.
* **5 User Roles:** `Requester`, `Operator`, `TeamLead`, `Manager`, `Administrator`.
* **RBAC Dependency:** `@require_roles(*allowed_roles)` in `backend/api/deps.py`.

### 24/7 Elapsed Wall-Clock SLA Matrix (SRS §4.3)
All SLA calculations run 24/7 wall-clock time without business-hour pausing:
* **P1 (Critical):** 15 min Initial Response / 4 hr Resolution
* **P2 (High):** 1 hr Initial Response / 8 hr Resolution
* **P3 (Medium):** 4 hr Initial Response / 72 hr (3 days) Resolution
* **P4 (Low):** 24 hr (1 day) Initial Response / 120 hr (5 days) Resolution

### Concurrency & Audit Trail
* **Optimistic Locking (SRS §7.12):** Every `Case` row has a `version` integer. Updates must supply the expected version; mismatch returns `409 Conflict` (`STALE_VERSION`).
* **Append-Only Audit Log (SRS §5.11):** Every material state change, priority override, or reassignment writes an immutable record to `AuditLog`.

---

## 3. Implemented API Endpoints

### Health & Direct UI Endpoints
* `GET /api/v1/health` — DB connectivity health check.
* `GET /ui` — Stitch UI landing index.
* `GET /ui/requester` — Direct Stitch Requester Portal & Incident Drawer view.
* `GET /ui/operator` — Direct Stitch Operator Workbench view.
* `GET /ui/command-center` — Direct Stitch Incident Command Center view.
* `GET /ui/manager` — Direct Stitch Manager Operational Insights view.

### Authentication (`/api/v1/auth`)
* `POST /api/v1/auth/signup` — Password registration with optional email verification.
* `POST /api/v1/auth/login` — Password authentication.
* `POST /api/v1/auth/google` — Google OAuth 2.0 / OIDC exchange.
* `POST /api/v1/auth/refresh` — Token rotation.
* `GET /api/v1/auth/verify-email` — Email verification link handler.
* `GET /api/v1/auth/me` — Authenticated profile.
* `POST /api/v1/auth/logout` — Session termination.

### Case Management (`/api/v1/cases`)
* `POST /api/v1/cases/` — Create Incident or Service Request.
* `GET /api/v1/cases/` — List permitted cases with pagination and filters.
* `GET /api/v1/cases/{case_id}` — Get case detail with SLA status.
* `PATCH /api/v1/cases/{case_id}` — Update case metadata with version check.
* `POST /api/v1/cases/{case_id}/transition` — Execute validated lifecycle state transition (with 7-day reopen enforcement).
* `GET /api/v1/cases/{case_id}/risk` — Retrieve or recompute real-time deterministic risk assessment and signal breakdown.
* `GET /api/v1/cases/{case_id}/escalations` — List all auto-escalation and manual escalation events.

### Messages & Attachments (`/api/v1/cases/{case_id}`)
* `POST /api/v1/cases/{case_id}/messages` — Add public message or internal staff note (enforces visibility partition).
* `GET /api/v1/cases/{case_id}/messages` — List messages (internal notes strictly hidden from Requesters).
* `POST /api/v1/cases/{case_id}/attachments` — Upload file attachment with magic-byte validation and 10MB/50MB limits.
* `GET /api/v1/cases/{case_id}/attachments` — List case attachments with storage quota metrics.
* `GET /api/v1/cases/{case_id}/attachments/{attachment_id}/download` — Get secure signed download URL.
* `DELETE /api/v1/cases/{case_id}/attachments/{attachment_id}` — Remove attachment.

### AI Engine (`/api/v1/cases/{case_id}/ai`)
* `POST /api/v1/cases/{case_id}/ai/triage` — Trigger or refresh intake triage (category, priority, confidence, missing info).
* `POST /api/v1/cases/{case_id}/ai/summarize` — Generate continuous chronological summary of case thread.
* `POST /api/v1/cases/{case_id}/ai/drafts` — Generate contextual communication draft (`info_request`, `progress_update`, `resolution`, `escalation_summary`).
* `GET /api/v1/cases/{case_id}/ai/drafts` — List all drafts generated for a case.
* `POST /api/v1/cases/{case_id}/ai/drafts/{draft_id}/send` — Human-in-the-loop review: approve, edit, and post draft as case message (`ai_generated=True`).

### Sweeps & Administration (`/api/v1/admin`)
* `POST /api/v1/admin/sweeps/run` — On-demand manual SLA audit and risk sweep execution (Managers & Admins).

### Operational Reports & Analytics (`/api/v1/reports`)
* `GET /api/v1/reports/summary` — Full executive summary with KPI metrics (volumes, compliance %, MTTR) + Gemini AI briefing.
* `GET /api/v1/reports/sla-compliance` — Granular SLA compliance breakdown by priority tier (P1–P4).
* `GET /api/v1/reports/team-performance` — Team & operator workload throughput and breach metrics.
* `GET /api/v1/reports/trends` — 14-day chronological daily ingestion & resolution trend series.

---

## 4. Flutter Client Implementation & Design System

### Design Tokens (`client/lib/shared/theme/`)
* **Color Palette (`colors.dart`):** Stitch Nordic Light Pastel palette (`#F8FAFC` canvas, `#FFFFFF` cards, `#E2E8F0` borders, `#4F46E5` indigo primary, `#F5F3FF` lavender accents, `#ECFDF5` sage badge, `#FEF2F2` blush warning).
* **Typography (`typography.dart`):** `Plus Jakarta Sans` for titles and UI labels; `JetBrains Mono` for IDs, timestamps, SLA clocks, and tags.
* **Layout Shell (`shell.dart`):** 260px desktop navigation sidebar with categorized sections (`OPERATIONS`, `INSIGHTS & ASSETS`, `GOVERNANCE`), real-time `Ctrl+K` search bar, APScheduler heartbeat badge, unread alert counter (`3`), and user profile status dot.

### Implemented Screen Directory
1. `LoginScreen` — [login_screen.dart](file:///e:/Projects/AsistIQ/client/lib/features/auth/screens/login_screen.dart)
2. `AppShell` — [shell.dart](file:///e:/Projects/AsistIQ/client/lib/app/shell.dart)
3. `RequesterDashboard` — [requester_dashboard.dart](file:///e:/Projects/AsistIQ/client/lib/features/dashboard/screens/requester_dashboard.dart)
4. `OperatorDashboard` — [operator_dashboard.dart](file:///e:/Projects/AsistIQ/client/lib/features/dashboard/screens/operator_dashboard.dart)
5. `LeadDashboard` (Command Center) — [lead_dashboard.dart](file:///e:/Projects/AsistIQ/client/lib/features/dashboard/screens/lead_dashboard.dart)
6. `ManagerDashboard` (Operational Insights) — [manager_dashboard.dart](file:///e:/Projects/AsistIQ/client/lib/features/dashboard/screens/manager_dashboard.dart)
7. `AdminScreen` & `AdminDashboard` (Governance) — [admin_screen.dart](file:///e:/Projects/AsistIQ/client/lib/features/admin/screens/admin_screen.dart)
8. `CasesScreen` (Workspaces Directory) — [cases_screen.dart](file:///e:/Projects/AsistIQ/client/lib/features/cases/screens/cases_screen.dart)
9. `CreateCaseScreen` (Intake Hub) — [create_case_screen.dart](file:///e:/Projects/AsistIQ/client/lib/features/cases/screens/create_case_screen.dart)
10. `CaseDetailScreen` (Incident Workspace) — [case_detail_screen.dart](file:///e:/Projects/AsistIQ/client/lib/features/cases/screens/case_detail_screen.dart)
11. `AiCopilotPanel` (Finny Copilot) — [ai_copilot_panel.dart](file:///e:/Projects/AsistIQ/client/lib/features/ai/widgets/ai_copilot_panel.dart)
12. `ReportsScreen` (Executive Analytics) — [reports_screen.dart](file:///e:/Projects/AsistIQ/client/lib/features/reports/screens/reports_screen.dart)
13. `NotificationDrawer` — [notification_drawer.dart](file:///e:/Projects/AsistIQ/client/lib/features/notifications/widgets/notification_drawer.dart)

---

## 5. Test Suite Verification & Security Posture
* **Backend:** 37 / 37 pytest test suites passing (`pytest backend/tests/ -v`)
* **Frontend:** 20 / 20 Flutter test suites passing (`flutter test`)
* **RBAC & Navigation Enforcement:**
  * Desktop sidebar & Mobile navigation strictly filter visible sections based on `UserRole` (`isStaff`, `isManagement`, `isAdmin`).
  * `ReportsScreen` (`/reports`) and backend endpoints `/api/v1/reports/*` strictly restricted to `Manager` and `Administrator`.
  * AI Copilot sidebar panel on `CaseDetailScreen` strictly restricted to staff roles to prevent Requester 403 API collisions.
