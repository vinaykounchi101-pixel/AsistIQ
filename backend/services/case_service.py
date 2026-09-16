import uuid
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from backend.models.user import User
from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.enums import CaseStatus, CaseType, CasePriority, UserRole
from backend.repositories.case_repository import CaseRepository
from backend.services.sla_service import SLAService
from backend.audit.audit_service import AuditService
from backend.schemas.case import CaseCreateSchema, CaseUpdateSchema, CaseTransitionSchema


class CaseService:
    # Allowed state machine transitions (SRS v3.3 §6.1)
    VALID_TRANSITIONS: Dict[CaseStatus, List[CaseStatus]] = {
        CaseStatus.DRAFT: [CaseStatus.NEW],
        CaseStatus.NEW: [CaseStatus.IN_ASSESSMENT, CaseStatus.CANCELLED],
        CaseStatus.IN_ASSESSMENT: [CaseStatus.ASSIGNED],
        CaseStatus.ASSIGNED: [
            CaseStatus.AWAITING_REQUESTER,
            CaseStatus.AWAITING_APPROVAL,
            CaseStatus.RESOLVED,
            CaseStatus.CANCELLED,
            CaseStatus.ASSIGNED  # Reassignment / owner change
        ],
        CaseStatus.AWAITING_REQUESTER: [CaseStatus.ASSIGNED],
        CaseStatus.AWAITING_APPROVAL: [CaseStatus.ASSIGNED],
        CaseStatus.PENDING: [CaseStatus.ASSIGNED],
        CaseStatus.RESOLVED: [CaseStatus.CLOSED, CaseStatus.ASSIGNED],
        CaseStatus.CLOSED: [CaseStatus.ASSIGNED],  # Reopen within 7 days (SRS §6)
        CaseStatus.CANCELLED: [],
    }

    @classmethod
    def create_case(cls, db: Session, user: User, data: CaseCreateSchema) -> Case:
        """Create a new Incident or Service Request with 24/7 SLA (SRS v3.3 §4.2, §4.3)."""
        ref_no = CaseRepository.generate_reference_number(db, data.type)
        resp_deadline, res_deadline = SLAService.calculate_deadlines(data.priority)

        case = CaseRepository.create(
            db=db,
            reference_number=ref_no,
            title=data.title,
            description=data.description,
            case_type=data.type,
            priority=data.priority,
            requester_id=user.id,
            site=data.site or user.site,
            service_id=data.service_id,
            target_response_at=resp_deadline,
            target_resolve_at=res_deadline
        )

        AuditService.log_action(
            db=db,
            actor_id=user.id,
            action="case_created",
            target_type="Case",
            target_id=str(case.id),
            after_value={"reference": case.reference_number, "priority": case.priority.value},
            commit=True
        )

        return case

    @classmethod
    def get_case(cls, db: Session, user: User, case_id: uuid.UUID) -> Case:
        """Get case detail enforcing role-based visibility (SRS v3.3 §7.6)."""
        case = CaseRepository.get_by_id(db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "CASE_NOT_FOUND", "message": "Case not found."}
            )

        # Requesters may only view their own cases
        if user.role == UserRole.REQUESTER and case.requester_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"code": "PERMISSION_DENIED", "message": "You do not have access to view this case."}
            )

        return case

    @classmethod
    def update_case(cls, db: Session, user: User, case_id: uuid.UUID, data: CaseUpdateSchema) -> Case:
        """Update case fields with optimistic locking verification (SRS v3.3 §7.12)."""
        case = cls.get_case(db, user, case_id)

        # Requesters cannot update case metadata directly
        if user.role == UserRole.REQUESTER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"code": "PERMISSION_DENIED", "message": "Requesters cannot modify case metadata."}
            )

        # Priority overrides require Lead, Manager, or Admin role
        if data.priority and data.priority != case.priority:
            if user.role not in [UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={"code": "PERMISSION_DENIED", "message": "Priority overrides require Team Lead or Manager authority."}
                )

        update_kwargs = data.model_dump(exclude_unset=True, exclude={"version"})
        before_state = {"priority": case.priority.value, "owner_id": str(case.owner_id) if case.owner_id else None}

        updated_case, success = CaseRepository.update_with_version_check(
            db=db,
            case=case,
            expected_version=data.version,
            **update_kwargs
        )

        if not success:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "STALE_VERSION",
                    "message": "This case was updated by someone else. Please reload to see the latest version."
                }
            )

        AuditService.log_action(
            db=db,
            actor_id=user.id,
            action="case_updated",
            target_type="Case",
            target_id=str(updated_case.id),
            before_value=before_state,
            after_value=update_kwargs,
            commit=True
        )

        return updated_case

    @classmethod
    def transition_status(cls, db: Session, user: User, case_id: uuid.UUID, data: CaseTransitionSchema) -> Case:
        """Execute validated lifecycle state transition (SRS v3.3 §6, §6.1)."""
        case = cls.get_case(db, user, case_id)

        allowed_targets = cls.VALID_TRANSITIONS.get(case.status, [])
        if data.target_status not in allowed_targets:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "code": "INVALID_STATE_TRANSITION",
                    "message": f"Cannot transition case from '{case.status.value}' to '{data.target_status.value}'."
                }
            )

        # Handle Reopen rule: allowed within 7 calendar days of closed_at (SRS §6)
        if case.status == CaseStatus.CLOSED and data.target_status == CaseStatus.ASSIGNED:
            if case.closed_at and (datetime.utcnow() - case.closed_at) > timedelta(days=7):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={
                        "code": "REOPEN_WINDOW_EXPIRED",
                        "message": "Cases cannot be reopened more than 7 calendar days after closure."
                    }
                )
            # Reset SLA for reopened case
            resp_deadline, res_deadline = SLAService.calculate_deadlines(case.priority)
            if case.sla:
                case.sla.target_response_at = resp_deadline
                case.sla.target_resolve_at = res_deadline
                case.sla.response_breached = False
                case.sla.resolve_breached = False

        # Status specific timestamp handling
        resolved_at = case.resolved_at
        closed_at = case.closed_at

        if data.target_status == CaseStatus.RESOLVED:
            resolved_at = datetime.utcnow()
        elif data.target_status == CaseStatus.CLOSED:
            closed_at = datetime.utcnow()

        before_state = {"status": case.status.value, "version": case.version}

        updated_case, success = CaseRepository.update_with_version_check(
            db=db,
            case=case,
            expected_version=data.version,
            status=data.target_status,
            resolved_at=resolved_at,
            closed_at=closed_at
        )

        if not success:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "STALE_VERSION",
                    "message": "This case was updated by someone else. Please reload to see the latest version."
                }
            )

        AuditService.log_action(
            db=db,
            actor_id=user.id,
            action="case_status_transition",
            target_type="Case",
            target_id=str(updated_case.id),
            before_value=before_state,
            after_value={"status": updated_case.status.value, "reason": data.reason},
            commit=True
        )

        return updated_case

    @classmethod
    def list_cases(
        cls,
        db: Session,
        user: User,
        page: int = 1,
        page_size: int = 20,
        status: Optional[CaseStatus] = None,
        priority: Optional[CasePriority] = None,
        case_type: Optional[CaseType] = None,
        search: Optional[str] = None
    ) -> Tuple[List[Case], int]:
        """List cases with role filtering and pagination (SRS v3.3 §3.6)."""
        skip = (page - 1) * page_size
        requester_id = user.id if user.role == UserRole.REQUESTER else None

        return CaseRepository.list_cases(
            db=db,
            skip=skip,
            limit=page_size,
            requester_id=requester_id,
            status=status,
            priority=priority,
            case_type=case_type,
            search=search
        )
