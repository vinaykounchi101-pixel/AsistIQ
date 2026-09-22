from contextlib import asynccontextmanager
import os
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, RedirectResponse
from backend.core.config import settings
from backend.api.health import router as health_router
from backend.api.auth.routes import router as auth_router
from backend.api.cases.routes import router as cases_router
from backend.api.messages.routes import router as messages_router
from backend.api.ai.routes import router as ai_router
from backend.api.admin.routes import router as admin_router
from backend.api.reports.routes import router as reports_router
from backend.api.releases import router as releases_router
from backend.scheduler.scheduler import start_scheduler, shutdown_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Validate required environment variables
    settings.validate_startup_secrets()
    # In production and staging, start the background scheduler automatically
    if settings.ENVIRONMENT in ["staging", "production"]:
        start_scheduler(interval_minutes=5)
    yield
    # Shutdown logic
    shutdown_scheduler()


app = FastAPI(
    title=settings.APP_NAME,
    description="AI-assisted, human-controlled IT Helpdesk API (SRS v3.3)",
    version="1.0.0",
    lifespan=lifespan
)

# CORS Configuration (SRS v3.3 §3.7)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:[0-9]+)?",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Root Health / Ping
@app.get("/", tags=["Root"])
def root():
    return {
        "app": settings.APP_NAME,
        "environment": settings.ENVIRONMENT,
        "status": "online"
    }

# Register API v1 Routers
app.include_router(health_router, prefix=settings.API_V1_PREFIX)
app.include_router(auth_router, prefix=settings.API_V1_PREFIX)
app.include_router(cases_router, prefix=settings.API_V1_PREFIX)
app.include_router(messages_router, prefix=settings.API_V1_PREFIX)
app.include_router(ai_router, prefix=settings.API_V1_PREFIX)
app.include_router(admin_router, prefix=settings.API_V1_PREFIX)
app.include_router(reports_router, prefix=settings.API_V1_PREFIX)
app.include_router(releases_router, prefix=settings.API_V1_PREFIX)

# Stitch UI Direct Web Serving Routes
STITCH_DIR = Path(__file__).resolve().parent.parent / "stitch_asistiq_incident_management_platform"

@app.get("/ui", tags=["Stitch UI"])
def get_stitch_ui_index():
    return RedirectResponse(url="/ui/requester")

@app.get("/ui/requester", tags=["Stitch UI"])
def get_stitch_requester_ui():
    file_path = STITCH_DIR / "requester_portal_incident_drawer_nordic_light_pastel" / "code.html"
    if file_path.exists():
        return FileResponse(file_path)
    return {"error": "Stitch requester UI not found"}

@app.get("/ui/operator", tags=["Stitch UI"])
def get_stitch_operator_ui():
    file_path = STITCH_DIR / "operator_workbench_airy_pastel_light" / "code.html"
    if file_path.exists():
        return FileResponse(file_path)
    return {"error": "Stitch operator UI not found"}

@app.get("/ui/command-center", tags=["Stitch UI"])
def get_stitch_command_center_ui():
    file_path = STITCH_DIR / "incident_command_center_nordic_light_pastel" / "code.html"
    if file_path.exists():
        return FileResponse(file_path)
    return {"error": "Stitch command center UI not found"}

@app.get("/ui/manager", tags=["Stitch UI"])
def get_stitch_manager_ui():
    file_path = STITCH_DIR / "manager_operational_insights_nordic_light_pastel" / "code.html"
    if file_path.exists():
        return FileResponse(file_path)
    return {"error": "Stitch manager UI not found"}
