# Stitch UI/UX Design System & Comprehensive Screen Specifications
## Project: Paradox / AsistIQ — AI-Assisted, Human-in-the-Loop IT Helpdesk
**Based on:** SRS v3.3 & Master PRD Revised  
**Theme:** Stitch Obsidian Design System (Dark Obsidian / Cyber-Enterprise Aesthetic)

---

## 1. Design System Tokens & Visual Language

### 1.1 Color Palette (Obsidian Theme)
* **Background Canvas (Deep Obsidian):** `#090A0F`
* **Surface / Sidebar / Topbar:** `#12141C`
* **Card / Container Background:** `#181B26`
* **Card Border / Divider Lines:** `#222636` (Subtle: `#1E2230`)
* **Primary Accent (Electric Violet):** `#7C3AED` (Hover: `#6D28D9`, Active: `#5B21B6`, Glow: `rgba(124, 58, 237, 0.25)`)
* **Secondary Accent (Cyan Glow):** `#06B6D4` (Hover: `#0891B2`, Glow: `rgba(6, 182, 212, 0.25)`)
* **Success / Resolution Green:** `#10B981` (Background tint: `rgba(16, 185, 129, 0.12)`, Border: `rgba(16, 185, 129, 0.3)`)
* **Warning / Awaiting Amber:** `#F59E0B` (Background tint: `rgba(245, 158, 11, 0.12)`, Border: `rgba(245, 158, 11, 0.3)`)
* **Error / Breach / Critical Red:** `#EF4444` (Background tint: `rgba(239, 68, 68, 0.12)`, Border: `rgba(239, 68, 68, 0.3)`)
* **Text Primary (High Contrast):** `#F8FAFC`
* **Text Secondary / Muted:** `#94A3B8`
* **Text Dim / Micro-labels:** `#64748B`

### 1.2 SLA Tier & Priority Badging
* **P1 — Critical (15m response / 4h resolve):** Crimson Badge (`#EF4444` on `rgba(239,68,68,0.15)`) with pulsing indicator ring.
* **P2 — High (1h response / 8h resolve):** Orange Badge (`#F97316` on `rgba(249,115,22,0.15)`).
* **P3 — Medium (4h response / 72h resolve):** Blue Badge (`#3B82F6` on `rgba(59,130,246,0.15)`).
* **P4 — Low (24h response / 120h resolve):** Slate Gray Badge (`#64748B` on `rgba(100,116,139,0.15)`).

### 1.3 Case Status Badges
* **New:** Blue (`#3B82F6`)
* **In Assessment:** Purple (`#8B5CF6`)
* **Assigned:** Cyan (`#06B6D4`)
* **Awaiting Requester:** Amber (`#F59E0B`)
* **Awaiting Approval:** Orange (`#F97316`)
* **Pending / External Dependency:** Slate (`#64748B`)
* **Resolved:** Emerald Green (`#10B981`)
* **Closed:** Gray (`#475569`)
* **Cancelled:** Red Muted (`#991B1B`)

### 1.4 Typography & Hierarchy
* **Primary Font Family:** `Inter`, `sans-serif`
* **Monospace / Code / Timers Font:** `JetBrains Mono`, `monospace`
* **Page Titles:** 24px Bold (`#F8FAFC`, letter-spacing: -0.5px)
* **Section Headers / Card Titles:** 16px Semi-Bold (`#F8FAFC`)
* **Body Text:** 14px Regular (`#CBD5E1`, line-height: 1.5)
* **Micro-Labels / Badges / Timers:** 11px–12px Bold / Semi-Bold (`#94A3B8`)

### 1.5 Spacing & Radii
* **Border Radii:** Card/Modal: `12px`, Input/Button: `8px`, Tag/Badge: `4px`
* **Grid Spacing:** Base `8px` scale (`8px`, `16px`, `24px`, `32px`, `48px`)

---

## 2. Global Shell & Navigation Architecture

### Screen 0: Global Obsidian Shell (`AppShell`)
* **Left Navigation Sidebar (240px Desktop, Collapsible on Tablet/Mobile):**
  * **Brand Header:** Violet lightning bolt icon + "AsistIQ" logo with "v1.0.0" badge.
  * **Role Badge:** Pill indicator showing current role (e.g. `Operator`, `Requester`, `Administrator`).
  * **Navigation Links (Role-Aware):**
    * *Requester:* `Cases (My Tickets)`, `+ New Ticket`
    * *Operator / Team Lead:* `Cases (Queue & Workspaces)`, `Knowledge Base`
    * *Manager:* `Cases`, `Reports & Analytics`, `Knowledge Base`
    * *Administrator:* `Cases`, `Reports`, `Admin Console`, `Knowledge Base`
  * **Bottom Profile Section:**
    * User avatar with online availability status dot (Green = Available, Amber = Away, Gray = Offline).
    * User Full Name + Email (truncated).
    * `[Logout]` icon button.
* **Top Header Bar:**
  * Global Search Bar (`Ctrl + K` / `Cmd + K`) with auto-complete for incident IDs (`INC-2026-XXXXXX`) and subjects.
  * Notification Bell with unread counter badge.
  * Role Switcher Chip (Demo mode).

---

## 3. Comprehensive Screen-by-Screen Specifications & API Contracts

---

### Screen 1: Dual Authentication & Login (`/login`)

#### Visual Layout & Elements:
* **Background:** Deep Obsidian canvas with subtle ambient electric violet gradient mesh.
* **Centered Card Modal (440px):**
  * **Logo & Title:** AsistIQ glowing shield icon + "Welcome Back" header with "Sign in to your enterprise IT portal".
  * **Google OAuth Button:** Full-width button with Google 'G' logo, dark surface with white text.
  * **Divider:** "OR CONTINUE WITH EMAIL" in 11px muted uppercase.
  * **Form Fields:**
    * Email Input (`mail` icon prefix, placeholder `name@company.com`).
    * Password Input (`lock` icon prefix, show/hide eye toggle).
  * **Remember Me & Forgot Password:** Flex row with custom checkbox and link.
  * **Submit Button:** Full-width Electric Violet gradient button: "Sign In →".
  * **Quick Role Switcher Chips (Bottom):** 5 clickable chips for instant testing (`Requester`, `Operator`, `Team Lead`, `Manager`, `Administrator`).

#### API Integration:
* `POST /api/v1/auth/login` $\rightarrow$ `{ email, password }`
* `POST /api/v1/auth/google` $\rightarrow$ `{ id_token }`
* **Response:** `{ user: { id, email, full_name, role }, tokens: { access_token, refresh_token } }`

---

### Screen 2: Requester Self-Service Portal (`/cases` for Requester)

#### Visual Layout & Elements:
* **Header Row:** "My Helpdesk Portal" title, search input, status filter dropdown, and prominent `[+ New Incident]` CTA button.
* **KPI Metrics Row (2 Summary Cards):**
  * Card 1: **Active Tickets** (Large purple number, e.g. `2`, with "Under Investigation" subtext).
  * Card 2: **Resolved / Closed** (Large green number, e.g. `14`, with "Avg resolution time: 3.2 hrs").
* **Ticket List (Card / Data Table View):**
  * **Columns/Cards:**
    * Reference Number (`INC-2026-000001` in cyan mono font).
    * Subject / Title (Bold, clickable to open detail).
    * Category Chip (`Hardware`, `Software`, `Network`, `Security`).
    * Priority Badge (`P1` to `P4` with color codes).
    * Status Badge (`New`, `In Assessment`, `Assigned`, `Resolved`, `Closed`).
    * Last Updated / Created relative time (`10m ago`).
  * **Empty State:** Friendly graphic + "No active incidents found. Everything is running smoothly!" + `[Report an Issue]` button.

#### API Integration:
* `GET /api/v1/cases/?page=1&page_size=20`

---

### Screen 3: Interactive Incident Creation Modal / Drawer (`/cases/new`)

#### Visual Layout & Elements:
* **Container:** 600px Centered Modal or Slide-over Right Drawer with smooth ease-in animation.
* **Header:** "Submit a New Incident / Service Request" + Close icon `✕`.
* **Form Inputs:**
  * **Request Type Toggle:** `[ Incident (Break/Fix) ]` vs `[ Service Request ]`.
  * **Subject / Title:** Single-line input (Required, min 3 chars).
  * **Service Catalog / Category Dropdown:** `Hardware`, `Software`, `Network`, `Security`, `Access & Permissions`, `Database`.
  * **Urgency & Priority Selector:** Segmented control (`P1 Critical`, `P2 High`, `P3 Medium`, `P4 Low`) displaying live SLA deadline tooltips (e.g. `P1: 15 min response / 4 hr resolution`).
  * **Description Field:** Rich Markdown-supported textarea with formatting bar (Bold, Italic, Code, List).
  * **Drag-and-Drop File Upload Area:**
    * Dashed violet/slate border dropzone: "Drop screenshots or logs here, or browse (Max 10MB)".
    * Allowed types: PNG, JPG, PDF, TXT, LOG.
    * Real-time file upload list with progress bar, magic-byte validation badge, and remove icon.
* **Footer Actions:** `[Cancel]` outline button + `[Submit Incident]` Electric Violet button with loading spinner.

#### API Integration:
* `POST /api/v1/cases/` $\rightarrow$ `{ title, description, priority, type, service_id }`
* `POST /api/v1/attachments/upload` $\rightarrow$ `multipart/form-data`

---

### Screen 4: Operator Personal Queue & Active Workload (`/cases` for Operator)

#### Visual Layout & Elements:
* **Header Row:** "Incident Workload Workbench" + Filter bar (My Assigned, Team Unassigned, At-Risk SLA, Resolved).
* **SLA Breach Warning Banner (Top):**
  * Amber/Red banner if any case has $< 15\text{ mins}$ on SLA clock: `⚠️ 2 Cases approaching SLA breach in Tier 1 Support. [Filter Now]`.
* **KPI Metric Strip (4 Small Cards):**
  * `My Open Cases: 5`
  * `Response SLA Met: 98%`
  * `Awaiting Requester: 2`
  * `Resolved Today: 8`
* **Incident Data Grid / List:**
  * Reference ID (`INC-2026-000002`).
  * SLA Timer Ticker (Live updating badge: Green `3h 12m`, Amber `14m`, Red `BREACHED`).
  * Title & Requester Name.
  * Priority (`P1`–`P4`).
  * Status Pill with quick-action hover dropdown.
  * Assignee Avatar.
  * Action button: `[Open Command Center →]`.

#### API Integration:
* `GET /api/v1/cases/?assigned_to_id={my_id}&page=1`

---

### Screen 5: Operator Flagship 3-Column Incident Command Center (`/cases/:id`)
*The ultimate all-in-one incident resolution cockpit.*

#### Column 1: Incident Metadata & SLA Health Ring (Left Column, 280px)
* **Back Navigation:** `← Back to Queue`.
* **Incident Header:** `INC-2026-000002` + Concurrency Version Badge (`v2`).
* **Lifecycle State Transition Action Group:**
  * Quick-action buttons matching valid state transitions: `[In Assessment]`, `[Assigned]`, `[Awaiting Requester]`, `[Resolved]`, `[Closed]`.
  * Transition confirmation modal requesting optional reason note.
* **SLA Progress Ring:**
  * Circular visual ring indicating elapsed vs remaining time.
  * Response SLA Deadline: `Met in 8 mins` or `Due by 14:30 (12m left)`.
  * Resolution SLA Deadline: `Due by 18:00 (3h 42m left)`.
* **Case Details Card:**
  * **Requester:** Avatar, Alice Requester (`requester@paradox.com`, `+1 555-0192`).
  * **Assignee:** Operator dropdown with team re-assign option.
  * **Service Affected:** `ERP & Database Cluster`.
  * **Risk Score Badge:** `HIGH RISK` in orange pill with computed risk factors.
* **Attachments Box:** File list with download and trash icons + storage quota meter (e.g. `2.4 MB / 50 MB`).

#### Column 2: Incident Thread & 1-Second SLA Countdown (Center Column, Flex 1)
* **Real-time SLA Header Ticker:**
  * Prominent digital countdown ticker updating every 1000ms in `JetBrains Mono`:  
    `⏳ Response SLA: 00:09:42 | Resolve SLA: 03:45:10`
  * Flashes red when $< 15\text{ mins}$ remaining or breached.
* **Optimistic Locking Conflict Banner (Conditional):**
  * Appears in amber/red when HTTP 409 Conflict occurs:  
    `⚠️ Conflict: This case was updated by another user. [Review Changes & Refresh]`
* **7-Day Reopen Warning Banner (Conditional):**
  * For closed tickets: checks `closed_at <= 7 days`. If expired, disables reopen button with tooltip: `Tickets closed > 7 days cannot be reopened.`
* **Threaded Conversation Stream:**
  * **Requester Visible Messages:** Slate card background, author badge, timestamp.
  * **Staff-Only Internal Notes:** Amber/Gold border with `🔒 Internal Note — Staff Only` header.
  * **AI Copilot Injected Messages:** Purple border with `✨ AI Finny Assist` badge.
* **Message Composer Box:**
  * Text input with formatting buttons.
  * Toggle Switch: `[ Public Message ]` vs `[ 🔒 Staff Internal Note ]`.
  * Send button (stops First Response SLA clock on public send).

#### Column 3: AI Finny Copilot Sidebar (Right Column, 360px)
* **AI Panel Header:** Finny AI sparkle icon + model status (`Gemini Flash - Ready`).
* **Tab 1: Intake Triage & Classification:**
  * Suggested Category & Priority badge.
  * Confidence Score Gauge (e.g. `92% High Confidence`).
  * Supporting Factors bullet list.
  * Missing Information alerts (e.g. `Missing VPN client version & OS build`).
* **Tab 2: Continuous Case Summary:**
  * Auto-generated 3-bullet executive timeline of the case history.
  * `[↻ Refresh Summary]` button.
* **Tab 3: Human-in-the-Loop (HITL) Communication Drafts:**
  * Draft Type Selector (`Clarification Request`, `Progress Update`, `Resolution Notice`).
  * Custom prompt input (e.g. `Ask for client certificate serial number`).
  * `[✨ Generate Draft]` button.
  * **Interactive Draft Reviewer:**
    * Editable textarea pre-populated with Finny's draft.
    * Toggle: `Send as Public Message` vs `Save as Internal Note`.
    * Action: `[✓ Approve & Post to Thread]` (automatically stops SLA clock).

#### API Integration:
* `GET /api/v1/cases/{case_id}`
* `POST /api/v1/cases/{case_id}/transition` $\rightarrow$ `{ target_status, version, reason }`
* `POST /api/v1/cases/{case_id}/messages` $\rightarrow$ `{ body, visibility }`
* `POST /api/v1/cases/{case_id}/ai/triage`
* `POST /api/v1/cases/{case_id}/ai/summarize`
* `POST /api/v1/cases/{case_id}/ai/drafts` $\rightarrow$ `{ draft_type, custom_instruction }`
* `POST /api/v1/cases/{case_id}/ai/drafts/{id}/send` $\rightarrow$ `{ edited_body, internal_only }`

---

### Screen 6: Team Lead Dispatch, Swarm & Escalation Board (`/cases` for Team Lead)

#### Visual Layout & Elements:
* **Topbar:** "Team Lead Queue Oversight", Team filter (`Tier 1 Support`, `Network Ops`), Re-assignment button.
* **Queue Health KPI Bar:**
  * Total Active Queue (e.g. `18`)
  * At-Risk SLA Cases (e.g. `3` in Amber)
  * Escalated Cases (e.g. `1` in Red)
* **Operator Availability & Workload Matrix:**
  * Horizontal avatar list showing each operator's load (e.g. `Bob: 4 tickets [Available]`, `Charlie: 7 tickets [Busy]`).
* **Interactive Kanban / Grouped Table:**
  * Columns / Tabs: `Unassigned`, `In Assessment`, `Assigned`, `Pending Vendor`, `Escalated`.
  * Case card with quick-assign avatar dropdown to distribute workload among operators.

#### API Integration:
* `GET /api/v1/cases/?team_id={team_id}`
* `POST /api/v1/cases/{case_id}/assign` $\rightarrow$ `{ assignee_id }`

---

### Screen 7: Manager Operational Analytics & Executive Briefing (`/reports`)

#### Visual Layout & Elements:
* **Topbar:** "Operational Insights & Analytics", Date Range Picker (`Last 7 Days`, `Last 30 Days`), and `[⚡ Run Immediate SLA Sweep]` trigger button.
* **AI Executive Briefing Card (Full Width):**
  * Sparkle icon + "Automated AI Executive Narrative".
  * Plain-English analytical summary generated by Gemini describing workload trends, major bottlenecks, and SLA breach root-causes.
* **KPI Metric Grid (4 Metric Tiles):**
  * Total Incident Volume (e.g. `142` with `+8% vs last week`).
  * Overall SLA Compliance Rate (e.g. `96.4%` in green ring).
  * Mean Time to Respond (MTTR) (e.g. `11.2 mins`).
  * Mean Time to Resolve (MTTR) (e.g. `3.8 hours`).
* **Visual Charts Grid (2-Column):**
  * Chart 1: **SLA Compliance by Priority Tier** (Bar chart: P1: 100%, P2: 95%, P3: 98%, P4: 100%).
  * Chart 2: **Incident Volume & Breach Trends (14 Days)** (Dual-line area chart showing daily volume vs breach counts).
* **Team & Operator Workload Table:**
  * Team / Operator Name, Active Cases, Resolved Cases, SLA Breaches, Average Resolution Time.

#### API Integration:
* `GET /api/v1/reports/summary?start_date=&end_date=`
* `GET /api/v1/reports/sla-compliance`
* `GET /api/v1/reports/team-performance`
* `GET /api/v1/reports/trends?days=14`
* `POST /api/v1/admin/sweeps/run`

---

### Screen 8: System Administrator Health Diagnostics & Background Sweeps (`/admin`)

#### Visual Layout & Elements:
* **Topbar:** "System Diagnostics & Administration".
* **Sub-Navigation Tabs:** `[ System Health ]`, `[ User Directory ]`, `[ SLA Policies ]`, `[ Audit Trail ]`.
* **System Infrastructure Status Cards:**
  * **Database Pool Status:** PostgreSQL 16 (`Connected`, 10/20 active connections, latency 1.8ms).
  * **Background Sweeper Engine:** APScheduler (`Active`, Sweeping every 5 mins, last sweep: 2m ago).
  * **Storage Service:** Supabase Storage (`Healthy`, magic-byte validation active, 42MB used).
  * **AI Provider:** Google Gemini Flash (`Operational`, quota remaining: 98%).
* **Manual Operational Action Card:**
  * "Trigger Immediate SLA & Escalation Sweep" with `[⚡ Execute Sweep Now]` button and live status response toast.

#### API Integration:
* `GET /api/v1/health`
* `POST /api/v1/admin/sweeps/run`

---

### Screen 9: Administrator User & Team Directory (`/admin/users`)

#### Visual Layout & Elements:
* **Header:** "User Directory & Access Control" + `[+ Invite User]` button.
* **Filters:** Search by name/email, filter by Role (`Requester`, `Operator`, `TeamLead`, `Manager`, `Administrator`), filter by Status (`Active`, `Inactive`).
* **User Data Table:**
  * User Name & Email.
  * Role Badge (with inline edit dropdown for Administrators).
  * Department / Team (`Tier 1 Support`, `Engineering`, `Finance`).
  * Availability Status Dot (`Available`, `Away`, `Offline`).
  * Auth Provider (`Password` vs `Google OAuth`).
  * Actions: `[Edit Details]`, `[Deactivate]`, `[Reset Password]`.

#### API Integration:
* `GET /api/v1/admin/users`
* `PATCH /api/v1/admin/users/{user_id}` $\rightarrow$ `{ role, department_id, is_active }`

---

### Screen 10: System Security Audit Trail & Timeline (`/admin/audit`)

#### Visual Layout & Elements:
* **Header:** "Security Audit Trail & Compliance Log" + Export CSV button.
* **Filter Bar:** Date range filter, Action type filter (`case_created`, `status_transitioned`, `internal_note_added`, `sla_breach_escalation`), Actor filter.
* **Audit Trail Table / Timeline:**
  * Timestamp (`YYYY-MM-DD HH:mm:ss`).
  * Actor Name & Role (`Eve SystemAdmin`, `Bob Operator`, or `System Scheduler`).
  * Event / Action (`Case Status Transitioned`).
  * Target (`Case #INC-2026-000001`).
  * Version Diff (`Old: New` $\rightarrow$ `New: In Assessment`).
  * IP Address & Client Agent.

#### API Integration:
* `GET /api/v1/admin/audit?page=1&page_size=50`

---

### Screen 11: In-App Notification Center Drawer (`/notifications`)

#### Visual Layout & Elements:
* **Container:** 380px Slide-out Right Drawer accessed via the global bell icon.
* **Header:** "Notifications" + `[Mark All as Read]` action.
* **Filter Tabs:** `All`, `SLA Alerts`, `Mentions / Notes`, `System`.
* **Notification Item List:**
  * **SLA Breach Alert:** Red icon + `Case #INC-2026-000002 has breached response SLA (15m elapsed)` + time ago (`2m ago`).
  * **Case Assignment:** Cyan icon + `You have been assigned Case #INC-2026-000005: VPN connectivity issue`.
  * **Internal Note Added:** Amber icon + `Team Lead Charlie added an internal note to INC-2026-000003`.
  * **AI Draft Ready:** Purple icon + `Finny generated a resolution draft for review`.
* **Action:** Clicking any notification marks it as read and immediately deep-links to the corresponding case command center.

#### API Integration:
* `GET /api/v1/notifications/`
* `PATCH /api/v1/notifications/{id}/read`
* `POST /api/v1/notifications/mark-all-read`

---

### Screen 12: Knowledge Base & Solution Article Browser (`/knowledge`)

#### Visual Layout & Elements:
* **Header:** "IT Knowledge Base & Standard Solutions" + `[+ New Article]` (Staff only).
* **Search Hero:** Large central search bar: "Search troubleshooting guides, error codes, and standard operating procedures...".
* **Category Grid:** `Network & VPN`, `Hardware Setup`, `Software Licenses`, `Account Access`, `Email & Communication`.
* **Article List Card View:**
  * Article Title (e.g. `Resolving Cisco AnyConnect Error 403 on Windows 11`).
  * Category Chip & View Count (`452 views`).
  * AI-Assisted Match Score (when viewed within an active incident).
  * Last Updated Date (`Updated 3 days ago by Bob Operator`).
* **Article Detail Modal / View:**
  * Markdown rendered troubleshooting steps with copyable code snippets.
  * `[Insert Solution into Incident Thread]` button (when launched from Operator Command Center).
  * Feedback Widget: "Did this resolve the issue? [👍 Yes] [👎 No]".

#### API Integration:
* `GET /api/v1/knowledge/articles?query=&category=`
* `GET /api/v1/knowledge/articles/{id}`
* `POST /api/v1/knowledge/articles` $\rightarrow$ `{ title, content, category, tags }`

---

## 4. Stitch Master Prompt for Complete Platform Generation

Copy and paste the exact master prompt below into Stitch:

```text
Design a complete, high-fidelity, production-ready enterprise UI/UX system for "AsistIQ" (Paradox Helpdesk), an AI-assisted, human-in-the-loop IT incident management platform.

### Design Language & Tokens:
- Theme: "Stitch Obsidian" — Cyber-Enterprise dark mode.
- Color Palette: Background #090A0F, Surfaces & Sidebar #12141C, Cards & Containers #181B26, Borders #222636.
- Interactive Accents: Electric Violet (#7C3AED) as primary interactive CTA, Cyan Glow (#06B6D4) for identifiers and active tags, Emerald Green (#10B981) for resolved/healthy states, Amber (#F59E0B) for pending/warning states, and Crimson (#EF4444) for P1 Critical and SLA breaches.
- Typography: Inter for UI structure and typography; JetBrains Mono for incident reference IDs (e.g. INC-2026-000001), timestamps, and live countdown timers.

### Complete Screen Architecture to Generate:

1. GLOBAL NAVIGATION & APP SHELL:
   - Left navigation sidebar (collapsible) with violet lightning logo, role pill badge, dynamic role-based navigation links, user avatar with online status dot, and logout button.
   - Top header with global search bar (Ctrl+K) and notification bell with unread badge counter.

2. DUAL AUTHENTICATION SCREEN (/login):
   - Centered Obsidian card with subtle violet rim glow.
   - Google OAuth full-width button, email/password form inputs, remember me, and "Sign In →" gradient CTA.
   - 5 Quick Role-Switcher chips at bottom: Requester, Operator, Team Lead, Manager, Administrator.

3. REQUESTER SELF-SERVICE PORTAL (/cases):
   - "+ New Incident" CTA button.
   - 2 KPI metric cards: Active Tickets (purple) and Resolved/Closed (green).
   - Clean tabular cards for tickets with cyan mono reference numbers, category chips, priority badges (P1-P4), and lifecycle status badges.

4. CREATE INCIDENT MODAL / DRAWER (/cases/new):
   - Slide-over drawer with title, request type toggle (Incident vs Service Request), category dropdown, priority selector with SLA tooltips, markdown description editor, and drag-and-drop file attachment zone (PNG/JPG/PDF/LOG).

5. OPERATOR QUEUE WORKBENCH (/cases for Operator):
   - SLA breach warning banner (alerts when < 15 mins remain).
   - 4 KPI metric tiles: My Open Cases, Response SLA Met (98%), Awaiting Requester, Resolved Today.
   - Incident queue table with live SLA timer countdown badges (green/amber/red).

6. OPERATOR 3-COLUMN INCIDENT COMMAND CENTER (/cases/:id):
   - LEFT COLUMN (280px): Case metadata, version number (v2), lifecycle state transition buttons (In Assessment, Assigned, Awaiting Requester, Resolved, Closed), circular SLA deadline progress ring, assignee selector, and attachment list with quota meter.
   - CENTER COLUMN (Flex 1): Real-time SLA digital ticker (Response: 00:09:42 | Resolve: 03:45:10) in monospace; optimistic locking conflict banner (when HTTP 409 occurs); threaded conversation stream separating requester visible messages, gold-bordered staff internal notes, and AI assist messages; bottom message composer with [Public Message] vs [Internal Note] toggle.
   - RIGHT COLUMN (360px): "Finny AI Copilot" panel with:
     * Intake Triage: suggested category/priority, 92% confidence gauge, supporting factors, and missing info warnings.
     * Continuous Summary: 3-bullet automated case synopsis with refresh button.
     * HITL Drafts: draft type selector, custom instructions prompt, "Generate Draft" CTA, and editable reviewer box with 1-click "Approve & Send" (stops SLA clock).

7. TEAM LEAD DISPATCH & SWARM WORKBENCH (/cases for Team Lead):
   - Operator capacity and availability matrix (e.g. Bob: 4 tickets [Available]).
   - Grouped Kanban queue with quick-assign avatar dropdowns to re-assign workload across operators.

8. MANAGER OPERATIONAL INSIGHTS DASHBOARD (/reports):
   - Date range selector and "Run Immediate SLA Sweep" trigger.
   - Full-width AI Executive Briefing card with automated plain-language summary of bottlenecks and root causes.
   - 4 KPI cards: Total Volume, SLA Compliance Rate (96.4%), MTTR Response (11.2m), MTTR Resolve (3.8h).
   - Priority Tier SLA breakdown bar chart + 14-day volume vs breach dual-line area chart.
   - Team and operator workload handling table.

9. SYSTEM ADMINISTRATOR HEALTH & DIAGNOSTICS (/admin):
   - PostgreSQL connection pool status, APScheduler sweeper status, Supabase storage quota, and Gemini AI status.
   - "Trigger Immediate SLA Sweep" operational action card.

10. USER & TEAM DIRECTORY (/admin/users):
    - Search and filter by role and active status.
    - User table with inline role changer, department assignment, and online status toggle.

11. SECURITY AUDIT TRAIL (/admin/audit):
    - Event timeline table with timestamp, actor, event action, target ID, and state diff before/after.

12. NOTIFICATION DRAWER & KNOWLEDGE BASE:
    - Slide-out notification drawer with SLA alerts, case assignments, and deep links.
    - Knowledge base search with solution articles and 1-click "Insert Solution into Incident Thread".
```
