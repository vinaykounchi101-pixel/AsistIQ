import httpx
import logging
from typing import Optional
from backend.core.config import settings
from backend.providers.storage.base import StorageProvider

logger = logging.getLogger(__name__)


class SupabaseStorageProvider(StorageProvider):
    """
    Supabase Storage Provider implementing direct REST API operations
    for case attachments per SRS v3.3 §7.5.
    """

    def __init__(
        self,
        supabase_url: Optional[str] = None,
        supabase_key: Optional[str] = None,
        bucket_name: Optional[str] = None
    ):
        self.supabase_url = (supabase_url or settings.SUPABASE_URL).rstrip("/")
        self.supabase_key = supabase_key or settings.SUPABASE_KEY
        self.bucket_name = bucket_name or settings.SUPABASE_STORAGE_BUCKET
        self.storage_base_url = f"{self.supabase_url}/storage/v1"

    @property
    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.supabase_key}",
            "apikey": self.supabase_key,
        }

    async def upload_file(
        self,
        file_bytes: bytes,
        destination_path: str,
        content_type: str
    ) -> str:
        """
        Uploads file bytes to the Supabase Storage bucket.
        Path format: cases/{case_id}/{uuid}_{file_name}
        """
        # If in local mock mode without live Supabase credentials
        if self.supabase_url.startswith("https://mock") or not self.supabase_key or self.supabase_key.startswith("mock"):
            logger.info(f"[MOCK SUPABASE STORAGE] Mock upload successful to path: {destination_path}")
            return destination_path

        upload_url = f"{self.storage_base_url}/object/{self.bucket_name}/{destination_path}"
        headers = {
            **self._headers,
            "Content-Type": content_type,
            "x-upsert": "true",
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(upload_url, content=file_bytes, headers=headers)
            if response.status_code not in (200, 201):
                logger.error(f"Supabase Storage upload failed: {response.status_code} - {response.text}")
                raise RuntimeError(f"Storage upload failed with status {response.status_code}: {response.text}")

        return destination_path

    async def get_download_url(
        self,
        storage_path: str,
        expires_in_seconds: int = 3600
    ) -> str:
        """
        Generates a time-limited signed URL for secure download.
        """
        if self.supabase_url.startswith("https://mock") or not self.supabase_key or self.supabase_key.startswith("mock"):
            return f"{self.supabase_url}/storage/v1/object/sign/{self.bucket_name}/{storage_path}?token=mock-token&expires={expires_in_seconds}"

        sign_url = f"{self.storage_base_url}/object/sign/{self.bucket_name}/{storage_path}"
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                sign_url,
                json={"expiresIn": expires_in_seconds},
                headers=self._headers
            )
            if response.status_code == 200:
                data = response.json()
                signed_path = data.get("signedURL", "")
                if signed_path.startswith("/"):
                    return f"{self.supabase_url}/storage/v1{signed_path}"
                return signed_path
            else:
                logger.error(f"Supabase Storage sign URL failed: {response.status_code} - {response.text}")
                raise RuntimeError(f"Failed to generate signed download URL: {response.text}")

    async def delete_file(self, storage_path: str) -> bool:
        """
        Deletes a file object from Supabase Storage.
        """
        if self.supabase_url.startswith("https://mock") or not self.supabase_key or self.supabase_key.startswith("mock"):
            logger.info(f"[MOCK SUPABASE STORAGE] Mock deleted path: {storage_path}")
            return True

        delete_url = f"{self.storage_base_url}/object/{self.bucket_name}"
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.request(
                "DELETE",
                delete_url,
                json={"prefixes": [storage_path]},
                headers=self._headers
            )
            return response.status_code in (200, 204)
