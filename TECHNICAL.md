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

### Messages & Attachments (`/api/v1/cases/{case_id}`)
* `POST /api/v1/cases/{case_id}/messages` — Add public message or internal staff note (enforces visibility partition).
* `GET /api/v1/cases/{case_id}/messages` — List messages (internal notes strictly hidden from Requesters).
* `POST /api/v1/cases/{case_id}/attachments` — Upload file attachment with magic-byte validation and 10MB/50MB limits.
* `GET /api/v1/cases/{case_id}/attachments` — List case attachments with storage quota metrics.
* `GET /api/v1/cases/{case_id}/attachments/{attachment_id}/download` — Get secure signed download URL.
* `DELETE /api/v1/cases/{case_id}/attachments/{attachment_id}` — Remove attachment.
