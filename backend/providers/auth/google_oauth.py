from typing import Optional, Dict, Any
from pydantic import BaseModel
import httpx
from backend.core.config import settings


class GoogleUserProfile(BaseModel):
    subject_id: str
    email: str
    email_verified: bool
    name: str
    picture: Optional[str] = None


class GoogleOAuthProvider:
    GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
    GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo"

    @classmethod
    async def exchange_code_for_profile(cls, code: str, redirect_uri: Optional[str] = None) -> GoogleUserProfile:
        """
        Exchange authorization code for tokens and fetch user profile (SRS v3.3 §3.1, §7.4).
        """
        target_redirect_uri = redirect_uri or settings.GOOGLE_OAUTH_REDIRECT_URI

        async with httpx.AsyncClient(timeout=10.0) as client:
            # 1. Exchange code for access token
            token_response = await client.post(
                cls.GOOGLE_TOKEN_URL,
                data={
                    "code": code,
                    "client_id": settings.GOOGLE_OAUTH_CLIENT_ID,
                    "client_secret": settings.GOOGLE_OAUTH_CLIENT_SECRET,
                    "redirect_uri": target_redirect_uri,
                    "grant_type": "authorization_code",
                },
            )

            if token_response.status_code != 200:
                error_data = token_response.json() if token_response.content else {}
                raise ValueError(
                    f"Google OAuth token exchange failed: {error_data.get('error_description', 'Invalid code or redirect URI')}"
                )

            tokens = token_response.json()
            access_token = tokens.get("access_token")
            if not access_token:
                raise ValueError("Google OAuth response did not return an access_token.")

            # 2. Fetch user profile from Google UserInfo endpoint
            userinfo_response = await client.get(
                cls.GOOGLE_USERINFO_URL,
                headers={"Authorization": f"Bearer {access_token}"},
            )

            if userinfo_response.status_code != 200:
                raise ValueError("Failed to fetch user profile from Google.")

            data = userinfo_response.json()
            return GoogleUserProfile(
                subject_id=data["sub"],
                email=data["email"],
                email_verified=data.get("email_verified", True),
                name=data.get("name", data["email"].split("@")[0]),
                picture=data.get("picture"),
            )

    @classmethod
    async def verify_id_token(cls, id_token: str) -> GoogleUserProfile:
        """
        Verify Google ID token directly (for mobile client PKCE / direct ID token flows).
        """
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
            )
            if response.status_code != 200:
                raise ValueError("Invalid Google ID token.")

            data = response.json()
            return GoogleUserProfile(
                subject_id=data["sub"],
                email=data["email"],
                email_verified=data.get("email_verified", True) in [True, "true"],
                name=data.get("name", data["email"].split("@")[0]),
                picture=data.get("picture"),
            )
