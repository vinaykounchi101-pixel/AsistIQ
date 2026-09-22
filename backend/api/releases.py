from pathlib import Path
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse, RedirectResponse
from backend.core.config import settings

router = APIRouter(prefix="/releases", tags=["App Releases"])

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
RELEASES_DIR = ROOT_DIR / "releases"
WINDOWS_PATHS = [
    RELEASES_DIR / "AsistIQ-Setup.exe",
    ROOT_DIR / "dist" / "AsistIQ-Setup.exe",
]
ANDROID_PATHS = [
    RELEASES_DIR / "app-release.apk",
    ROOT_DIR / "client" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk",
]


@router.get("/android")
def get_android_release():
    """
    Serves the Android APK release binary directly from the server repository or Supabase storage.
    """
    for apk_path in ANDROID_PATHS:
        if apk_path.exists():
            return FileResponse(
                path=str(apk_path),
                filename="AsistIQ-app-release.apk",
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
    Serves the Windows installer release binary directly from the server repository or Supabase storage.
    """
    for win_path in WINDOWS_PATHS:
        if win_path.exists():
            return FileResponse(
                path=str(win_path),
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
