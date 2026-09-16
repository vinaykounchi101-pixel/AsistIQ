import os
import logging
from typing import Optional
from backend.providers.storage.base import StorageProvider

logger = logging.getLogger(__name__)


class LocalStorageProvider(StorageProvider):
    """
    Local filesystem storage provider for testing or offline development (SRS §3.2).
    """

    def __init__(self, base_directory: str = "temp_storage"):
        self.base_directory = base_directory
        os.makedirs(self.base_directory, exist_ok=True)

    async def upload_file(
        self,
        file_bytes: bytes,
        destination_path: str,
        content_type: str
    ) -> str:
        full_path = os.path.join(self.base_directory, destination_path)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, "wb") as f:
            f.write(file_bytes)
        return destination_path

    async def get_download_url(
        self,
        storage_path: str,
        expires_in_seconds: int = 3600
    ) -> str:
        # Returns local file path URI or mock signed link
        return f"/api/v1/storage/local/{storage_path}"

    async def delete_file(self, storage_path: str) -> bool:
        full_path = os.path.join(self.base_directory, storage_path)
        if os.path.exists(full_path):
            os.remove(full_path)
            return True
        return False
