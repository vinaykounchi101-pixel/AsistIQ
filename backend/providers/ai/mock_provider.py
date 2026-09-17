from typing import Any, Dict
from backend.providers.ai.base import AIProvider


class MockAIProvider(AIProvider):
    """
    Deterministic AI provider for unit testing and offline development.
    """

    def generate_triage(self, prompt: str) -> Dict[str, Any]:
        return {
            "suggested_category": "Software",
            "suggested_severity": "High",
            "suggested_priority": "P2 — High",
            "confidence_level": "High",
            "confidence_score": 0.88,
            "supporting_factors": [
                "User reported database connection timeout across multiple instances.",
                "Impacting multiple business units simultaneously."
            ],
            "missing_info": [
                "Database error logs and timestamp of first failure.",
                "Server hostnames and environment (production/staging)."
            ],
            "suggested_team": "DevOps",
            "recommended_next_action": "Check connection pool saturation and database health metrics.",
            "related_case_ids": []
        }

    def generate_summary(self, prompt: str) -> str:
        return (
            "### Continuous Case Summary\n"
            "- **Reported Issue:** User encountered connection timeouts accessing database services.\n"
            "- **Actions Taken:** Diagnostic checks initiated; connection pool inspect scheduled.\n"
            "- **Confirmed Facts:** Database service port 5432 responding intermittently.\n"
            "- **Current Status & Blocker:** Awaiting server telemetry and error logs."
        )

    def generate_draft(self, prompt: str) -> str:
        return (
            "Hello John,\n\n"
            "Thank you for contacting IT Support regarding the database connection timeouts. "
            "Our DevOps engineering team is currently investigating connection pool limits and server telemetry.\n\n"
            "Could you please confirm if this issue is also impacting read replicas?\n\n"
            "Best regards,\nIT Service Desk"
        )
