from datetime import datetime
from typing import Any, Dict, List, Optional
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import (
    ForbiddenError,
    NotFoundError,
    ValidationAppError,
)
from app.db.models import MonthlyBudget, User
from app.db.session import unit_of_work
from app.deps import Context
from app.repositories.audit_repo import AuditRepository
from app.repositories.household_repo import HouseholdRepository, generate_invite_code
from app.repositories.member_repo import MemberRepository
from app.schemas.household import HouseholdCurrentResponse
from app.schemas.member import MemberDetailOut, MemberOfficialOut

class HouseholdService:
    @staticmethod
    def create_household(
        session: Session,
        user: User,
        name: str,
    ) -> HouseholdCurrentResponse:
        # Enforce 1 household per user rule
        existing_membership = MemberRepository.get_by_user_id(session, user.id)
        if existing_membership:
            raise ValidationAppError("User already belongs to a household.")

        clean_name = name.strip()
        if not clean_name:
            raise ValidationAppError("Household name cannot be blank.")

        invite_code = generate_invite_code()

        with unit_of_work(session, write=True):
            # 1. Create household
            hh = HouseholdRepository.create(
                session=session,
                name=clean_name,
                invite_code=invite_code,
                currency="PKR",
                timezone=settings.TIMEZONE,
            )

            # 2. Create initial owner member M01
            member = MemberRepository.create_member(
                session=session,
                household_id=hh.id,
                name=user.display_name,
                code="M01",
                sort_order=1,
                role="owner",
                user_id=user.id,
            )

            # 3. Initialize default monthly budget
            try:
                tz = ZoneInfo(settings.TIMEZONE)
                active_month = datetime.now(tz).strftime("%Y-%m")
            except Exception:
                active_month = datetime.utcnow().strftime("%Y-%m")

            budget = MonthlyBudget(
                household_id=hh.id,
                month=active_month,
                limit_paisa=settings.DEFAULT_MONTHLY_BUDGET_PAISA,
            )
            session.add(budget)

            # 4. Audit Log
            AuditRepository.record_audit(
                session=session,
                household_id=hh.id,
                user_id=user.id,
                action="household_created",
                entity_type="household",
                entity_id=hh.id,
                payload={"name": hh.name, "owner_member_id": member.id},
            )

        return HouseholdCurrentResponse(
            id=hh.id,
            name=hh.name,
            currency=hh.currency,
            timezone=hh.timezone,
            invite_code=hh.invite_code,  # Owner sees the invite code
        )

    @staticmethod
    def join_household(
        session: Session,
        user: User,
        invite_code: str,
    ) -> HouseholdCurrentResponse:
        existing_membership = MemberRepository.get_by_user_id(session, user.id)
        if existing_membership:
            raise ValidationAppError("User already belongs to a household.")

        hh = HouseholdRepository.get_by_invite_code(session, invite_code)
        if not hh:
            raise NotFoundError("Invalid or non-existent household invite code.")

        with unit_of_work(session, write=True):
            next_code, sort_order = MemberRepository.get_next_member_code(session, hh.id)
            member = MemberRepository.create_member(
                session=session,
                household_id=hh.id,
                name=user.display_name,
                code=next_code,
                sort_order=sort_order,
                role="member",
                user_id=user.id,
            )

            AuditRepository.record_audit(
                session=session,
                household_id=hh.id,
                user_id=user.id,
                action="member_joined",
                entity_type="member",
                entity_id=member.id,
                payload={"member_code": member.code, "name": member.name},
            )

        # Non-owners do not see the invite code in the response
        return HouseholdCurrentResponse(
            id=hh.id,
            name=hh.name,
            currency=hh.currency,
            timezone=hh.timezone,
            invite_code=None,
        )

    @staticmethod
    def get_current_household(
        session: Session,
        ctx: Context,
    ) -> HouseholdCurrentResponse:
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        hh = HouseholdRepository.get_by_id(session, ctx.household_id)
        if not hh:
            raise NotFoundError("Household not found.")

        # Invite code is ONLY exposed to owner or admin
        can_view_code = ctx.role in ("owner", "admin")
        return HouseholdCurrentResponse(
            id=hh.id,
            name=hh.name,
            currency=hh.currency,
            timezone=hh.timezone,
            invite_code=hh.invite_code if can_view_code else None,
        )

    @staticmethod
    def rotate_invite_code(
        session: Session,
        ctx: Context,
    ) -> HouseholdCurrentResponse:
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        hh = HouseholdRepository.get_by_id(session, ctx.household_id)
        if not hh:
            raise NotFoundError("Household not found.")

        new_code = generate_invite_code()
        with unit_of_work(session, write=True):
            HouseholdRepository.update_invite_code(session, hh, new_code)
            AuditRepository.record_audit(
                session=session,
                household_id=hh.id,
                user_id=ctx.user.id if ctx.user else None,
                action="invite_code_rotated",
                entity_type="household",
                entity_id=hh.id,
            )

        return HouseholdCurrentResponse(
            id=hh.id,
            name=hh.name,
            currency=hh.currency,
            timezone=hh.timezone,
            invite_code=new_code,
        )

    @staticmethod
    def list_members(
        session: Session,
        household_id: str,
        detail: bool = False,
    ) -> List[Any]:
        members = MemberRepository.list_by_household(session, household_id)
        if not detail:
            # OFFICIAL PDF format: raw array of [{"id": "M01", "name": "Ali"}, ...]
            return [
                {"id": m.code, "name": m.name}
                for m in members
            ]
        else:
            return [
                {
                    "id": m.code,
                    "name": m.name,
                    "role": m.role,
                    "linked": m.user_id is not None,
                }
                for m in members
            ]

    @staticmethod
    def create_unlinked_member(
        session: Session,
        ctx: Context,
        name: str,
    ) -> MemberOfficialOut:
        clean_name = name.strip()
        if not clean_name:
            raise ValidationAppError("Member name cannot be blank.")

        # Check for duplicate member name in household
        existing_members = MemberRepository.list_by_household(session, ctx.household_id)
        if any(m.name.lower() == clean_name.lower() for m in existing_members):
            raise ValidationAppError(f"Member with name '{clean_name}' already exists in household.")

        with unit_of_work(session, write=True):
            next_code, sort_order = MemberRepository.get_next_member_code(session, ctx.household_id)
            member = MemberRepository.create_member(
                session=session,
                household_id=ctx.household_id,
                name=clean_name,
                code=next_code,
                sort_order=sort_order,
                role="member",
                user_id=None,  # Unlinked roommate without an app account
            )

            AuditRepository.record_audit(
                session=session,
                household_id=ctx.household_id,
                user_id=ctx.user.id if ctx.user else None,
                action="unlinked_member_created",
                entity_type="member",
                entity_id=member.id,
                payload={"member_code": member.code, "name": member.name},
            )

        return MemberOfficialOut(id=member.code, name=member.name)

