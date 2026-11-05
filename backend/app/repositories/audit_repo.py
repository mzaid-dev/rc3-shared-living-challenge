from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session
from app.db.models import AuditLog

class AuditRepository:
    @staticmethod
    def list_audit_logs(
        session: Session,
        household_id: str,
        limit: int = 50,
        offset: int = 0,
    ) -> List[AuditLog]:
        """Lists audit logs for a household, ordered newest first."""
        return (
            session.query(AuditLog)
            .filter_by(household_id=household_id)
            .order_by(AuditLog.created_at.desc(), AuditLog.id.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )

    @staticmethod
    def record_audit(
        session: Session,
        household_id: str,
        user_id: Optional[str],
        action: str,
        entity_type: str,
        entity_id: str,
        payload: Optional[Dict[str, Any]] = None,
    ) -> AuditLog:
        """
        Records an audit log entry in the same transaction as the business write.
        Never logs passwords, tokens, or hashes.
        """
        # Redact any accidental sensitive keys in payload
        clean_payload = None
        if payload:
            clean_payload = {
                k: ("***REDACTED***" if any(s in k.lower() for s in ["password", "token", "secret", "hash"]) else v)
                for k, v in payload.items()
            }

        log = AuditLog(
            household_id=household_id,
            user_id=user_id,
            action=action,
            entity_type=entity_type,
            entity_id=str(entity_id),
            payload=clean_payload,
        )
        session.add(log)
        session.flush()
        return log

