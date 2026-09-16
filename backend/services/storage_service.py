import os
import re
import uuid
from typing import List, Optional
from fastapi import HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from backend.models.user import User
from backend.models.case import Case
from backend.models.message import Attachment
from backend.models.enums import UserRole
from backend.repositories.case_repository import CaseRepository
from backend.repositories.message_repository import MessageRepository
from backend.providers.storage.base import (
    StorageProvider,
    MAX_FILE_SIZE_BYTES,
    MAX_CASE_STORAGE_BYTES,
    ALLOWED_MIME_TYPES,
)
from backend.providers.storage.supabase_storage import SupabaseStorageProvider
from backend.audit.audit_service import AuditService
from backend.schemas.message import AttachmentResponse, AttachmentListResponse


class StorageService:
    """Business logic for Case File Attachments (SRS v3.3 §7.5)."""

    def __init__(self, db: Session, storage_provider: Optional[StorageProvider] = None):
        self.db = db
        self.message_repo = MessageRepository(db)
        self.storage_provider = storage_provider or SupabaseStorageProvider()

    @staticmethod
    def _sanitize_filename(filename: str) -> str:
        base_name = os.path.basename(filename)
        cleaned = re.sub(r"[^a-zA-Z0-9_.-]", "_", base_name)
        return cleaned or "attachment.bin"

    async def upload_attachment(
        self,
        case_id: uuid.UUID,
        file: UploadFile,
        current_user: User
    ) -> AttachmentResponse:
        case = CaseRepository.get_by_id(self.db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        # Access check: Requester can only attach to their own case
        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to attach files to this case."
            )

        # Read file bytes
        file_bytes = await file.read()
        file_size = len(file_bytes)

        if file_size == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded file is empty."
            )

        # 1. Check max file size limit (10 MB)
        if file_size > MAX_FILE_SIZE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail=f"File size exceeds the maximum allowed limit of {MAX_FILE_SIZE_BYTES // (1024 * 1024)} MB."
            )

        # 2. Check cumulative case storage quota (50 MB)
        current_case_storage = self.message_repo.get_total_attachments_size(case_id)
        if (current_case_storage + file_size) > MAX_CASE_STORAGE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Uploading this file would exceed the case total storage quota of {MAX_CASE_STORAGE_BYTES // (1024 * 1024)} MB."
            )

        # 3. MIME type & magic-byte signature validation
        content_type = file.content_type or "application/octet-stream"
        if content_type not in ALLOWED_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File type '{content_type}' is not allowed. Supported formats: Images, PDF, TXT, CSV, JSON, LOG."
            )

        is_valid_signature = self.storage_provider.validate_magic_bytes(file_bytes, content_type)
        if not is_valid_signature:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File content signature does not match the declared MIME type (magic-byte validation failed)."
            )

        # 4. Upload to storage provider
        sanitized_filename = self._sanitize_filename(file.filename or "attachment")
        storage_filename = f"{uuid.uuid4().hex[:12]}_{sanitized_filename}"
        storage_path = f"cases/{case_id}/{storage_filename}"

        await self.storage_provider.upload_file(
            file_bytes=file_bytes,
            destination_path=storage_path,
            content_type=content_type
        )

        # 5. Persist attachment record
        attachment = self.message_repo.create_attachment(
            case_id=case_id,
            uploaded_by=current_user.id,
            storage_path=storage_path,
            file_name=sanitized_filename,
            file_type=content_type,
            size_bytes=file_size
        )

        # 6. Audit log
        AuditService.log_action(
            db=self.db,
            action="ATTACHMENT_ADDED",
            target_type="case",
            target_id=str(case_id),
            actor_id=current_user.id,
            after_value={
                "attachment_id": str(attachment.id),
                "file_name": attachment.file_name,
                "size_bytes": attachment.size_bytes,
                "file_type": attachment.file_type
            },
            commit=True
        )

        download_url = await self.storage_provider.get_download_url(attachment.storage_path)

        return AttachmentResponse(
            id=attachment.id,
            case_id=attachment.case_id,
            uploaded_by=attachment.uploaded_by,
            uploader_name=current_user.full_name,
            file_name=attachment.file_name,
            file_type=attachment.file_type,
            size_bytes=attachment.size_bytes,
            download_url=download_url,
            created_at=attachment.created_at,
        )

    async def list_case_attachments(
        self,
        case_id: uuid.UUID,
        current_user: User
    ) -> AttachmentListResponse:
        case = CaseRepository.get_by_id(self.db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to view attachments for this case."
            )

        attachments = self.message_repo.get_attachments_by_case(case_id)
        total_used = sum(att.size_bytes for att in attachments)

        items = []
        for att in attachments:
            download_url = await self.storage_provider.get_download_url(att.storage_path)
            items.append(
                AttachmentResponse(
                    id=att.id,
                    case_id=att.case_id,
                    uploaded_by=att.uploaded_by,
                    uploader_name=att.uploader.full_name if att.uploader else "Unknown",
                    file_name=att.file_name,
                    file_type=att.file_type,
                    size_bytes=att.size_bytes,
                    download_url=download_url,
                    created_at=att.created_at,
                )
            )

        return AttachmentListResponse(
            items=items,
            total_bytes_used=total_used,
            quota_bytes=MAX_CASE_STORAGE_BYTES,
        )

    async def get_download_url(
        self,
        case_id: uuid.UUID,
        attachment_id: uuid.UUID,
        current_user: User
    ) -> str:
        case = CaseRepository.get_by_id(self.db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to access attachments on this case."
            )

        attachment = self.message_repo.get_attachment_by_id(attachment_id)
        if not attachment or attachment.case_id != case_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Attachment with ID '{attachment_id}' not found."
            )

        return await self.storage_provider.get_download_url(attachment.storage_path)

    async def delete_attachment(
        self,
        case_id: uuid.UUID,
        attachment_id: uuid.UUID,
        current_user: User
    ) -> bool:
        case = CaseRepository.get_by_id(self.db, case_id)
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Case with ID '{case_id}' not found."
            )

        attachment = self.message_repo.get_attachment_by_id(attachment_id)
        if not attachment or attachment.case_id != case_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Attachment with ID '{attachment_id}' not found."
            )

        # Deletion permission: Uploader, Administrator, Manager, or TeamLead
        is_uploader = attachment.uploaded_by == current_user.id
        is_admin_or_lead = current_user.role in (UserRole.ADMINISTRATOR, UserRole.MANAGER, UserRole.TEAM_LEAD)
        if not (is_uploader or is_admin_or_lead):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to delete this attachment."
            )

        # Delete from storage provider
        await self.storage_provider.delete_file(attachment.storage_path)

        # Delete from repository
        self.message_repo.delete_attachment(attachment_id)

        # Audit log
        AuditService.log_action(
            db=self.db,
            action="ATTACHMENT_DELETED",
            target_type="case",
            target_id=str(case_id),
            actor_id=current_user.id,
            after_value={
                "attachment_id": str(attachment_id),
                "file_name": attachment.file_name,
            },
            commit=True
        )

        return True
