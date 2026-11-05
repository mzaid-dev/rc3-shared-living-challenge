from datetime import date, datetime
from typing import Any, Dict, List, Optional, Union
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import (
    NotFoundError,
    ValidationAppError,
)
from app.core.idempotency import (
    check_idempotency,
    compute_request_hash,
    record_idempotency,
)
from app.db.session import unit_of_work
from app.deps import Context
from app.domain.exceptions import DuplicateSplitMember
from app.domain.money import format_pkr, parse_pkr
from app.domain.split import equal_split, custom_split_validate
from app.repositories.audit_repo import AuditRepository
from app.repositories.expense_repo import ExpenseRepository
from app.repositories.member_repo import MemberRepository
from app.schemas.expense import ExpenseCreate

class ExpenseService:
    @staticmethod
    def create_expense(
        session: Session,
        ctx: Context,
        payload: ExpenseCreate,
        idempotency_key: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Creates a shared expense with splits inside ONE atomic transaction (BEGIN IMMEDIATE).
        Supports equal and custom splits with strict paisa financial math.
        """
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        user_id = ctx.user.id if ctx.user else "demo_system"
        req_hash = compute_request_hash(payload.model_dump(mode="json"))

        # Check idempotency cache
        cached = check_idempotency(
            session=session,
            user_id=user_id,
            endpoint="/api/expenses",
            key=idempotency_key,
            request_hash=req_hash,
        )
        if cached:
            return cached[1]

        # 1. Parse total amount to paisa (Rule 1)
        total_paisa = parse_pkr(payload.amount)

        # 2. Resolve Payer (Rule 3)
        payer = MemberRepository.resolve_member(session, ctx.household_id, payload.payer_id)
        if not payer:
            raise NotFoundError(f"Payer '{payload.payer_id}' not found in household.")

        # 3. Process Splits
        splits_to_insert: List[tuple[int, str, int]] = []  # (member_id, member_code, share_paisa)

        if payload.split_type == "equal":
            if not payload.split_members:
                raise ValidationAppError("split_members is required for equal split.")

            # Resolve all split members
            resolved_members = []
            seen_ids = set()
            for mid in payload.split_members:
                m = MemberRepository.resolve_member(session, ctx.household_id, mid)
                if not m:
                    raise NotFoundError(f"Split member '{mid}' not found in household.")
                if m.id in seen_ids:
                    raise DuplicateSplitMember(f"Duplicate member '{mid}' detected in split members list.")
                seen_ids.add(m.id)
                resolved_members.append(m)

            # Domain equal split (handles remainder distribution by ascending code)
            member_codes = [m.code for m in resolved_members]
            equal_allocations = equal_split(total_paisa, member_codes)

            for m in resolved_members:
                share = equal_allocations[m.code]
                splits_to_insert.append((m.id, m.code, share))

        elif payload.split_type == "custom":
            if not payload.custom_splits:
                raise ValidationAppError("custom_splits is required for custom split.")

            allocations_by_code: Dict[str, int] = {}
            resolved_custom = []
            seen_ids = set()

            for item in payload.custom_splits:
                m = MemberRepository.resolve_member(session, ctx.household_id, item.member_id)
                if not m:
                    raise NotFoundError(f"Split member '{item.member_id}' not found in household.")
                if m.id in seen_ids:
                    raise DuplicateSplitMember(f"Duplicate member '{item.member_id}' detected in custom splits.")
                seen_ids.add(m.id)

                share_paisa = parse_pkr(item.amount)
                resolved_custom.append((m, share_paisa))
                allocations_by_code[m.code] = share_paisa

            # Domain custom split validation (asserts exact sum match)
            custom_split_validate(total_paisa, allocations_by_code)

            for m, share in resolved_custom:
                splits_to_insert.append((m.id, m.code, share))
        else:
            raise ValidationAppError(f"Invalid split_type: '{payload.split_type}'.")

        # 4. Resolve Expense Date
        if payload.expense_date is not None:
            expense_date = payload.expense_date
        else:
            try:
                tz = ZoneInfo(settings.TIMEZONE)
                expense_date = datetime.now(tz).date()
            except Exception:
                expense_date = datetime.utcnow().date()

        # 5. Atomic Write Transaction (BEGIN IMMEDIATE)
        with unit_of_work(session, write=True):
            expense = ExpenseRepository.create_expense(
                session=session,
                household_id=ctx.household_id,
                title=payload.title,
                category=payload.category,
                amount_paisa=total_paisa,
                payer_member_id=payer.id,
                split_type=payload.split_type,
                expense_date=expense_date,
                source="manual",
                created_by_user_id=ctx.user.id if ctx.user else None,
            )

            # Create splits
            splits_data = [(mid, share) for mid, _, share in splits_to_insert]
            ExpenseRepository.create_splits(session, expense.id, splits_data)

            res_body = {
                "id": expense.id,
                "title": expense.title,
                "category": expense.category,
                "amount": float(format_pkr(expense.amount_paisa)),
                "amount_paisa": expense.amount_paisa,
                "payer_id": payer.code,
                "split_type": expense.split_type,
                "expense_date": expense.expense_date.isoformat(),
                "source": expense.source,
                "splits": [
                    {
                        "member_id": code,
                        "amount": float(format_pkr(share)),
                        "amount_paisa": share,
                    }
                    for _, code, share in splits_to_insert
                ],
            }

            # Record Idempotency
            record_idempotency(
                session=session,
                user_id=user_id,
                endpoint="/api/expenses",
                key=idempotency_key,
                request_hash=req_hash,
                response_status=201,
                response_body=res_body,
            )

            # Record Audit Log
            AuditRepository.record_audit(
                session=session,
                household_id=ctx.household_id,
                user_id=ctx.user.id if ctx.user else None,
                action="expense_created",
                entity_type="expense",
                entity_id=str(expense.id),
                payload={
                    "title": expense.title,
                    "amount_paisa": expense.amount_paisa,
                    "payer": payer.code,
                    "split_type": expense.split_type,
                },
            )

        return res_body

    @staticmethod
    def list_expenses(
        session: Session,
        ctx: Context,
        member_id: Optional[Union[str, int]] = None,
        from_date: Optional[date] = None,
        to_date: Optional[date] = None,
        category: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Dict[str, Any]]:
        """Lists expenses for the household with eager-loaded splits and optional filters."""
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        target_member_pk = None
        if member_id is not None:
            m = MemberRepository.resolve_member(session, ctx.household_id, member_id)
            if not m:
                raise NotFoundError(f"Member '{member_id}' not found in household.")
            target_member_pk = m.id

        expenses = ExpenseRepository.list_expenses(
            session=session,
            household_id=ctx.household_id,
            member_id=target_member_pk,
            from_date=from_date,
            to_date=to_date,
            category=category,
            limit=limit,
            offset=offset,
        )

        # Lookup table of members for member_id -> code conversion
        members = MemberRepository.list_by_household(session, ctx.household_id)
        member_map = {m.id: m.code for m in members}

        results = []
        for exp in expenses:
            payer_code = member_map.get(exp.payer_member_id, f"M{exp.payer_member_id}")
            splits_list = [
                {
                    "member_id": member_map.get(sp.member_id, str(sp.member_id)),
                    "amount": float(format_pkr(sp.share_paisa)),
                    "amount_paisa": sp.share_paisa,
                }
                for sp in exp.splits
            ]
            results.append({
                "id": exp.id,
                "title": exp.title,
                "category": exp.category,
                "amount": float(format_pkr(exp.amount_paisa)),
                "amount_paisa": exp.amount_paisa,
                "payer_id": payer_code,
                "split_type": exp.split_type,
                "expense_date": exp.expense_date.isoformat(),
                "source": exp.source,
                "splits": splits_list,
            })

        return results

