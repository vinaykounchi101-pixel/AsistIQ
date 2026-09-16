import uuid
from typing import Optional
from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.orm import Session
from backend.db.session import get_db
from backend.models.user import User
from backend.models.enums import CaseStatus, CasePriority, CaseType
from backend.services.case_service import CaseService
from backend.api.deps import get_current_verified_user
from backend.schemas.case import (
    CaseCreateSchema, CaseUpdateSchema, CaseTransitionSchema,
    CaseResponseSchema, CaseListResponseSchema
)

router = APIRouter(prefix="/cases", tags=["Cases"])


@router.post("/", response_model=CaseResponseSchema, status_code=status.HTTP_201_CREATED)
def create_case(
    data: CaseCreateSchema,
    current_user: User = Depends(get_current_verified_user),
    db: Session = Depends(get_db)
):
    """
    Create a new Incident or Service Request (SRS v3.3 §6).
    """
    case = CaseService.create_case(db, current_user, data)
    return CaseResponseSchema.model_validate(case)


@router.get("/", response_model=CaseListResponseSchema, status_code=status.HTTP_200_OK)
def list_cases(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    status: Optional[CaseStatus] = None,
    priority: Optional[CasePriority] = None,
    case_type: Optional[CaseType] = None,
    search: Optional[str] = None,
    current_user: User = Depends(get_current_verified_user),
    db: Session = Depends(get_db)
):
    """
    List permitted cases with pagination, filters, and search (SRS v3.3 §3.6, §7.6).
    """
    items, total = CaseService.list_cases(
        db=db,
        user=current_user,
        page=page,
        page_size=page_size,
        status=status,
        priority=priority,
        case_type=case_type,
        search=search
    )
    return CaseListResponseSchema(
        items=[CaseResponseSchema.model_validate(c) for c in items],
        page=page,
        page_size=page_size,
        total=total
    )


@router.get("/{case_id}", response_model=CaseResponseSchema, status_code=status.HTTP_200_OK)
def get_case(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_verified_user),
    db: Session = Depends(get_db)
):
    """
    Get full case details including SLA health (SRS v3.3 §7.6).
    """
    case = CaseService.get_case(db, current_user, case_id)
    return CaseResponseSchema.model_validate(case)


@router.patch("/{case_id}", response_model=CaseResponseSchema, status_code=status.HTTP_200_OK)
def update_case(
    case_id: uuid.UUID,
    data: CaseUpdateSchema,
    current_user: User = Depends(get_current_verified_user),
    db: Session = Depends(get_db)
):
    """
    Update case metadata with optimistic concurrency locking (SRS v3.3 §7.12).
    """
    case = CaseService.update_case(db, current_user, case_id, data)
    return CaseResponseSchema.model_validate(case)


@router.post("/{case_id}/transition", response_model=CaseResponseSchema, status_code=status.HTTP_200_OK)
def transition_case_status(
    case_id: uuid.UUID,
    data: CaseTransitionSchema,
    current_user: User = Depends(get_current_verified_user),
    db: Session = Depends(get_db)
):
    """
    Perform a lifecycle state transition with optimistic locking & 7-day reopen check (SRS §6, §6.1).
    """
    case = CaseService.transition_status(db, current_user, case_id, data)
    return CaseResponseSchema.model_validate(case)
