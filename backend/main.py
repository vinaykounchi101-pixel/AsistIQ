from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.core.config import settings
from backend.api.health import router as health_router
from backend.api.auth.routes import router as auth_router
from backend.api.cases.routes import router as cases_router
from backend.api.messages.routes import router as messages_router
from backend.api.ai.routes import router as ai_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Validate required environment variables
    settings.validate_startup_secrets()
    yield
    # Shutdown logic (if any)


app = FastAPI(
    title=settings.APP_NAME,
    description="AI-assisted, human-controlled IT Helpdesk API (SRS v3.3)",
    version="1.0.0",
    lifespan=lifespan
)

# CORS Configuration (SRS v3.3 §3.7 - strict allowed origins, never '*')
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
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

