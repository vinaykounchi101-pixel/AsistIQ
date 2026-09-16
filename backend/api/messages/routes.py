import uuid
from typing import Dict, Any
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from backend.db.session import get_db
from backend.models.user import User
from backend.models.enums import UserRole
from backend.api.deps import get_current_user, require_roles
from backend.services.message_service import MessageService
from backend.services.storage_service import StorageService
from backend.schemas.message import (
    CreateMessageRequest,
    MessageResponse,
    MessageListResponse,
    AttachmentResponse,
    AttachmentListResponse,
)

router = APIRouter(prefix="/cases/{case_id}", tags=["Case Messages & Attachments"])


@router.post(
    "/messages",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add a message or internal note to a case",
)
def add_message(
    case_id: uuid.UUID,
    request: CreateMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MessageResponse:
    """
    Adds a message or internal note to a case (SRS v3.3 §4.5).
    Requesters can ONLY post `requester_visible` messages.
    Staff roles can post either `requester_visible` or `internal_only` notes.
    """
    service = MessageService(db)
    return service.create_message(case_id, request, current_user)


@router.get(
    "/messages",
    response_model=MessageListResponse,
    summary="List all messages and notes for a case",
)
def list_messages(
    case_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MessageListResponse:
    """
    Lists messages for a case.
    Requesters only receive `requester_visible` messages.
    Staff roles receive both `requester_visible` and `internal_only` notes.
    """
    service = MessageService(db)
    return service.get_case_messages(case_id, current_user)


@router.post(
    "/attachments",
    response_model=AttachmentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload an attachment to a case",
)
async def upload_attachment(
    case_id: uuid.UUID,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AttachmentResponse:
    """
    Uploads a file attachment to Supabase Storage (SRS v3.3 §7.5).
    Validates magic bytes, max 10MB per file, max 50MB per case quota.
    """
    service = StorageService(db)
    return await service.upload_attachment(case_id, file, current_user)


@router.get(
    "/attachments",
    response_model=AttachmentListResponse,
    summary="List all attachments for a case",
)
async def list_attachments(
    case_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AttachmentListResponse:
    """
    Lists all attachments for a case along with storage quota usage.
    """
    service = StorageService(db)
    return await service.list_case_attachments(case_id, current_user)


@router.get(
    "/attachments/{attachment_id}/download",
    summary="Get secure signed download URL for an attachment",
)
async def get_attachment_download_url(
    case_id: uuid.UUID,
    attachment_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """
    Generates a secure, time-limited download URL for a case attachment.
    """
    service = StorageService(db)
    download_url = await service.get_download_url(case_id, attachment_id, current_user)
    return {"attachment_id": attachment_id, "download_url": download_url}


@router.delete(
    "/attachments/{attachment_id}",
    status_code=status.HTTP_200_OK,
    summary="Delete an attachment",
)
async def delete_attachment(
    case_id: uuid.UUID,
    attachment_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """
    Deletes an attachment from storage and removes its record.
    Allowed for the original uploader or Admin/Manager/Lead roles.
    """
    service = StorageService(db)
    await service.delete_attachment(case_id, attachment_id, current_user)
    return {"success": True, "message": "Attachment deleted successfully."}
