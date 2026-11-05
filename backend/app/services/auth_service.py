from datetime import datetime, timedelta, timezone
from typing import Optional
import uuid

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import (
    EmailTakenError,
    InvalidCredentialsError,
    RefreshReusedError,
    TokenExpiredError,
    TokenInvalidError,
)
from app.core.security import (
    create_access_token,
    dummy_verify,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    validate_password_policy,
    verify_password,
)
from app.db.models import Household, Member, User
from app.db.session import unit_of_work
from app.repositories.session_repo import SessionRepository
from app.repositories.user_repo import UserRepository
from app.schemas.auth import (
    AuthMeResponse,
    HouseholdSummary,
    MemberSummary,
    TokenResponse,
    UserOut,
)

class AuthService:
    @staticmethod
    def register(
        session: Session,
        email: str,
        password: str,
        display_name: str,
    ) -> UserOut:
        clean_email = email.strip().lower()
        validate_password_policy(password, clean_email)

        # Check existing user
        existing = UserRepository.get_by_email(session, clean_email)
        if existing:
            raise EmailTakenError("Email address is already registered.")

        pw_hash = hash_password(password)

        with unit_of_work(session, write=True):
            user = UserRepository.create(
                session=session,
                email=clean_email,
                password_hash=pw_hash,
                display_name=display_name,
            )

        return UserOut.model_validate(user)

    @staticmethod
    def login(
        session: Session,
        email: str,
        password: str,
        user_agent: Optional[str] = None,
    ) -> TokenResponse:
        clean_email = email.strip().lower()
        user = UserRepository.get_by_email(session, clean_email)

        if not user or not user.is_active:
            # Timing mitigation
            dummy_verify(password)
            raise InvalidCredentialsError("Invalid email or password.")

        if not verify_password(user.password_hash, password):
            raise InvalidCredentialsError("Invalid email or password.")

        now = datetime.now(timezone.utc)
        refresh_raw = generate_refresh_token()
        refresh_hash = hash_refresh_token(refresh_raw)
        family_id = str(uuid.uuid4())
        expires_at = now + timedelta(days=settings.REFRESH_TOKEN_DAYS)
        access_tok = create_access_token(user.id)

        with unit_of_work(session, write=True):
            SessionRepository.create(
                session=session,
                user_id=user.id,
                family_id=family_id,
                token_hash=refresh_hash,
                expires_at=expires_at,
                user_agent=user_agent,
            )

        return TokenResponse(
            access_token=access_tok,
            refresh_token=refresh_raw,
            expires_in=settings.ACCESS_TOKEN_MINUTES * 60,
            user=UserOut.model_validate(user),
        )

    @staticmethod
    def refresh(
        session: Session,
        refresh_token_raw: str,
        user_agent: Optional[str] = None,
    ) -> TokenResponse:
        token_hash = hash_refresh_token(refresh_token_raw)
        session_rec = SessionRepository.get_by_token_hash(session, token_hash)

        if not session_rec:
            raise TokenInvalidError("Invalid refresh token.")

        # REUSE DETECTION: if token was already used or revoked, revoke entire family!
        if session_rec.used_at is not None or session_rec.revoked_at is not None:
            with unit_of_work(session, write=True):
                SessionRepository.revoke_family(session, session_rec.family_id)
            raise RefreshReusedError(
                "Refresh token reuse detected. All sessions in this family have been revoked."
            )

        now = datetime.now(timezone.utc)
        expires_at_rec = session_rec.expires_at
        if expires_at_rec.tzinfo is None:
            expires_at_rec = expires_at_rec.replace(tzinfo=timezone.utc)

        if expires_at_rec < now:
            raise TokenExpiredError("Refresh token has expired.")

        user = UserRepository.get_by_id(session, session_rec.user_id)
        if not user or not user.is_active:
            raise TokenInvalidError("User associated with refresh token is invalid or inactive.")

        # Rotate token
        new_refresh_raw = generate_refresh_token()
        new_refresh_hash = hash_refresh_token(new_refresh_raw)
        new_expires = now + timedelta(days=settings.REFRESH_TOKEN_DAYS)
        access_tok = create_access_token(user.id)

        with unit_of_work(session, write=True):
            new_session = SessionRepository.create(
                session=session,
                user_id=user.id,
                family_id=session_rec.family_id,  # Preserve family
                token_hash=new_refresh_hash,
                expires_at=new_expires,
                user_agent=user_agent,
            )
            SessionRepository.mark_used(session, session_rec, replaced_by_id=new_session.id)

        return TokenResponse(
            access_token=access_tok,
            refresh_token=new_refresh_raw,
            expires_in=settings.ACCESS_TOKEN_MINUTES * 60,
            user=UserOut.model_validate(user),
        )

    @staticmethod
    def logout(session: Session, refresh_token_raw: str) -> None:
        token_hash = hash_refresh_token(refresh_token_raw)
        session_rec = SessionRepository.get_by_token_hash(session, token_hash)
        if session_rec:
            with unit_of_work(session, write=True):
                SessionRepository.revoke_family(session, session_rec.family_id)

    @staticmethod
    def logout_all(session: Session, user_id: str) -> None:
        with unit_of_work(session, write=True):
            SessionRepository.revoke_all_for_user(session, user_id)

    @staticmethod
    def get_me(session: Session, user: User) -> AuthMeResponse:
        member = session.query(Member).filter_by(user_id=user.id).first()
        household_summary = None
        member_summary = None

        if member:
            member_summary = MemberSummary(
                id=member.code,
                name=member.name,
                role=member.role,
            )
            hh = session.query(Household).filter_by(id=member.household_id).first()
            if hh:
                household_summary = HouseholdSummary(
                    id=hh.id,
                    name=hh.name,
                )

        return AuthMeResponse(
            user=UserOut.model_validate(user),
            household=household_summary,
            member=member_summary,
        )

