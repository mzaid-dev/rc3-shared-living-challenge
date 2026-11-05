from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError, ValidationAppError
from app.core.idempotency import (
    check_idempotency,
    compute_request_hash,
    record_idempotency,
)
from app.db.session import unit_of_work
from app.deps import Context
from app.repositories.audit_repo import AuditRepository
from app.repositories.shopping_repo import ShoppingRepository
from app.schemas.shopping import ShoppingItemCreate, ShoppingItemResponse

class ShoppingService:
    @staticmethod
    def list_shopping_items(
        session: Session,
        ctx: Context,
        status: Optional[str] = None,
        include_bought: Optional[bool] = None,
    ) -> List[Dict[str, Any]]:
        """Lists shopping items for caller's household with optional status filter."""
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        filter_status = None
        if status is not None:
            clean_status = status.strip().lower()
            if clean_status not in ("pending", "bought"):
                raise ValidationAppError("Status filter must be 'pending' or 'bought'.")
            filter_status = clean_status
        elif include_bought is False:
            filter_status = "pending"

        items = ShoppingRepository.list_items(
            session=session,
            household_id=ctx.household_id,
            status=filter_status,
        )

        return [
            {
                "id": i.id,
                "title": i.title,
                "unit": i.unit,
                "requested_qty": i.requested_qty,
                "status": i.status,
            }
            for i in items
        ]

    @staticmethod
    def create_shopping_item(
        session: Session,
        ctx: Context,
        payload: ShoppingItemCreate,
        idempotency_key: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Creates a shopping item with idempotency support and audit logging in 1 transaction."""
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        user_id = ctx.user.id if ctx.user else "demo_system"
        req_hash = compute_request_hash(payload.model_dump())

        # Check idempotency cache
        cached = check_idempotency(
            session=session,
            user_id=user_id,
            endpoint="/api/shopping",
            key=idempotency_key,
            request_hash=req_hash,
        )
        if cached:
            return cached[1]

        with unit_of_work(session, write=True):
            item = ShoppingRepository.create_item(
                session=session,
                household_id=ctx.household_id,
                title=payload.title,
                unit=payload.unit,
                requested_qty=payload.requested_qty,
                created_by_member_id=ctx.member_id,
            )

            res_dict = {
                "id": item.id,
                "title": item.title,
                "unit": item.unit,
                "requested_qty": item.requested_qty,
                "status": item.status,
            }

            # Record Idempotency
            record_idempotency(
                session=session,
                user_id=user_id,
                endpoint="/api/shopping",
                key=idempotency_key,
                request_hash=req_hash,
                response_status=201,
                response_body=res_dict,
            )

            # Record Audit Log
            AuditRepository.record_audit(
                session=session,
                household_id=ctx.household_id,
                user_id=ctx.user.id if ctx.user else None,
                action="shopping_item_created",
                entity_type="shopping_item",
                entity_id=str(item.id),
                payload={
                    "title": item.title,
                    "unit": item.unit,
                    "requested_qty": item.requested_qty,
                },
            )

        return res_dict

