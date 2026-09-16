import uuid
from datetime import datetime
from typing import Optional, List, Tuple
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import select, func, and_, or_
from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.enums import CaseType, CaseStatus, CasePriority


class CaseRepository:
    @staticmethod
    def generate_reference_number(db: Session, case_type: CaseType) -> str:
        """
        Generate sequential case reference number (SRS v3.3 §4.2): <TYPE>-<YEAR>-<sequential>
        e.g. INC-2026-000001 or SR-2026-000002
        """
        year = datetime.utcnow().year
        prefix = "INC" if case_type == CaseType.INCIDENT else "SR"

        stmt = select(func.count(Case.id)).where(
            func.extract("year", Case.created_at) == year
        )
        count = db.execute(stmt).scalar() or 0
        return f"{prefix}-{year}-{count + 1:06d}"

    @staticmethod
    def get_by_id(db: Session, case_id: uuid.UUID) -> Optional[Case]:
        """Fetch active case by UUID with SLA relationship eager loaded."""
        stmt = (
            select(Case)
            .options(joinedload(Case.sla))
            .where(and_(Case.id == case_id, Case.deleted_at.is_(None)))
        )
        return db.execute(stmt).scalar_one_or_none()

    @staticmethod
    def get_by_reference(db: Session, ref_no: str) -> Optional[Case]:
        """Fetch active case by reference number."""
        stmt = (
            select(Case)
            .options(joinedload(Case.sla))
            .where(and_(Case.reference_number == ref_no.strip().upper(), Case.deleted_at.is_(None)))
        )
        return db.execute(stmt).scalar_one_or_none()

    @staticmethod
    def create(
        db: Session,
        reference_number: str,
        title: str,
        description: str,
        case_type: CaseType,
        priority: CasePriority,
        requester_id: uuid.UUID,
        site: Optional[str] = None,
        service_id: Optional[uuid.UUID] = None,
        target_response_at: Optional[datetime] = None,
        target_resolve_at: Optional[datetime] = None
    ) -> Case:
        """Atomically create a Case and its associated SLA record."""
        case = Case(
            reference_number=reference_number,
            type=case_type,
            title=title.strip(),
            description=description.strip(),
            status=CaseStatus.NEW,
            priority=priority,
            requester_id=requester_id,
            service_id=service_id,
            site=site,
            version=1
        )
        db.add(case)
        db.flush()

        if target_response_at and target_resolve_at:
            sla = SLA(
                case_id=case.id,
                target_response_at=target_response_at,
                target_resolve_at=target_resolve_at,
                response_breached=False,
                resolve_breached=False
            )
            db.add(sla)

        db.commit()
        db.refresh(case)
        return case

    @staticmethod
    def update_with_version_check(
        db: Session,
        case: Case,
        expected_version: int,
        **kwargs
    ) -> Tuple[Optional[Case], bool]:
        """
        Update case fields while strictly verifying optimistic locking version (SRS v3.3 §7.12).
        Returns (updated_case, True) on success, or (case, False) if version conflict.
        """
        if case.version != expected_version:
            return case, False

        for key, value in kwargs.items():
            if hasattr(case, key) and value is not None:
                setattr(case, key, value)

        case.version += 1
        case.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(case)
        return case, True

    @staticmethod
    def list_cases(
        db: Session,
        skip: int = 0,
        limit: int = 20,
        requester_id: Optional[uuid.UUID] = None,
        owner_id: Optional[uuid.UUID] = None,
        team_id: Optional[uuid.UUID] = None,
        status: Optional[CaseStatus] = None,
        priority: Optional[CasePriority] = None,
        case_type: Optional[CaseType] = None,
        search: Optional[str] = None
    ) -> Tuple[List[Case], int]:
        """
        List cases with multi-criteria filtering, pagination, and total count.
        """
        conditions = [Case.deleted_at.is_(None)]

        if requester_id:
            conditions.append(Case.requester_id == requester_id)
        if owner_id:
            conditions.append(Case.owner_id == owner_id)
        if team_id:
            conditions.append(Case.team_id == team_id)
        if status:
            conditions.append(Case.status == status)
        if priority:
            conditions.append(Case.priority == priority)
        if case_type:
            conditions.append(Case.type == case_type)
        if search:
            search_pattern = f"%{search.strip()}%"
            conditions.append(
                or_(
                    Case.reference_number.ilike(search_pattern),
                    Case.title.ilike(search_pattern),
                    Case.description.ilike(search_pattern)
                )
            )

        base_stmt = select(Case).options(joinedload(Case.sla)).where(and_(*conditions))
        total_stmt = select(func.count(Case.id)).where(and_(*conditions))

        total = db.execute(total_stmt).scalar() or 0
        items = list(db.execute(base_stmt.order_by(Case.created_at.desc()).offset(skip).limit(limit)).scalars().all())

        return items, total
