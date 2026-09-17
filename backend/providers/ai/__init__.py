from backend.core.config import settings
from backend.providers.ai.base import AIProvider
from backend.providers.ai.gemini_provider import GeminiAIProvider
from backend.providers.ai.mock_provider import MockAIProvider


def get_ai_provider() -> AIProvider:
    """
    Factory returning the appropriate AI provider based on environment and configuration.
    """
    if settings.ENVIRONMENT == "local" and (
        not settings.GEMINI_API_KEY or settings.GEMINI_API_KEY.startswith("mock-")
    ):
        return MockAIProvider()
    return GeminiAIProvider()


__all__ = ["AIProvider", "GeminiAIProvider", "MockAIProvider", "get_ai_provider"]
