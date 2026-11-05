from typing import Any, Dict, List, Optional, Union
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.deps import Context
from app.domain.balances import assert_ledger_balanced, compute_net
from app.domain.money import format_pkr
from app.domain.settlement import simplify_debts
from app.repositories.ledger_repo import LedgerRepository
from app.repositories.member_repo import MemberRepository

class BalanceService:
    @staticmethod
    def get_household_balances(
        session: Session,
        ctx: Context,
        member_id: Optional[Union[str, int]] = None,
    ) -> Dict[str, Any]:
        """
        Computes the complete household balance sheet with net balances.
        If member_id is specified:
        - Validates that the member belongs to caller's authorized household.
        - Raises 404 NotFoundError if the member does not exist or belongs to another household (IDOR protection).
        - Filters the returned members list to that specific member.
        Enforces zero-sum ledger conservation.
        """
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        target_member = None
        if member_id is not None:
            target_member = MemberRepository.resolve_member(session, ctx.household_id, member_id)
            if not target_member:
                raise NotFoundError(f"Member '{member_id}' not found in authorized household.")

        members = MemberRepository.list_by_household(session, ctx.household_id)
        member_ids = [m.id for m in members]

        # 1. Fetch aggregates
        total_spending_paisa = LedgerRepository.get_household_total_spending(session, ctx.household_id)
        paid_map = LedgerRepository.get_paid_by_member(session, ctx.household_id)
        owed_map = LedgerRepository.get_owed_by_member(session, ctx.household_id)
        sent_map = LedgerRepository.get_sent_by_member(session, ctx.household_id)
        received_map = LedgerRepository.get_received_by_member(session, ctx.household_id)

        # 2. Compute net balances via domain layer
        net_map = compute_net(
            paid=paid_map,
            owed=owed_map,
            received=received_map,
            sent=sent_map,
            member_ids=member_ids,
        )

        # 3. Assert zero-sum balance invariant
        assert_ledger_balanced(net_map)

        # 4. Build member balance items
        members_out: List[Dict[str, Any]] = []
        for m in members:
            p = paid_map.get(m.id, 0)
            o = owed_map.get(m.id, 0)
            net = net_map.get(m.id, 0)

            if net > 0:
                status_str = "owed"
            elif net < 0:
                status_str = "owes"
            else:
                status_str = "settled"

            members_out.append({
                "member_id": m.code,
                "name": m.name,
                "paid": float(format_pkr(p)),
                "paid_paisa": p,
                "owed": float(format_pkr(o)),
                "owed_paisa": o,
                "net_balance": float(format_pkr(net)),
                "net_balance_paisa": net,
                "status": status_str,
            })

        # 5. Apply member_id filter if requested
        if target_member is not None:
            members_out = [item for item in members_out if item["member_id"] == target_member.code]

        return {
            "household_total_spending": float(format_pkr(total_spending_paisa)),
            "household_total_spending_paisa": total_spending_paisa,
            "members": members_out,
            "is_balanced": sum(net_map.values()) == 0,
        }

    @staticmethod
    def simplify_household_debts(session: Session, ctx: Context) -> List[Dict[str, Any]]:
        """
        SURPRISE TASK ENDPOINT: Calculates the minimum necessary debt-settlement cash transfers
        to balance all household accounts using greedy bipartite matching.
        Strictly isolated to caller's household.
        """
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        members = MemberRepository.list_by_household(session, ctx.household_id)
        member_ids = [m.id for m in members]

        paid_map = LedgerRepository.get_paid_by_member(session, ctx.household_id)
        owed_map = LedgerRepository.get_owed_by_member(session, ctx.household_id)
        sent_map = LedgerRepository.get_sent_by_member(session, ctx.household_id)
        received_map = LedgerRepository.get_received_by_member(session, ctx.household_id)

        net_map = compute_net(
            paid=paid_map,
            owed=owed_map,
            received=received_map,
            sent=sent_map,
            member_ids=member_ids,
        )

        member_map = {m.id: m.code for m in members}
        net_by_code = {member_map[mid]: net_paisa for mid, net_paisa in net_map.items()}

        raw_trans = simplify_debts(net_by_code)

        return [
            {
                "sender_id": t["sender"],
                "recipient_id": t["recipient"],
                "amount": float(format_pkr(t["amount_paisa"])),
                "amount_paisa": t["amount_paisa"],
            }
            for t in raw_trans
        ]
