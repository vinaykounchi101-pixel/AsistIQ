import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from backend.models.user import User
from backend.models.case import Case
from backend.models.message import Message
from backend.models.enums import UserRole, MessageVisibility
from backend.repositories.case_repository import CaseRepository
from backend.repositories.message_repository import MessageRepository
from backend.services.sla_service import SLAService
from backend.audit.audit_service import AuditService
from backend.schemas.message import CreateMessageRequest, MessageResponse, MessageListResponse


class MessageService:
    """Business logic for Case Messages and Internal Notes (SRS v3.3 §4.5)."""

    def __init__(self, db: Session):
        self.db = db
        self.message_repo = MessageRepository(db)

    def create_message(
        self,
        case_id: uuid.UUID,
        request: CreateMessageRequest,
        current_user: User
    ) -> MessageResponse:
        case = CaseRepository.get_by_id(self.db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        # Access check: Requesters can only access their own cases
        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to post messages to this case."
            )

        # Visibility rule: Requesters CANNOT post internal notes (SRS §4.5)
        if current_user.role == UserRole.REQUESTER and request.visibility == MessageVisibility.INTERNAL_ONLY:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Requesters are not permitted to create internal-only notes."
            )

        # Create message
        message = self.message_repo.create_message(
            case_id=case_id,
            author_id=current_user.id,
            body=request.body,
            visibility=request.visibility,
            ai_generated=False
        )

        # First Response SLA clock stop (SRS §4.3):
        # If staff posts the first requester-visible message, record first_responded_at
        if current_user.role != UserRole.REQUESTER and request.visibility == MessageVisibility.REQUESTER_VISIBLE:
            if case.sla and case.sla.first_responded_at is None:
                case.sla.first_responded_at = datetime.utcnow()
                if case.sla.target_response_at and case.sla.first_responded_at > case.sla.target_response_at:
                    case.sla.response_breached = True
                else:
                    case.sla.response_breached = False
                self.db.commit()

        # Audit logging
        action_name = (
            "NOTE_ADDED"
            if request.visibility == MessageVisibility.INTERNAL_ONLY
            else "MESSAGE_ADDED"
        )
        AuditService.log_action(
            db=self.db,
            action=action_name,
            target_type="case",
            target_id=str(case_id),
            actor_id=current_user.id,
            after_value={
                "message_id": str(message.id),
                "visibility": message.visibility.value,
                "is_staff_reply": current_user.role != UserRole.REQUESTER
            },
            commit=True
        )

        return MessageResponse(
            id=message.id,
            case_id=message.case_id,
            author_id=message.author_id,
            author_name=current_user.full_name,
            author_role=current_user.role.value,
            body=message.body,
            visibility=message.visibility,
            ai_generated=message.ai_generated,
            created_at=message.created_at,
        )

    def get_case_messages(
        self,
        case_id: uuid.UUID,
        current_user: User
    ) -> MessageListResponse:
        case = CaseRepository.get_by_id(self.db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        # Requesters can only view their own cases
        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to view messages for this case."
            )

        # Requesters NEVER see internal notes (SRS §4.5)
        include_internal = current_user.role != UserRole.REQUESTER
        messages = self.message_repo.get_messages_by_case(case_id, include_internal=include_internal)

        items = [
            MessageResponse(
                id=msg.id,
                case_id=msg.case_id,
                author_id=msg.author_id,
                author_name=msg.author.full_name if msg.author else "Unknown",
                author_role=msg.author.role.value if msg.author else "Unknown",
                body=msg.body,
                visibility=msg.visibility,
                ai_generated=msg.ai_generated,
                created_at=msg.created_at,
            )
            for msg in messages
        ]

        return MessageListResponse(items=items, total=len(items))
