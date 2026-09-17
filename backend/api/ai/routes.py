import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_db, require_roles
from backend.models.enums import UserRole
from backend.models.user import User
from backend.schemas.ai import (
    AITriageResponse, CaseSummaryResponse, DraftCreateRequest,
    DraftResponse, DraftSendRequest
)
from backend.services.ai_service import AIService

router = APIRouter(prefix="/cases/{case_id}/ai", tags=["AI Engine"])

STAFF_ROLES = [
    UserRole.OPERATOR,
    UserRole.TEAM_LEAD,
    UserRole.MANAGER,
    UserRole.ADMINISTRATOR,
]


@router.post(
    "/triage",
    response_model=AITriageResponse,
    status_code=status.HTTP_200_OK,
    summary="Trigger or refresh AI intake triage for a case (SRS v3.3 §7.1)"
)
def triage_case(
    case_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(*STAFF_ROLES))
):
    result = AIService.triage_case(db=db, case_id=case_id, actor=current_user)
    return result


@router.post(
    "/summarize",
    response_model=CaseSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Generate or refresh continuous case summary (SRS v3.3 §7.1)"
)
def summarize_case(
    case_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(*STAFF_ROLES))
):
    summary = AIService.summarize_case(db=db, case_id=case_id, actor=current_user)
    return summary


@router.post(
    "/drafts",
    response_model=DraftResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Generate contextual communication draft (SRS v3.3 §7.1)"
)
def generate_draft(
    case_id: uuid.UUID,
    request: DraftCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(*STAFF_ROLES))
):
    draft = AIService.generate_draft(
        db=db,
        case_id=case_id,
        draft_type=request.draft_type,
        custom_instruction=request.custom_instruction,
        actor=current_user
    )
    return draft


@router.get(
    "/drafts",
    response_model=List[DraftResponse],
    status_code=status.HTTP_200_OK,
    summary="List all generated communication drafts for a case"
)
def list_drafts(
    case_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(*STAFF_ROLES))
):
    drafts = AIService.list_drafts(db=db, case_id=case_id)
    return drafts


@router.post(
    "/drafts/{draft_id}/send",
    response_model=DraftResponse,
    status_code=status.HTTP_200_OK,
    summary="Human-in-the-loop review: approve, edit, and post draft as case message (SRS v3.3 §7.1, §9)"
)
def send_draft(
    case_id: uuid.UUID,
    draft_id: uuid.UUID,
    request: DraftSendRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(*STAFF_ROLES))
):
    sent_draft = AIService.send_draft(
        db=db,
        case_id=case_id,
        draft_id=draft_id,
        reviewer=current_user,
        edited_body=request.edited_body,
        internal_only=request.internal_only
    )
    return sent_draft
