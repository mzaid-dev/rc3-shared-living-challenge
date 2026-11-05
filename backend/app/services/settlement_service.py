from typing import Any, Dict, List, Optional, Union
from sqlalchemy.orm import Session

from app.core.errors import (
    NotFoundError,
    SelfSettlementError,
)
from app.core.idempotency import (
    check_idempotency,
    compute_request_hash,
    record_idempotency,
)
from app.db.session import lock_household, unit_of_work
from app.deps import Context
from app.domain.balances import compute_net
from app.domain.money import format_pkr, parse_pkr
from app.domain.settlement import validate_settlement
from app.repositories.audit_repo import AuditRepository
from app.repositories.ledger_repo import LedgerRepository
from app.repositories.member_repo import MemberRepository
from app.schemas.settle import SettlementCreate

class SettlementService:
    @staticmethod
    def create_settlement(
        session: Session,
        ctx: Context,
        payload: SettlementCreate,
        idempotency_key: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Executes a debt settlement between two members in ONE write transaction.
        Enforces:
        - Sender must be an active debtor with sufficient debt.
        - Recipient must be an active creditor with sufficient credit.
        - Disallows self-settlements.
        - Exact paisa arithmetic and audit logging.
        """
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        user_id = ctx.user.id if ctx.user else "demo_system"
        req_hash = compute_request_hash(payload.model_dump(mode="json"))

        # Check idempotency cache
        cached = check_idempotency(
            session=session,
            user_id=user_id,
            endpoint="/api/settle",
            key=idempotency_key,
            request_hash=req_hash,
        )
        if cached:
            return cached[1]

        # 1. Parse settlement amount to paisa
        amount_paisa = parse_pkr(payload.amount)

        # 2. Resolve Sender and Recipient
        sender = MemberRepository.resolve_member(session, ctx.household_id, payload.sender_id)
        if not sender:
            raise NotFoundError(f"Sender member '{payload.sender_id}' not found in household.")

        recipient = MemberRepository.resolve_member(session, ctx.household_id, payload.recipient_id)
        if not recipient:
            raise NotFoundError(f"Recipient member '{payload.recipient_id}' not found in household.")

        if sender.id == recipient.id:
            raise SelfSettlementError("Cannot settle debt with oneself.")

        # 3. Write Transaction (BEGIN IMMEDIATE)
        with unit_of_work(session, write=True):
            lock_household(session, ctx.household_id)

            # Compute current household net balances
            members = MemberRepository.list_by_household(session, ctx.household_id)
            paid_map = LedgerRepository.get_paid_by_member(session, ctx.household_id)
            owed_map = LedgerRepository.get_owed_by_member(session, ctx.household_id)
            sent_map = LedgerRepository.get_sent_by_member(session, ctx.household_id)
            received_map = LedgerRepository.get_received_by_member(session, ctx.household_id)

            net_by_id = compute_net(
                paid=paid_map,
                owed=owed_map,
                received=received_map,
                sent=sent_map,
                member_ids=[m.id for m in members],
            )
            net_by_code = {m.code: net_by_id[m.id] for m in members}

            # Domain validation
            validate_settlement(
                net=net_by_code,
                sender=sender.code,
                recipient=recipient.code,
                amount_paisa=amount_paisa,
            )

            # Insert settlement record
            settlement = LedgerRepository.create_settlement(
                session=session,
                household_id=ctx.household_id,
                sender_member_id=sender.id,
                recipient_member_id=recipient.id,
                amount_paisa=amount_paisa,
                created_by_user_id=ctx.user.id if ctx.user else None,
            )

            res_body = {
                "id": settlement.id,
                "sender_id": sender.code,
                "recipient_id": recipient.code,
                "amount": float(format_pkr(settlement.amount_paisa)),
                "amount_paisa": settlement.amount_paisa,
                "created_at": settlement.created_at.isoformat(),
            }

            # Record Idempotency
            record_idempotency(
                session=session,
                user_id=user_id,
                endpoint="/api/settle",
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
                action="settlement_created",
                entity_type="settlement",
                entity_id=str(settlement.id),
                payload={
                    "sender": sender.code,
                    "recipient": recipient.code,
                    "amount_paisa": amount_paisa,
                },
            )

        return res_body

    @staticmethod
    def list_settlements(
        session: Session,
        ctx: Context,
        member_id: Optional[Union[str, int]] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Dict[str, Any]]:
        """Lists settlements for household with optional member filter."""
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        target_member_pk = None
        if member_id is not None:
            m = MemberRepository.resolve_member(session, ctx.household_id, member_id)
            if not m:
                raise NotFoundError(f"Member '{member_id}' not found in household.")
            target_member_pk = m.id

        settlements = LedgerRepository.list_settlements(
            session=session,
            household_id=ctx.household_id,
            member_id=target_member_pk,
            limit=limit,
            offset=offset,
        )

        members = MemberRepository.list_by_household(session, ctx.household_id)
        member_map = {m.id: m.code for m in members}

        return [
            {
                "id": s.id,
                "sender_id": member_map.get(s.sender_member_id, str(s.sender_member_id)),
                "recipient_id": member_map.get(s.recipient_member_id, str(s.recipient_member_id)),
                "amount": float(format_pkr(s.amount_paisa)),
                "amount_paisa": s.amount_paisa,
                "created_at": s.created_at.isoformat(),
            }
            for s in settlements
        ]

