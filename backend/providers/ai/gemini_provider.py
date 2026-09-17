import json
import logging
import time
from typing import Any, Dict, Optional
from google import genai
from google.genai import types
from google.genai.errors import APIError

from backend.core.config import settings
from backend.providers.ai.base import AIProvider

logger = logging.getLogger(__name__)


class GeminiAIProvider(AIProvider):
    """
    Production AI provider leveraging Google Gemini via the official google-genai SDK.
    Implements 1 retry with exponential backoff and graceful degradation.
    """

    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None):
        self.api_key = api_key or settings.GEMINI_API_KEY
        self.model = model or settings.GEMINI_MODEL or "gemini-2.5-flash"
        self._client: Optional[genai.Client] = None

    @property
    def client(self) -> genai.Client:
        if self._client is None:
            self._client = genai.Client(api_key=self.api_key)
        return self._client

    def _execute_with_retry(self, prompt: str, is_json: bool = False) -> str:
        """
        Executes Gemini call with 1 retry on failure.
        """
        config = types.GenerateContentConfig(
            response_mime_type="application/json" if is_json else "text/plain",
            temperature=0.2 if is_json else 0.4
        )

        attempts = 2
        for attempt in range(1, attempts + 1):
            try:
                response = self.client.models.generate_content(
                    model=self.model,
                    contents=prompt,
                    config=config
                )
                if response and response.text:
                    return response.text.strip()
                raise ValueError("Empty response text received from Gemini API.")
            except Exception as e:
                logger.warning(
                    f"Gemini API attempt {attempt}/{attempts} failed: {type(e).__name__} - {str(e)}"
                )
                if attempt < attempts:
                    time.sleep(1.0)  # Short backoff before single retry
                else:
                    raise e

    def generate_triage(self, prompt: str) -> Dict[str, Any]:
        """
        Calls Gemini to generate structured case triage.
        Falls back to a safe degradation object if unavailable.
        """
        try:
            raw_text = self._execute_with_retry(prompt, is_json=True)
            # Remove any possible markdown wrapping if returned
            clean_text = raw_text.strip()
            if clean_text.startswith("```json"):
                clean_text = clean_text[7:]
            if clean_text.startswith("```"):
                clean_text = clean_text[3:]
            if clean_text.endswith("```"):
                clean_text = clean_text[:-3]

            parsed = json.loads(clean_text.strip())
            return parsed
        except Exception as e:
            logger.error(f"Gemini triage generation failed, activating fallback: {str(e)}")
            return {
                "suggested_category": "Other",
                "suggested_severity": "Medium",
                "suggested_priority": "P3 — Medium",
                "confidence_level": "Low",
                "confidence_score": 0.50,
                "supporting_factors": ["Automated AI triage fallback due to upstream provider unavailability."],
                "missing_info": ["Detailed diagnostic logs and verification steps."],
                "suggested_team": "IT Helpdesk",
                "recommended_next_action": "Conduct initial manual assessment and review case description.",
                "related_case_ids": []
            }

    def generate_summary(self, prompt: str) -> str:
        """
        Generates continuous case summary via Gemini with fallback.
        """
        try:
            return self._execute_with_retry(prompt, is_json=False)
        except Exception as e:
            logger.error(f"Gemini summary generation failed, activating fallback: {str(e)}")
            return (
                "**Summary (Degraded Mode):**\n"
                "- Case requires engineer review.\n"
                "- Live AI summary generation temporarily unavailable."
            )

    def generate_draft(self, prompt: str) -> str:
        """
        Generates communication draft via Gemini with fallback.
        """
        try:
            return self._execute_with_retry(prompt, is_json=False)
        except Exception as e:
            logger.error(f"Gemini draft generation failed, activating fallback: {str(e)}")
            return (
                "Hello,\n\n"
                "Thank you for contacting IT Support. We have received your case and our team is currently investigating. "
                "We will update you as soon as we make progress.\n\n"
                "Best regards,\nIT Service Desk"
            )
