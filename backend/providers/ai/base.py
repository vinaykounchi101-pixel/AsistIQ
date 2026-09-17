import abc
from typing import Any, Dict


class AIProvider(abc.ABC):
    """
    Abstract contract for Paradox AI providers.
    Supports swappable engines (Gemini, Mock, etc.).
    """

    @abc.abstractmethod
    def generate_triage(self, prompt: str) -> Dict[str, Any]:
        """
        Generates structured case triage metadata (category, priority, confidence, missing info).
        Must return a valid dictionary matching AITriageResult schema.
        """
        raise NotImplementedError

    @abc.abstractmethod
    def generate_summary(self, prompt: str) -> str:
        """
        Synthesizes case history into a concise narrative summary.
        """
        raise NotImplementedError

    @abc.abstractmethod
    def generate_draft(self, prompt: str) -> str:
        """
        Generates a contextual communication draft (info request, update, resolution, escalation).
        """
        raise NotImplementedError
