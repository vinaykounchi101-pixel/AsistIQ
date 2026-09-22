from pathlib import Path
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse, RedirectResponse
from backend.core.config import settings

router = APIRouter(prefix="/releases", tags=["App Releases"])

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
WINDOWS_LOCAL = ROOT_DIR / "dist" / "AsistIQ-Setup.exe"
ANDROID_LOCAL = ROOT_DIR / "client" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"


@router.get("/android")
def get_android_release():
    """
    Serves the local Android APK if present; otherwise redirects to Supabase storage.
    """
    if ANDROID_LOCAL.exists():
        return FileResponse(
            path=str(ANDROID_LOCAL),
            filename="app-release.apk",
            media_type="application/vnd.android.package-archive"
        )
    
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    if supabase_url and not supabase_url.startswith("https://mock"):
        return RedirectResponse(
            url=f"{supabase_url}/storage/v1/object/public/app-releases/app-release.apk",
            status_code=status.HTTP_307_TEMPORARY_REDIRECT
        )
    
    raise HTTPException(status_code=404, detail="Android APK release binary not found")


@router.get("/windows")
def get_windows_release():
    """
    Serves the local Windows Installer if present; otherwise redirects to Supabase storage.
    """
    if WINDOWS_LOCAL.exists():
        return FileResponse(
            path=str(WINDOWS_LOCAL),
            filename="AsistIQ-Setup.exe",
            media_type="application/octet-stream"
        )
    
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    if supabase_url and not supabase_url.startswith("https://mock"):
        return RedirectResponse(
            url=f"{supabase_url}/storage/v1/object/public/app-releases/AsistIQ-Setup.exe",
            status_code=status.HTTP_307_TEMPORARY_REDIRECT
        )
    
    raise HTTPException(status_code=404, detail="Windows installer release binary not found")
