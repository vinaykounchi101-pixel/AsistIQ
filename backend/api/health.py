from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from backend.db.session import get_db

router = APIRouter(tags=["Health"])


@router.get("/health", status_code=status.HTTP_200_OK)
def health_check(db: Session = Depends(get_db)):
    """
    Health check endpoint (SRS v3.3 §3.8).
    Verifies database connectivity without calling external AI providers.
    """
    db_status = "ok"
    db_error = None
    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        db_status = "error"
        # Sanitize and extract high-level error reason without exposing secrets
        db_error = str(e).splitlines()[-1] if str(e).splitlines() else str(e)

    response = {
        "status": "ok" if db_status == "ok" else "degraded",
        "db": db_status
    }
    if db_error:
        response["db_error"] = db_error
    return response
