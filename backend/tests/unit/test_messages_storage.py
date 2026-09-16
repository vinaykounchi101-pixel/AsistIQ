import io
import uuid
from datetime import datetime
import pytest
from fastapi import HTTPException, UploadFile
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.db.session import Base
from backend.models.user import User
from backend.models.case import Case
from backend.models.sla import SLA
from backend.models.message import Message, Attachment
from backend.models.enums import UserRole, CasePriority, CaseStatus, CaseType, MessageVisibility
from backend.providers.storage.base import (
    StorageProvider,
    MAX_FILE_SIZE_BYTES,
    MAX_CASE_STORAGE_BYTES,
)
from backend.providers.storage.local_storage import LocalStorageProvider
from backend.providers.storage.supabase_storage import SupabaseStorageProvider
from backend.repositories.message_repository import MessageRepository
from backend.repositories.case_repository import CaseRepository
from backend.services.message_service import MessageService
from backend.services.storage_service import StorageService
from backend.schemas.message import CreateMessageRequest


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", echo=False)
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def test_users(db_session):
    requester = User(
        id=uuid.uuid4(),
        email="requester@test.com",
        full_name="Alice Requester",
        role=UserRole.REQUESTER,
        email_verified=True,
    )
    operator = User(
        id=uuid.uuid4(),
        email="operator@test.com",
        full_name="Bob Operator",
        role=UserRole.OPERATOR,
        email_verified=True,
    )
    admin = User(
        id=uuid.uuid4(),
        email="admin@test.com",
        full_name="Charlie Admin",
        role=UserRole.ADMINISTRATOR,
        email_verified=True,
    )
    db_session.add_all([requester, operator, admin])
    db_session.commit()
    return {"requester": requester, "operator": operator, "admin": admin}


@pytest.fixture
def test_case(db_session, test_users):
    case = Case(
        id=uuid.uuid4(),
        reference_number="INC-2026-000001",
        title="VPN Connection Failure",
        description="Cannot reach internal resources",
        type=CaseType.INCIDENT,
        priority=CasePriority.P2,
        status=CaseStatus.NEW,
        requester_id=test_users["requester"].id,
    )
    sla = SLA(
        id=uuid.uuid4(),
        case_id=case.id,
        target_response_at=datetime.utcnow(),
        target_resolve_at=datetime.utcnow(),
    )
    db_session.add(case)
    db_session.add(sla)
    db_session.commit()
    return case


# --- 1. Magic Byte Validation Tests ---

def test_magic_byte_validation_png():
    valid_png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
    assert StorageProvider.validate_magic_bytes(valid_png, "image/png") is True

    fake_png = b"MZ\x90\x00"  # Windows PE executable header
    assert StorageProvider.validate_magic_bytes(fake_png, "image/png") is False


def test_magic_byte_validation_jpeg():
    valid_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF"
    assert StorageProvider.validate_magic_bytes(valid_jpeg, "image/jpeg") is True

    fake_jpeg = b"<!DOCTYPE html><html>"
    assert StorageProvider.validate_magic_bytes(fake_jpeg, "image/jpeg") is False


def test_magic_byte_validation_pdf():
    valid_pdf = b"%PDF-1.7\n%raw content"
    assert StorageProvider.validate_magic_bytes(valid_pdf, "application/pdf") is True

    fake_pdf = b"NOT_A_PDF_FILE"
    assert StorageProvider.validate_magic_bytes(fake_pdf, "application/pdf") is False


def test_magic_byte_validation_text_and_json():
    valid_txt = b"Hello, this is a plain text log file."
    assert StorageProvider.validate_magic_bytes(valid_txt, "text/plain") is True

    valid_json = b'{"status": "ok", "error": null}'
    assert StorageProvider.validate_magic_bytes(valid_json, "application/json") is True

    binary_disguised_as_txt = b"Text content with hidden null \x00 byte executable payload"
    assert StorageProvider.validate_magic_bytes(binary_disguised_as_txt, "text/plain") is False


# --- 2. Message Body HTML Sanitization ---

def test_message_body_sanitization():
    req = CreateMessageRequest(
        body="<script>alert('xss')</script>Hello <b>world</b>!",
        visibility=MessageVisibility.REQUESTER_VISIBLE
    )
    assert "<script>" not in req.body
    assert "<b>" not in req.body
    assert "alert('xss')Hello world!" in req.body


# --- 3. Message Visibility & Role Isolation Tests ---

def test_requester_can_post_public_message(db_session, test_users, test_case):
    service = MessageService(db_session)
    req = CreateMessageRequest(
        body="I still cannot connect to the server.",
        visibility=MessageVisibility.REQUESTER_VISIBLE
    )
    msg = service.create_message(test_case.id, req, test_users["requester"])
    assert msg.body == "I still cannot connect to the server."
    assert msg.visibility == MessageVisibility.REQUESTER_VISIBLE


def test_requester_cannot_post_internal_note(db_session, test_users, test_case):
    service = MessageService(db_session)
    req = CreateMessageRequest(
        body="Trying to sneak an internal note",
        visibility=MessageVisibility.INTERNAL_ONLY
    )
    with pytest.raises(HTTPException) as exc_info:
        service.create_message(test_case.id, req, test_users["requester"])
    assert exc_info.value.status_code == 403
    assert "not permitted to create internal-only notes" in exc_info.value.detail


def test_operator_can_post_internal_note(db_session, test_users, test_case):
    service = MessageService(db_session)
    req = CreateMessageRequest(
        body="Checking firewall rule on node #4.",
        visibility=MessageVisibility.INTERNAL_ONLY
    )
    msg = service.create_message(test_case.id, req, test_users["operator"])
    assert msg.visibility == MessageVisibility.INTERNAL_ONLY


def test_message_visibility_filtering(db_session, test_users, test_case):
    service = MessageService(db_session)

    # 1 public message + 1 internal note
    service.create_message(
        test_case.id,
        CreateMessageRequest(body="Public message 1", visibility=MessageVisibility.REQUESTER_VISIBLE),
        test_users["requester"]
    )
    service.create_message(
        test_case.id,
        CreateMessageRequest(body="Staff secret note", visibility=MessageVisibility.INTERNAL_ONLY),
        test_users["operator"]
    )

    # Requester views messages: should only see 1 message
    requester_msgs = service.get_case_messages(test_case.id, test_users["requester"])
    assert requester_msgs.total == 1
    assert requester_msgs.items[0].body == "Public message 1"

    # Operator views messages: should see both 2 messages
    operator_msgs = service.get_case_messages(test_case.id, test_users["operator"])
    assert operator_msgs.total == 2


# --- 4. Storage Quota & File Upload Tests ---

@pytest.mark.asyncio
async def test_file_size_limit_exceeded(db_session, test_users, test_case):
    storage_provider = LocalStorageProvider()
    service = StorageService(db_session, storage_provider=storage_provider)

    oversized_content = b"A" * (MAX_FILE_SIZE_BYTES + 1024)
    upload_file = UploadFile(filename="huge.txt", file=io.BytesIO(oversized_content), headers={"content-type": "text/plain"})

    with pytest.raises(HTTPException) as exc_info:
        await service.upload_attachment(test_case.id, upload_file, test_users["requester"])
    assert exc_info.value.status_code == 413


@pytest.mark.asyncio
async def test_valid_attachment_upload_and_quota(db_session, test_users, test_case):
    storage_provider = LocalStorageProvider()
    service = StorageService(db_session, storage_provider=storage_provider)

    valid_png_content = b"\x89PNG\r\n\x1a\n" + b"\x00" * 200
    upload_file = UploadFile(
        filename="screenshot.png",
        file=io.BytesIO(valid_png_content),
        headers={"content-type": "image/png"}
    )

    attachment = await service.upload_attachment(test_case.id, upload_file, test_users["requester"])
    assert attachment.file_name == "screenshot.png"
    assert attachment.size_bytes == len(valid_png_content)
    assert attachment.download_url is not None

    # Check listing
    attachments_list = await service.list_case_attachments(test_case.id, test_users["requester"])
    assert len(attachments_list.items) == 1
    assert attachments_list.total_bytes_used == len(valid_png_content)
    assert attachments_list.quota_bytes == MAX_CASE_STORAGE_BYTES
