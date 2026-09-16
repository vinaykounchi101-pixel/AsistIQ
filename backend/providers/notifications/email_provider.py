import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from abc import ABC, abstractmethod
from typing import Optional
import httpx
from backend.core.config import settings


class NotificationProvider(ABC):
    @abstractmethod
    async def send_email(self, to_email: str, subject: str, body_text: str, body_html: Optional[str] = None) -> bool:
        """Send an email notification (verification link, alert, etc.)."""
        pass


class GmailSmtpNotificationProvider(NotificationProvider):
    """
    Local Development Email Provider via Gmail SMTP (SRS v3.3 §3.9).
    """
    def __init__(self, smtp_address: Optional[str], smtp_password: Optional[str]):
        self.smtp_address = smtp_address
        self.smtp_password = smtp_password

    async def send_email(self, to_email: str, subject: str, body_text: str, body_html: Optional[str] = None) -> bool:
        if not self.smtp_address or not self.smtp_password:
            # In local dev without credentials, log and succeed safely
            print(f"[LOCAL EMAIL MOCK] To: {to_email} | Subject: {subject}\nBody: {body_text}")
            return True

        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = self.smtp_address
            msg["To"] = to_email

            msg.attach(MIMEText(body_text, "plain"))
            if body_html:
                msg.attach(MIMEText(body_html, "html"))

            with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
                server.login(self.smtp_address, self.smtp_password)
                server.sendmail(self.smtp_address, [to_email], msg.as_string())
            return True
        except Exception as e:
            print(f"[EMAIL ERROR] Gmail SMTP send failed: {str(e)}")
            return False


class BrevoNotificationProvider(NotificationProvider):
    """
    Staging & Production Email Provider via Brevo HTTP API (SRS v3.3 §3.9).
    Bypasses Render's outbound SMTP port blocking.
    """
    BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"

    def __init__(self, api_key: Optional[str], from_address: str, from_name: str):
        self.api_key = api_key
        self.from_address = from_address
        self.from_name = from_name

    async def send_email(self, to_email: str, subject: str, body_text: str, body_html: Optional[str] = None) -> bool:
        if not self.api_key:
            print(f"[BREVO EMAIL WARNING] Missing BREVO_API_KEY. To: {to_email} | Subject: {subject}")
            return False

        headers = {
            "api-key": self.api_key,
            "Content-Type": "application/json",
            "Accept": "application/json"
        }

        payload = {
            "sender": {"name": self.from_name, "email": self.from_address},
            "to": [{"email": to_email}],
            "subject": subject,
            "textContent": body_text,
        }
        if body_html:
            payload["htmlContent"] = body_html

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(self.BREVO_API_URL, json=payload, headers=headers)
                return response.status_code in [200, 201, 202]
        except Exception as e:
            print(f"[EMAIL ERROR] Brevo API send failed: {str(e)}")
            return False


def get_notification_provider() -> NotificationProvider:
    """Factory selecting provider based on ENVIRONMENT (SRS v3.3 §3.9)."""
    if settings.ENVIRONMENT == "local":
        return GmailSmtpNotificationProvider(
            smtp_address=settings.GMAIL_SMTP_ADDRESS,
            smtp_password=settings.GMAIL_SMTP_APP_PASSWORD,
        )
    return BrevoNotificationProvider(
        api_key=settings.BREVO_API_KEY,
        from_address=settings.EMAIL_FROM_ADDRESS,
        from_name=settings.EMAIL_FROM_NAME,
    )
