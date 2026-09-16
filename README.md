# Paradox / AsistIQ — AI IT Helpdesk

> An AI-assisted, human-controlled IT service desk for Incident and Service Request management.

## 🚀 Overview
Paradox / AsistIQ is a production-ready IT service desk built on free-tier infrastructure. It provides end-to-end management for **Incidents** and **Service Requests**, pairing human accountability with 11 automated AI capabilities powered by Google Gemini.

## 🏗️ Architecture & Tech Stack
* **Frontend:** Single Flutter codebase targeting Mobile (Android, iOS), Desktop (Windows, macOS, Linux), and Web.
* **Backend:** FastAPI (Python 3.11+) with Layered Clean Architecture.
* **Database & Storage:** PostgreSQL (Supabase) + Supabase Storage, managed via SQLAlchemy ORM and Alembic migrations.
* **Background Sweeps:** In-process APScheduler for 24/7 SLA tracking, risk evaluation, and auto-escalations.
* **AI Provider:** Google Gemini API via an abstracted `AIProvider` interface.
* **Email Delivery:** Gmail SMTP (Local Dev) / Brevo HTTP API (Staging & Production).

## 📂 Project Structure
```text
AsistIQ/
├── client/                      # Flutter multi-platform application
├── backend/                     # FastAPI backend
├── docs/                        # PRD, SRS v3.3, and architecture docs
├── scripts/                     # Seed and utility scripts
├── docker-compose.yml           # Local dev infrastructure
└── .gitignore
```

## 📖 Documentation
Detailed specifications are available in the [`docs/`](./docs) folder:
* [Product Requirements Document (PRD)](./docs/Ultimate_Master_AI_IT_Helpdesk_PRD_Revised.md)
* [Software Requirements Specification (SRS v3.3)](./docs/RAS_AI_IT_Helpdesk_SRS_v3.3.md)
* [Agents Rules & Governance](./AGENTS.md)
