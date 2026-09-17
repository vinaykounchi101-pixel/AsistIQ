# AsistIQ / Paradox — Technical Architecture Document

**Specification Version:** SRS v3.3 / PRD Revised  
**Architecture:** Layered Clean Architecture (FastAPI) + Feature-Driven Multi-Platform Client (Flutter)  
**Backend Port:** 8000  
**API Base Prefix:** `/api/v1`

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
* **AI Provider (`providers/ai/`):** Gemini API client with graceful fallback handling.
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

## 3. Implemented API Endpoints (as of Session 1)

### Health
* `GET /api/v1/health` — DB connectivity health check.

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
* `GET /api/v1/reports/team-performance` — Per-team and per-operator workload and velocity metrics.
* `GET /api/v1/reports/trends` — Time-series incident volume, resolution, and breach trends.

---

## 4. Flutter Multi-Platform Client Architecture (Sprint 8)

### Design System (Stitch Obsidian Theme)
* **Dark Mode Theme (Primary):** Background `#0B0F19`, Surface `#111827`, Card `#1F2937`, Border `#374151`.
* **Light Mode Theme:** Background `#F8FAFC`, Surface `#FFFFFF`, Border `#E2E8F0`.
* **Primary Brand Accents:** Electric Iris (`#6366F1`), Cyan Glow (`#06B6D4`), Purple Accent (`#8B5CF6`).
* **SLA Priority Colors:** P1 Critical (`#EF4444`), P2 High (`#F59E0B`), P3 Medium (`#3B82F6`), P4 Low (`#10B981`).
* **Typography:** Google Fonts Inter across all display, headline, title, body, and label text themes.
* **Layout Grid & Breakpoints:** 4px spacing scale (`xs`: 4, `sm`: 8, `md`: 12, `base`: 16, `lg`: 20, `xl`: 24, `xxl`: 32, `xxxl`: 48). Responsive breakpoints at Mobile (`<600px`), Tablet (`600-1024px`), Desktop (`>1024px`).

### API Networking & Auth State Management
* **`ApiClient`:** Powered by `dio` with configurable `API_BASE_URL` (default `http://localhost:8000`).
* **`AuthInterceptor`:** Automatic Bearer token header injection and queued `401 Unauthorized` token refresh rotation via `FlutterSecureStorage`.
* **Typed Error Envelope:** Maps backend HTTP status codes to `ApiException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `ConflictException`, `ValidationException`, and `NetworkException`.
* **`AuthNotifier` (Riverpod `StateNotifier`):** Handles `checkAuth()`, `login()`, `loginWithGoogle()`, and `logout()`.
* **`GoRouter` Navigation:** Auth state-driven route guards with role permissions (`/login`, `/cases`, `/reports`, `/admin`) and responsive multi-platform shell.

---

## 5. Flutter Incident Workspace & AI Copilot Architecture (Sprint 9)

### Incident Workspace & SLA Countdown Clock
* **Live SLA Clock (`SlaCountdownTimer`):** Real-time 1-second ticker computing elapsed wall-clock deadlines for Response SLA and Resolution SLA. Color-coded warning and breach transitions. First staff public response immediately stops the Response clock.
* **Threaded Communication Feed:** Partitioned into Public Messages (visible to requesters) and Internal Staff Notes (strictly restricted to staff roles).
* **Optimistic Concurrency Conflict Banner:** Detects `409 Conflict` (`STALE_VERSION`) from backend mutations and displays a prompt to reload without losing user context.
* **7-Day Reopen Enforcement:** Closed cases within the 7-day window present a Reopen button triggering `POST /api/v1/cases/{id}/transition` with reason logging.

### AI Finny Copilot Panel (`AiCopilotPanel`)
* **Intake Triage Card:** Displays AI predicted category, SLA priority tier, confidence score %, reasoning, and missing info checklist.
* **Continuous Summary Card:** On-demand chronological synthesis of complex case threads.
* **HITL Communication Drafts:** Generates contextual drafts (`info_request`, `progress_update`, `resolution`, `escalation_summary`), enables operator text editing, and offers 1-click "Approve & Send" to timeline.

### 5 Role Dashboards (`RoleDashboardRouter`)
* **`RequesterDashboard`:** Self-service tracking, open ticket count, quick incident creation.
* **`OperatorDashboard`:** Active ticket workbench, SLA urgency filters, risk signal badges.
* **`LeadDashboard`:** Unassigned triage pool and critical risk escalations.
* **`ManagerDashboard`:** Real-time KPI summaries, SLA breach alerts, and 1-click manual sweep trigger (`/admin/sweeps/run`).
* **`AdminDashboard`:** Security posture, RBAC overview, active cases counter.




