import abc
from typing import Optional, Set

# Limits per SRS v3.3 §7.5
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024       # 10 MB per file
MAX_CASE_STORAGE_BYTES = 50 * 1024 * 1024   # 50 MB total per case

ALLOWED_MIME_TYPES: Set[str] = {
    "image/png",
    "image/jpeg",
    "image/webp",
    "application/pdf",
    "text/plain",
    "text/csv",
    "application/json",
    "text/x-log",
}

# Magic-byte headers for signature verification
MAGIC_SIGNATURES = {
    "image/png": [b"\x89PNG\r\n\x1a\n"],
    "image/jpeg": [b"\xff\xd8\xff"],
    "image/webp": [b"RIFF"],  # Starts with RIFF and has WEBP at offset 8
    "application/pdf": [b"%PDF-"],
}


class StorageProvider(abc.ABC):
    """Abstract storage provider interface for case attachments."""

    @abc.abstractmethod
    async def upload_file(
        self,
        file_bytes: bytes,
        destination_path: str,
        content_type: str
    ) -> str:
        """Uploads file bytes to the storage provider and returns the storage path."""
        pass

    @abc.abstractmethod
    async def get_download_url(
        self,
        storage_path: str,
        expires_in_seconds: int = 3600
    ) -> str:
        """Generates a secure, time-limited download or signed URL."""
        pass

    @abc.abstractmethod
    async def delete_file(self, storage_path: str) -> bool:
        """Deletes a file from storage."""
        pass

    @staticmethod
    def validate_magic_bytes(file_bytes: bytes, content_type: str) -> bool:
        """
        Validates the binary magic-byte header against the declared MIME type (SRS §7.5).
        Returns True if valid, False otherwise.
        """
        if not file_bytes:
            return False

        if content_type not in ALLOWED_MIME_TYPES:
            return False

        # Binary formats with fixed signatures
        if content_type in MAGIC_SIGNATURES:
            if content_type == "image/webp":
                return file_bytes.startswith(b"RIFF") and len(file_bytes) >= 12 and file_bytes[8:12] == b"WEBP"
            return any(file_bytes.startswith(sig) for sig in MAGIC_SIGNATURES[content_type])

        # Text-based formats (text/plain, text/csv, application/json, text/x-log)
        try:
            sample = file_bytes[:4096]
            if b"\x00" in sample:
                return False
            sample.decode("utf-8")
            return True
        except UnicodeDecodeError:
            return False
