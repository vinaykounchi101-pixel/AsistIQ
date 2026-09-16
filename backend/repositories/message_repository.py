import uuid
from typing import List, Optional
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from backend.models.message import Message, Attachment
from backend.models.enums import MessageVisibility


class MessageRepository:
    """Repository for Message and Attachment data access."""

    def __init__(self, db: Session):
        self.db = db

    def create_message(
        self,
        case_id: uuid.UUID,
        author_id: uuid.UUID,
        body: str,
        visibility: MessageVisibility = MessageVisibility.REQUESTER_VISIBLE,
        ai_generated: bool = False
    ) -> Message:
        message = Message(
            case_id=case_id,
            author_id=author_id,
            body=body,
            visibility=visibility,
            ai_generated=ai_generated,
        )
        self.db.add(message)
        self.db.commit()
        self.db.refresh(message)
        return message

    def get_messages_by_case(
        self,
        case_id: uuid.UUID,
        include_internal: bool = True
    ) -> List[Message]:
        query = (
            self.db.query(Message)
            .options(joinedload(Message.author))
            .filter(Message.case_id == case_id)
        )
        if not include_internal:
            query = query.filter(Message.visibility == MessageVisibility.REQUESTER_VISIBLE)

        return query.order_by(Message.created_at.asc()).all()

    def create_attachment(
        self,
        case_id: uuid.UUID,
        uploaded_by: uuid.UUID,
        storage_path: str,
        file_name: str,
        file_type: str,
        size_bytes: int
    ) -> Attachment:
        attachment = Attachment(
            case_id=case_id,
            uploaded_by=uploaded_by,
            storage_path=storage_path,
            file_name=file_name,
            file_type=file_type,
            size_bytes=size_bytes,
        )
        self.db.add(attachment)
        self.db.commit()
        self.db.refresh(attachment)
        return attachment

    def get_attachments_by_case(self, case_id: uuid.UUID) -> List[Attachment]:
        return (
            self.db.query(Attachment)
            .options(joinedload(Attachment.uploader))
            .filter(Attachment.case_id == case_id)
            .order_by(Attachment.created_at.desc())
            .all()
        )

    def get_attachment_by_id(self, attachment_id: uuid.UUID) -> Optional[Attachment]:
        return (
            self.db.query(Attachment)
            .options(joinedload(Attachment.uploader))
            .filter(Attachment.id == attachment_id)
            .first()
        )

    def get_total_attachments_size(self, case_id: uuid.UUID) -> int:
        """Returns total bytes used by attachments for a given case."""
        result = (
            self.db.query(func.coalesce(func.sum(Attachment.size_bytes), 0))
            .filter(Attachment.case_id == case_id)
            .scalar()
        )
        return int(result or 0)

    def delete_attachment(self, attachment_id: uuid.UUID) -> bool:
        attachment = self.get_attachment_by_id(attachment_id)
        if not attachment:
            return False
        self.db.delete(attachment)
        self.db.commit()
        return True
