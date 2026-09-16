import enum


class UserRole(str, enum.Enum):
    REQUESTER = "Requester"
    OPERATOR = "Operator"
    TEAM_LEAD = "TeamLead"
    MANAGER = "Manager"
    ADMINISTRATOR = "Administrator"


class AuthProvider(str, enum.Enum):
    PASSWORD = "password"
    GOOGLE = "google"


class AvailabilityStatus(str, enum.Enum):
    AVAILABLE = "available"
    AWAY = "away"
    OFFLINE = "offline"


class CaseType(str, enum.Enum):
    INCIDENT = "Incident"
    SERVICE_REQUEST = "Service Request"
    PROBLEM = "Problem"  # Phase 2
    CHANGE = "Change"    # Phase 2


class CaseStatus(str, enum.Enum):
    DRAFT = "Draft"
    NEW = "New"
    IN_ASSESSMENT = "In Assessment"
    ASSIGNED = "Assigned"
    AWAITING_REQUESTER = "Awaiting Requester"
    AWAITING_APPROVAL = "Awaiting Approval"
    PENDING = "Pending / External Dependency"
    RESOLVED = "Resolved"
    CLOSED = "Closed"
    CANCELLED = "Cancelled"


class CasePriority(str, enum.Enum):
    P1 = "P1 — Critical"
    P2 = "P2 — High"
    P3 = "P3 — Medium"
    P4 = "P4 — Low"


class CaseRelationshipType(str, enum.Enum):
    RELATED_TO = "related_to"
    DUPLICATE_OF = "duplicate_of"
    PART_OF_MAJOR_INCIDENT = "part_of_major_incident"


class MessageVisibility(str, enum.Enum):
    REQUESTER_VISIBLE = "requester_visible"
    INTERNAL_ONLY = "internal_only"


class ConfidenceLevel(str, enum.Enum):
    LOW = "Low"
    MODERATE = "Moderate"
    HIGH = "High"


class RiskLevel(str, enum.Enum):
    LOW = "Low"
    MODERATE = "Moderate"
    HIGH = "High"
    CRITICAL = "Critical"


class EscalationTriggerReason(str, enum.Enum):
    APPROACHING_DEADLINE = "approaching_deadline"
    MISSED_DEADLINE = "missed_deadline"
    HIGH_RISK = "high_risk"
    REPEATED_REOPEN = "repeated_reopen"
    OPERATOR_REQUESTED = "operator_requested"


class EscalationStatus(str, enum.Enum):
    OPEN = "open"
    ACKNOWLEDGED = "acknowledged"
    RESOLVED = "resolved"


class DraftType(str, enum.Enum):
    INFO_REQUEST = "info_request"
    PROGRESS_UPDATE = "progress_update"
    RESOLUTION = "resolution"
    ESCALATION_SUMMARY = "escalation_summary"


class DraftStatus(str, enum.Enum):
    DRAFT = "draft"
    SENT = "sent"
    DISCARDED = "discarded"


class ApprovalDecision(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class KnowledgeState(str, enum.Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"
