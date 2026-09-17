from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID
from sqlalchemy.orm import Session

from backend.models.ai import AITriageResult, CaseSummary, CommunicationDraft
from backend.models.enums import ConfidenceLevel, DraftStatus, DraftType


class AITriageRepository:
    @staticmethod
    def get_by_case_id(db: Session, case_id: UUID) -> Optional[AITriageResult]:
        return db.query(AITriageResult).filter(AITriageResult.case_id == case_id).first()

    @staticmethod
    def upsert(
        db: Session,
        case_id: UUID,
        triage_data: Dict[str, Any],
        commit: bool = True
    ) -> AITriageResult:
        existing = db.query(AITriageResult).filter(AITriageResult.case_id == case_id).first()

        # Parse confidence level safely
        conf_level_val = triage_data.get("confidence_level")
        if isinstance(conf_level_val, str):
            try:
                conf_level = ConfidenceLevel(conf_level_val)
            except ValueError:
                conf_level = ConfidenceLevel.MODERATE
        else:
            conf_level = conf_level_val or ConfidenceLevel.MODERATE

        conf_score = float(triage_data.get("confidence_score", 0.75))
        # Ensure score stays in [0.0, 1.0]
        conf_score = max(0.0, min(1.0, conf_score))

        if existing:
            existing.suggested_category = triage_data.get("suggested_category")
            existing.suggested_severity = triage_data.get("suggested_severity")
            existing.suggested_priority = triage_data.get("suggested_priority")
            existing.confidence_level = conf_level
            existing.confidence_score = conf_score
            existing.supporting_factors = triage_data.get("supporting_factors", [])
            existing.missing_info = triage_data.get("missing_info", [])
            existing.suggested_team = triage_data.get("suggested_team")
            existing.recommended_next_action = triage_data.get("recommended_next_action")
            existing.related_case_ids = triage_data.get("related_case_ids", [])
            existing.created_at = datetime.utcnow()
            result = existing
        else:
            result = AITriageResult(
                case_id=case_id,
                suggested_category=triage_data.get("suggested_category"),
                suggested_severity=triage_data.get("suggested_severity"),
                suggested_priority=triage_data.get("suggested_priority"),
                confidence_level=conf_level,
                confidence_score=conf_score,
                supporting_factors=triage_data.get("supporting_factors", []),
                missing_info=triage_data.get("missing_info", []),
                suggested_team=triage_data.get("suggested_team"),
                recommended_next_action=triage_data.get("recommended_next_action"),
                related_case_ids=triage_data.get("related_case_ids", [])
            )
            db.add(result)

        if commit:
            db.commit()
            db.refresh(result)
        return result


class CaseSummaryRepository:
    @staticmethod
    def get_by_case_id(db: Session, case_id: UUID) -> Optional[CaseSummary]:
        return db.query(CaseSummary).filter(CaseSummary.case_id == case_id).first()

    @staticmethod
    def upsert(
        db: Session,
        case_id: UUID,
        summary_text: str,
        last_source_message_id: Optional[UUID] = None,
        commit: bool = True
    ) -> CaseSummary:
        existing = db.query(CaseSummary).filter(CaseSummary.case_id == case_id).first()
        if existing:
            existing.summary_text = summary_text
            existing.last_source_message_id = last_source_message_id
            existing.updated_at = datetime.utcnow()
            result = existing
        else:
            result = CaseSummary(
                case_id=case_id,
                summary_text=summary_text,
                last_source_message_id=last_source_message_id,
                updated_at=datetime.utcnow()
            )
            db.add(result)

        if commit:
            db.commit()
            db.refresh(result)
        return result


class DraftRepository:
    @staticmethod
    def create(
        db: Session,
        case_id: UUID,
        draft_type: DraftType,
        body: str,
        commit: bool = True
    ) -> CommunicationDraft:
        draft = CommunicationDraft(
            case_id=case_id,
            draft_type=draft_type,
            body=body,
            status=DraftStatus.DRAFT
        )
        db.add(draft)
        if commit:
            db.commit()
            db.refresh(draft)
        return draft

    @staticmethod
    def get_by_id(db: Session, draft_id: UUID) -> Optional[CommunicationDraft]:
        return db.query(CommunicationDraft).filter(CommunicationDraft.id == draft_id).first()

    @staticmethod
    def list_by_case_id(db: Session, case_id: UUID) -> List[CommunicationDraft]:
        return (
            db.query(CommunicationDraft)
            .filter(CommunicationDraft.case_id == case_id)
            .order_by(CommunicationDraft.created_at.desc())
            .all()
        )

    @staticmethod
    def mark_sent(
        db: Session,
        draft: CommunicationDraft,
        reviewer_id: UUID,
        sent_message_id: UUID,
        commit: bool = True
    ) -> CommunicationDraft:
        draft.status = DraftStatus.SENT
        draft.reviewed_by = reviewer_id
        draft.sent_message_id = sent_message_id
        if commit:
            db.commit()
            db.refresh(draft)
        return draft
