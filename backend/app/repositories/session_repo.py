from datetime import datetime, timezone
from typing import Optional
from sqlalchemy.orm import Session
from app.db.models import RefreshSession

class SessionRepository:
    @staticmethod
    def get_by_token_hash(session: Session, token_hash: str) -> Optional[RefreshSession]:
        return session.query(RefreshSession).filter_by(token_hash=token_hash).first()

    @staticmethod
    def create(
        session: Session,
        user_id: str,
        family_id: str,
        token_hash: str,
        expires_at: datetime,
        user_agent: Optional[str] = None,
    ) -> RefreshSession:
        rec = RefreshSession(
            user_id=user_id,
            family_id=family_id,
            token_hash=token_hash,
            expires_at=expires_at,
            user_agent=user_agent,
        )
        session.add(rec)
        session.flush()
        return rec

    @staticmethod
    def mark_used(
        session: Session,
        record: RefreshSession,
        replaced_by_id: str,
    ) -> None:
        record.used_at = datetime.now(timezone.utc)
        record.replaced_by_id = replaced_by_id
        session.flush()

    @staticmethod
    def revoke_family(session: Session, family_id: str) -> None:
        now = datetime.now(timezone.utc)
        (
            session.query(RefreshSession)
            .filter_by(family_id=family_id)
            .filter(RefreshSession.revoked_at.is_(None))
            .update({"revoked_at": now})
        )
        session.flush()

    @staticmethod
    def revoke_all_for_user(session: Session, user_id: str) -> None:
        now = datetime.now(timezone.utc)
        (
            session.query(RefreshSession)
            .filter_by(user_id=user_id)
            .filter(RefreshSession.revoked_at.is_(None))
            .update({"revoked_at": now})
        )
        session.flush()

