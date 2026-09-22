import os
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse, RedirectResponse
from backend.core.config import settings

router = APIRouter(prefix="/releases", tags=["App Releases"])

ROOT_DIR = Path(__file__).resolve().parent.parent.parent


def _find_binary(filename: str) -> Optional[Path]:
    candidates = [
        ROOT_DIR / "releases" / filename,
        ROOT_DIR / "dist" / filename,
        Path.cwd() / "releases" / filename,
        Path.cwd() / "dist" / filename,
        Path("/app/releases") / filename,
        Path("releases") / filename,
        Path(filename),
    ]
    for p in candidates:
        try:
            if p.exists() and p.is_file():
                return p.resolve()
        except Exception:
            continue
    return None


@router.get("/status")
def get_releases_status():
    """
    Diagnostic endpoint showing availability of release binaries and Supabase storage configuration.
    """
    win_bin = _find_binary("AsistIQ-Setup.exe")
    apk_bin = _find_binary("app-release.apk")
    supabase_configured = bool(settings.SUPABASE_URL and not settings.SUPABASE_URL.startswith("https://mock"))

    releases_dir = ROOT_DIR / "releases"
    releases_contents = []
    if releases_dir.exists():
        try:
            releases_contents = [f.name for f in releases_dir.iterdir()]
        except Exception as e:
            releases_contents = [f"error: {e}"]

    root_contents = []
    try:
        root_contents = [f.name for f in ROOT_DIR.iterdir()]
    except Exception as e:
        root_contents = [f"error: {e}"]

    return {
        "windows_installer_present": win_bin is not None,
        "windows_installer_path": str(win_bin) if win_bin else None,
        "android_apk_present": apk_bin is not None,
        "android_apk_path": str(apk_bin) if apk_bin else None,
        "supabase_url_configured": supabase_configured,
        "supabase_bucket": getattr(settings, "SUPABASE_RELEASES_BUCKET", "app-releases"),
        "cwd": str(Path.cwd()),
        "root_dir": str(ROOT_DIR),
        "root_contents": root_contents,
        "releases_contents": releases_contents,
    }


@router.get("/android")
def get_android_release():
    """
    Redirects to Supabase Storage public URL for the Android APK, or serves local file as fallback.
    """
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    bucket = getattr(settings, "SUPABASE_RELEASES_BUCKET", "app-releases")
    if supabase_url and not supabase_url.startswith("https://mock"):
        return RedirectResponse(
            url=f"{supabase_url}/storage/v1/object/public/{bucket}/app-release.apk",
            status_code=status.HTTP_307_TEMPORARY_REDIRECT
        )
    
    apk_path = _find_binary("app-release.apk")
    if apk_path:
        return FileResponse(
            path=str(apk_path),
            filename="AsistIQ-app-release.apk",
            media_type="application/vnd.android.package-archive"
        )
    
    raise HTTPException(status_code=404, detail="Android APK release binary not found")


@router.get("/windows")
def get_windows_release():
    """
    Redirects to Supabase Storage public URL for the Windows Installer, or serves local file as fallback.
    """
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    bucket = getattr(settings, "SUPABASE_RELEASES_BUCKET", "app-releases")
    if supabase_url and not supabase_url.startswith("https://mock"):
        return RedirectResponse(
            url=f"{supabase_url}/storage/v1/object/public/{bucket}/AsistIQ-Setup.exe",
            status_code=status.HTTP_307_TEMPORARY_REDIRECT
        )
    
    win_path = _find_binary("AsistIQ-Setup.exe")
    if win_path:
        return FileResponse(
            path=str(win_path),
            filename="AsistIQ-Setup.exe",
            media_type="application/octet-stream"
        )
    
    raise HTTPException(status_code=404, detail="Windows installer release binary not found")
