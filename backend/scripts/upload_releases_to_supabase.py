import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

import httpx
from backend.core.config import settings
RELEASES_DIR = ROOT_DIR / "releases"
WINDOWS_FILE = RELEASES_DIR / "AsistIQ-Setup.exe"
ANDROID_FILE = RELEASES_DIR / "app-release.apk"

def upload_file_to_supabase(file_path: Path, remote_filename: str, content_type: str):
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    supabase_key = settings.SUPABASE_KEY
    bucket = getattr(settings, "SUPABASE_RELEASES_BUCKET", "app-releases")

    if not supabase_url or supabase_url.startswith("https://mock"):
        print(f"[WARN] Supabase URL is mock ({supabase_url}). Skipping remote upload.")
        return

    if not file_path.exists():
        print(f"[ERROR] Local file does not exist: {file_path}")
        return

    print(f"Uploading {file_path.name} ({file_path.stat().st_size / (1024*1024):.2f} MB) to Supabase bucket '{bucket}'...")
    
    upload_url = f"{supabase_url}/storage/v1/object/{bucket}/{remote_filename}"
    headers = {
        "Authorization": f"Bearer {supabase_key}",
        "apiKey": supabase_key,
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    with open(file_path, "rb") as f:
        file_bytes = f.read()

    try:
        with httpx.Client(timeout=120.0) as client:
            # 1. Ensure bucket exists or create public bucket
            bucket_url = f"{supabase_url}/storage/v1/bucket"
            client.post(bucket_url, headers=headers, json={"id": bucket, "name": bucket, "public": True})

            # 2. Upload file with upsert
            response = client.post(upload_url, headers=headers, content=file_bytes)
            if response.status_code in (200, 201):
                public_url = f"{supabase_url}/storage/v1/object/public/{bucket}/{remote_filename}"
                print(f"[SUCCESS] Uploaded {remote_filename} successfully!")
                print(f"Public Download URL: {public_url}")
            else:
                print(f"[ERROR] Failed to upload {remote_filename}: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"[ERROR] Exception during Supabase upload: {e}")


def main():
    print("--- Uploading Release Binaries to Supabase Storage ---")
    if WINDOWS_FILE.exists():
        upload_file_to_supabase(WINDOWS_FILE, "AsistIQ-Setup.exe", "application/octet-stream")
    if ANDROID_FILE.exists():
        upload_file_to_supabase(ANDROID_FILE, "app-release.apk", "application/vnd.android.package-archive")

if __name__ == "__main__":
    main()
