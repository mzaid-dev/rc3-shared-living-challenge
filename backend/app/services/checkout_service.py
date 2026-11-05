from datetime import datetime
from typing import Any, Dict, List, Optional
from zoneinfo import ZoneInfo
from sqlalchemy import update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import (
    FieldError,
    ItemAlreadyBoughtError,
    NotFoundError,
    ValidationAppError,
)
from app.core.idempotency import (
    check_idempotency,
    compute_request_hash,
    record_idempotency,
)
from app.db.models import CheckoutItem, ShoppingItem
from app.db.session import unit_of_work
from app.deps import Context
from app.domain.exceptions import DuplicateSplitMember
from app.domain.money import format_pkr, parse_pkr
from app.domain.split import equal_split
from app.repositories.audit_repo import AuditRepository
from app.repositories.expense_repo import ExpenseRepository
from app.repositories.member_repo import MemberRepository
from app.schemas.checkout import CheckoutRequest

class CheckoutService:
    @staticmethod
    def checkout(
        session: Session,
        ctx: Context,
        payload: CheckoutRequest,
        idempotency_key: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Executes atomic checkout of shopping items into a shared expense.
        Guarantees:
        - Strict ONE-write transaction (BEGIN IMMEDIATE).
        - Compare-and-Set (CAS) atomic item status update.
        - Backstop DB unique constraint on checkout_items.item_id.
        - Full rollback if any item is missing or already bought.
        """
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        user_id = ctx.user.id if ctx.user else "demo_system"
        req_hash = compute_request_hash(payload.model_dump(mode="json"))

        # 1. Idempotency Check
        cached = check_idempotency(
            session=session,
            user_id=user_id,
            endpoint="/api/shopping/checkout",
            key=idempotency_key,
            request_hash=req_hash,
        )
        if cached:
            return cached[1]

        # 2. Parse Total Amount to integer paisa (Rule 1)
        total_paisa = parse_pkr(payload.total_paid)

        # 3. Resolve Payer (Rule 3)
        payer = MemberRepository.resolve_member(session, ctx.household_id, payload.payer_id)
        if not payer:
            raise NotFoundError(f"Payer '{payload.payer_id}' not found in household.")

        # 4. Resolve Split Members
        resolved_split_members = []
        seen_ids = set()
        for mid in payload.split_members:
            m = MemberRepository.resolve_member(session, ctx.household_id, mid)
            if not m:
                raise NotFoundError(f"Split member '{mid}' not found in household.")
            if m.id in seen_ids:
                raise DuplicateSplitMember(f"Duplicate member '{mid}' detected in split members list.")
            seen_ids.add(m.id)
            resolved_split_members.append(m)

        # 5. Domain Equal Split Calculation
        member_codes = [m.code for m in resolved_split_members]
        allocations = equal_split(total_paisa, member_codes)

        # 6. Single Write Transaction (BEGIN IMMEDIATE)
        with unit_of_work(session, write=True):
            # Load shopping items scoped strictly to household_id
            items = (
                session.query(ShoppingItem)
                .filter(
                    ShoppingItem.household_id == ctx.household_id,
                    ShoppingItem.id.in_(payload.item_ids),
                )
                .all()
            )

            # Check for missing or other-household items -> 404 NOT_FOUND
            found_ids = {item.id for item in items}
            missing_ids = [iid for iid in payload.item_ids if iid not in found_ids]
            if missing_ids:
                raise NotFoundError(f"Shopping items not found in household: {missing_ids}")

            # Check if any items are already bought -> 409 ITEM_ALREADY_BOUGHT
            already_bought = [item.id for item in items if item.status != "pending"]
            if already_bought:
                field_errors = [
                    FieldError(field=f"item_ids[{iid}]", issue="Item already bought")
                    for iid in already_bought
                ]
                raise ItemAlreadyBoughtError(
                    f"One or more items are already bought: {already_bought}",
                    fields=field_errors,
                )

            # Determine expense date
            try:
                tz = ZoneInfo(settings.TIMEZONE)
                expense_date = datetime.now(tz).date()
            except Exception:
                expense_date = datetime.utcnow().date()

            # Derive concise expense title from checked-out items
            item_titles = ", ".join(i.title for i in items)
            title = f"Grocery: {item_titles}"[:100]

            # Insert Expense record
            expense = ExpenseRepository.create_expense(
                session=session,
                household_id=ctx.household_id,
                title=title,
                category="Groceries",
                amount_paisa=total_paisa,
                payer_member_id=payer.id,
                split_type="equal",
                expense_date=expense_date,
                source="checkout",
                created_by_user_id=ctx.user.id if ctx.user else None,
            )

            # Insert Expense Splits
            splits_to_insert = [(m.id, allocations[m.code]) for m in resolved_split_members]
            ExpenseRepository.create_splits(session, expense.id, splits_to_insert)

            # Compare-and-Set: UPDATE shopping_items SET status='bought'
            # Must match exact count of pending items
            cas_stmt = (
                update(ShoppingItem)
                .where(
                    ShoppingItem.id.in_(payload.item_ids),
                    ShoppingItem.household_id == ctx.household_id,
                    ShoppingItem.status == "pending",
                )
                .values(status="bought")
            )
            cas_result = session.execute(cas_stmt)
            if cas_result.rowcount != len(payload.item_ids):
                raise ItemAlreadyBoughtError(
                    "One or more items were concurrently modified or already bought."
                )

            # Insert Checkout Items (UNIQUE constraint backstop)
            try:
                for item_id in payload.item_ids:
                    checkout_row = CheckoutItem(expense_id=expense.id, item_id=item_id)
                    session.add(checkout_row)
                session.flush()
            except IntegrityError:
                raise ItemAlreadyBoughtError(
                    "One or more shopping items have already been checked out."
                )

            # Prepare structured response
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
                        "member_id": m.code,
                        "amount": float(format_pkr(allocations[m.code])),
                        "amount_paisa": allocations[m.code],
                    }
                    for m in resolved_split_members
                ],
                "items": [
                    {
                        "id": i.id,
                        "title": i.title,
                        "status": "bought",
                    }
                    for i in items
                ],
            }

            # Record Idempotency Entry
            record_idempotency(
                session=session,
                user_id=user_id,
                endpoint="/api/shopping/checkout",
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
                action="shopping_checkout",
                entity_type="expense",
                entity_id=str(expense.id),
                payload={
                    "item_ids": payload.item_ids,
                    "amount_paisa": total_paisa,
                    "payer": payer.code,
                },
            )

        return res_body

