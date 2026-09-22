from fastapi import APIRouter, status
from fastapi.responses import RedirectResponse
from backend.core.config import settings

router = APIRouter(prefix="/releases", tags=["App Releases"])


@router.get("/android", status_code=status.HTTP_307_TEMPORARY_REDIRECT)
def get_android_release():
    """
    Redirects to the latest Android APK in the Supabase public app-releases bucket.
    """
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    target_url = f"{supabase_url}/storage/v1/object/public/app-releases/app-release.apk"
    return RedirectResponse(url=target_url)


@router.get("/windows", status_code=status.HTTP_307_TEMPORARY_REDIRECT)
def get_windows_release():
    """
    Redirects to the latest Windows Installer in the Supabase public app-releases bucket.
    """
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    target_url = f"{supabase_url}/storage/v1/object/public/app-releases/AsistIQ-Setup.exe"
    return RedirectResponse(url=target_url)
