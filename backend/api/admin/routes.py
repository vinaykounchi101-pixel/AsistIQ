from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from backend.api.deps import get_db, require_roles
from backend.models.enums import UserRole
from backend.models.user import User
from backend.schemas.sweep import SweepSummaryResponse
from backend.services.sweep_service import SweepService

router = APIRouter(prefix="/admin", tags=["Administration"])

ADMIN_AND_MANAGERS = [UserRole.MANAGER, UserRole.ADMINISTRATOR]


@router.post(
    "/sweeps/run",
    response_model=SweepSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Trigger immediate on-demand SLA & Risk sweep (SRS v3.3 §4.3, §7.1)"
)
def run_manual_sweep(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(*ADMIN_AND_MANAGERS))
):
    """
    Executes a comprehensive background sweep manually on demand.
    Audits SLA deadlines, recomputes risk levels, and triggers auto-escalations.
    """
    summary = SweepService.execute_sweep(
        db=db,
        triggered_by=f"manual_{current_user.email}"
    )
    return summary
