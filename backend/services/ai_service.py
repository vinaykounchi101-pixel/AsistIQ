import os
import uuid
from datetime import datetime
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from backend.audit.audit_service import AuditService
from backend.models.ai import AITriageResult, CaseSummary, CommunicationDraft
from backend.models.enums import (
    ConfidenceLevel, DraftStatus, DraftType, MessageVisibility, UserRole
)
from backend.models.user import User
from backend.providers.ai import get_ai_provider
from backend.providers.ai.base import AIProvider
from backend.repositories.ai_repository import (
    AITriageRepository, CaseSummaryRepository, DraftRepository
)
from backend.repositories.case_repository import CaseRepository
from backend.repositories.message_repository import MessageRepository


PROMPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ai", "prompts")


def _read_prompt(filename: str) -> str:
    path = os.path.join(PROMPTS_DIR, filename)
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class AIService:
    """
    Business logic for Paradox AI Engine (SRS v3.3 §7.1, §7.14, §9).
    Orchestrates Prompt Assembly, Provider Execution, HITL Draft Workflow, and Database Persistence.
    """

    @staticmethod
    def triage_case(
        db: Session,
        case_id: uuid.UUID,
        provider: Optional[AIProvider] = None,
        actor: Optional[User] = None
    ) -> AITriageResult:
        case = CaseRepository.get_by_id(db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        ai = provider or get_ai_provider()
        template = _read_prompt("intake_triage_v1.txt")
        prompt = template.format(
            title=case.title,
            description=case.description,
            case_type=case.type.value if case.type else "Incident",
            priority=case.priority.value if case.priority else "Unspecified",
            requester_name=case.requester.full_name if case.requester else "Unknown"
        )


        triage_dict = ai.generate_triage(prompt)
        result = AITriageRepository.upsert(db, case_id, triage_dict, commit=True)

        AuditService.log_action(
            db=db,
            action="AI_TRIAGE_GENERATED",
            target_type="case",
            target_id=str(case_id),
            actor_id=actor.id if actor else None,
            after_value={
                "category": result.suggested_category,
                "priority": result.suggested_priority,
                "confidence_level": result.confidence_level.value,
                "confidence_score": result.confidence_score
            },
            commit=True
        )

        return result

    @staticmethod
    def summarize_case(
        db: Session,
        case_id: uuid.UUID,
        provider: Optional[AIProvider] = None,
        actor: Optional[User] = None
    ) -> CaseSummary:
        case = CaseRepository.get_by_id(db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        # Retrieve messages (including internal notes for staff synthesis)
        message_repo = MessageRepository(db)
        messages = message_repo.get_messages_by_case(case_id, include_internal=True)

        history_lines = []
        last_msg_id = None
        for msg in messages:
            last_msg_id = msg.id
            sender_name = msg.author.full_name if msg.author else "System"
            role = msg.author.role.value if msg.author else "System"
            vis = "Staff Note" if msg.visibility == MessageVisibility.INTERNAL_ONLY else "Public Reply"
            history_lines.append(f"[{msg.created_at.strftime('%Y-%m-%d %H:%M')}] {sender_name} ({role}) - {vis}:\n{msg.body}\n")

        history_text = "\n".join(history_lines) if history_lines else "No messages recorded yet."

        ai = provider or get_ai_provider()
        template = _read_prompt("continuous_summary_v1.txt")
        prompt = template.format(
            reference_number=case.reference_number,
            title=case.title,
            status=case.status.value,
            priority=case.priority.value if case.priority else "Unset",
            created_at=case.created_at.strftime("%Y-%m-%d %H:%M UTC"),
            description=case.description,
            message_history=history_text
        )

        summary_text = ai.generate_summary(prompt)
        summary = CaseSummaryRepository.upsert(
            db=db,
            case_id=case_id,
            summary_text=summary_text,
            last_source_message_id=last_msg_id,
            commit=True
        )

        AuditService.log_action(
            db=db,
            action="AI_SUMMARY_UPDATED",
            target_type="case",
            target_id=str(case_id),
            actor_id=actor.id if actor else None,
            after_value={"summary_id": str(summary.id)},
            commit=True
        )

        return summary

    @staticmethod
    def generate_draft(
        db: Session,
        case_id: uuid.UUID,
        draft_type: DraftType,
        custom_instruction: Optional[str] = None,
        provider: Optional[AIProvider] = None,
        actor: Optional[User] = None
    ) -> CommunicationDraft:
        case = CaseRepository.get_by_id(db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        # Get existing summary or use description
        existing_summary = CaseSummaryRepository.get_by_case_id(db, case_id)
        summary_text = existing_summary.summary_text if existing_summary else case.description

        ai = provider or get_ai_provider()
        template = _read_prompt("communication_draft_v1.txt")
        prompt = template.format(
            reference_number=case.reference_number,
            title=case.title,
            requester_name=case.requester.full_name if case.requester else "Customer",
            status=case.status.value,
            priority=case.priority.value if case.priority else "Unset",
            case_summary=summary_text,
            draft_type=draft_type.value,
            custom_instruction=custom_instruction or "None provided."
        )

        draft_body = ai.generate_draft(prompt)
        draft = DraftRepository.create(
            db=db,
            case_id=case_id,
            draft_type=draft_type,
            body=draft_body,
            commit=True
        )

        AuditService.log_action(
            db=db,
            action="AI_DRAFT_GENERATED",
            target_type="case",
            target_id=str(case_id),
            actor_id=actor.id if actor else None,
            after_value={"draft_id": str(draft.id), "draft_type": draft_type.value},
            commit=True
        )

        return draft

    @staticmethod
    def list_drafts(db: Session, case_id: uuid.UUID) -> List[CommunicationDraft]:
        return DraftRepository.list_by_case_id(db, case_id)

    @staticmethod
    def send_draft(
        db: Session,
        case_id: uuid.UUID,
        draft_id: uuid.UUID,
        reviewer: User,
        edited_body: Optional[str] = None,
        internal_only: bool = False
    ) -> CommunicationDraft:
        case = CaseRepository.get_by_id(db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        draft = DraftRepository.get_by_id(db, draft_id)
        if not draft or draft.case_id != case_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Draft with ID '{draft_id}' not found for this case."
            )

        if draft.status != DraftStatus.DRAFT:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Draft is already in '{draft.status.value}' state and cannot be sent again."
            )

        final_body = edited_body.strip() if edited_body and edited_body.strip() else draft.body
        visibility = (
            MessageVisibility.INTERNAL_ONLY
            if internal_only
            else MessageVisibility.REQUESTER_VISIBLE
        )

        # Create message with ai_generated = True
        msg_repo = MessageRepository(db)
        message = msg_repo.create_message(
            case_id=case_id,
            author_id=reviewer.id,
            body=final_body,
            visibility=visibility,
            ai_generated=True
        )

        # First response SLA clock stop if requester-visible message by staff
        if reviewer.role != UserRole.REQUESTER and visibility == MessageVisibility.REQUESTER_VISIBLE:
            if case.sla and case.sla.first_responded_at is None:
                case.sla.first_responded_at = datetime.utcnow()
                if case.sla.target_response_at and case.sla.first_responded_at > case.sla.target_response_at:
                    case.sla.response_breached = True
                else:
                    case.sla.response_breached = False
                db.commit()

        # Mark draft as sent
        updated_draft = DraftRepository.mark_sent(
            db=db,
            draft=draft,
            reviewer_id=reviewer.id,
            sent_message_id=message.id,
            commit=True
        )

        AuditService.log_action(
            db=db,
            action="AI_DRAFT_APPROVED_AND_SENT",
            target_type="case",
            target_id=str(case_id),
            actor_id=reviewer.id,
            after_value={
                "draft_id": str(draft.id),
                "message_id": str(message.id),
                "was_edited": bool(edited_body and edited_body.strip() != draft.body)
            },
            commit=True
        )

        return updated_draft
