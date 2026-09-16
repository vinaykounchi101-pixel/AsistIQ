import pytest
from backend.providers.auth.password_hasher import PasswordHasher
from backend.providers.auth.jwt_provider import JWTProvider
from backend.models.enums import UserRole


def test_password_hashing():
    raw_password = "SecurePassword123!"
    hashed = PasswordHasher.hash_password(raw_password)
    assert hashed != raw_password
    assert PasswordHasher.verify_password(raw_password, hashed) is True
    assert PasswordHasher.verify_password("WrongPassword123!", hashed) is False
    assert PasswordHasher.verify_password(raw_password, "") is False


def test_jwt_lifecycle():
    user_id = "11111111-1111-1111-1111-111111111111"
    email = "testuser@asistiq.com"
    role = UserRole.REQUESTER.value

    # 1. Access Token
    access_token = JWTProvider.create_access_token(
        subject=user_id,
        role=role,
        email=email
    )
    payload = JWTProvider.decode_token(access_token)
    assert payload["sub"] == user_id
    assert payload["role"] == role
    assert payload["email"] == email
    assert payload["type"] == "access"

    # 2. Refresh Token
    refresh_token = JWTProvider.create_refresh_token(subject=user_id)
    ref_payload = JWTProvider.decode_token(refresh_token)
    assert ref_payload["sub"] == user_id
    assert ref_payload["type"] == "refresh"

    # 3. Verification Token
    verify_token = JWTProvider.create_verification_token(email=email)
    ver_payload = JWTProvider.decode_token(verify_token)
    assert ver_payload["sub"] == email
    assert ver_payload["type"] == "email_verification"


def test_invalid_token():
    with pytest.raises(ValueError):
        JWTProvider.decode_token("invalid.token.signature")
