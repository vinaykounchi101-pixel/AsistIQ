import uuid
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from backend.models.audit import AuditLog


class AuditService:
    @staticmethod
    def log_action(
        db: Session,
        action: str,
        target_type: str,
        target_id: str,
        actor_id: Optional[uuid.UUID] = None,
        before_value: Optional[Dict[str, Any]] = None,
        after_value: Optional[Dict[str, Any]] = None,
        commit: bool = False
    ) -> AuditLog:
        """
        Record an append-only audit log entry (SRS v3.3 §4, §5.11).
        Actor ID is None for system-triggered sweep events.
        """
        entry = AuditLog(
            actor_id=actor_id,
            action=action,
            target_type=target_type,
            target_id=str(target_id),
            before_value=before_value,
            after_value=after_value
        )
        db.add(entry)
        if commit:
            db.commit()
            db.refresh(entry)
        return entry
