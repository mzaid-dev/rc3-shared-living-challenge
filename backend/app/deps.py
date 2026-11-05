from dataclasses import dataclass
from typing import Callable, Generator, Optional
from fastapi import Depends, Header, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import ForbiddenError, TokenInvalidError
from app.core.idempotency import validate_idempotency_key
from app.core.logging import logger
from app.core.security import decode_access_token
from app.db.models import Household, Member, User
from app.db.session import SessionLocal

security_bearer = HTTPBearer(auto_error=False)

@dataclass
class Context:
    user: Optional[User]
    household_id: Optional[str]
    member_id: Optional[int]
    member_code: Optional[str]
    role: Optional[str]

def get_db() -> Generator[Session, None, None]:
    """Provides a database session to use-cases and repositories."""
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()

def get_request_id(request: Request) -> str:
    """Retrieves current request ID set by middleware."""
    return getattr(request.state, "request_id", "unknown")

def get_idempotency_key(
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key")
) -> Optional[str]:
    """Extracts and validates optional Idempotency-Key HTTP header."""
    return validate_idempotency_key(idempotency_key)

def get_current_user(
    auth: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    session: Session = Depends(get_db),
) -> User:
    """
    Validates Bearer access token and returns authenticated active user.
    Raises 401 TOKEN_EXPIRED or TOKEN_INVALID.
    """
    if not auth or not auth.credentials:
        raise TokenInvalidError("Missing or malformed Authorization header.")

    payload = decode_access_token(auth.credentials)
    user_id = payload.get("sub")
    if not user_id:
        raise TokenInvalidError("Access token payload missing subject claim.")

    user = session.query(User).filter_by(id=user_id).first()
    if not user or not user.is_active:
        raise TokenInvalidError("User account not found or has been deactivated.")

    return user

def get_context(
    request: Request,
    auth: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    session: Session = Depends(get_db),
) -> Context:
    """
    Constructs the operational context (User + Household + Member + Role).
    Loads membership dynamically FROM THE DB on every request to reflect role changes immediately.
    If AUTH_ENABLED is False, yields the seeded demo owner context with no token required.
    """
    if not settings.AUTH_ENABLED:
        logger.warning("AUTH_ENABLED is false! Bypassing authentication with demo owner context.")
        demo_hh = session.query(Household).filter_by(name="Lahore Apartment").first()
        demo_member = (
            session.query(Member)
            .filter_by(household_id=demo_hh.id, code="M01")
            .first() if demo_hh else None
        )
        demo_user = demo_member.user if demo_member else None
        return Context(
            user=demo_user,
            household_id=demo_hh.id if demo_hh else None,
            member_id=demo_member.id if demo_member else None,
            member_code=demo_member.code if demo_member else None,
            role=demo_member.role if demo_member else None,
        )

    # Standard authenticated path
    user = get_current_user(auth, session)
    member = session.query(Member).filter_by(user_id=user.id).first()

    if not member:
        return Context(
            user=user,
            household_id=None,
            member_id=None,
            member_code=None,
            role=None,
        )

    return Context(
        user=user,
        household_id=member.household_id,
        member_id=member.id,
        member_code=member.code,
        role=member.role,
    )

def require_role(*allowed_roles: str) -> Callable[[Context], Context]:
    """Dependency factory ensuring current context possesses one of the allowed roles."""
    def role_checker(ctx: Context = Depends(get_context)) -> Context:
        if not ctx.role or ctx.role not in allowed_roles:
            raise ForbiddenError(f"Insufficient privileges. Required role in: {allowed_roles}")
        return ctx
    return role_checker
