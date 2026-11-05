from datetime import datetime
from typing import Any, Dict, Optional, Union
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import NotFoundError
from app.db.session import unit_of_work
from app.deps import Context
from app.domain.budget import budget_status
from app.domain.money import format_pkr, parse_pkr
from app.repositories.audit_repo import AuditRepository
from app.repositories.budget_repo import BudgetRepository
from app.repositories.household_repo import HouseholdRepository
from app.repositories.member_repo import MemberRepository
from app.schemas.budget import BudgetSetRequest
from app.services.balance_service import BalanceService
from app.services.expense_service import ExpenseService
from app.services.settlement_service import SettlementService

class BudgetService:
    @staticmethod
    def set_budget(
        session: Session,
        ctx: Context,
        payload: BudgetSetRequest,
    ) -> Dict[str, Any]:
        """Sets or updates the household monthly budget for a specific calendar month."""
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        limit_paisa = parse_pkr(payload.limit)

        with unit_of_work(session, write=True):
            budget = BudgetRepository.upsert_budget(
                session=session,
                household_id=ctx.household_id,
                month=payload.month,
                limit_paisa=limit_paisa,
            )

            AuditRepository.record_audit(
                session=session,
                household_id=ctx.household_id,
                user_id=ctx.user.id if ctx.user else None,
                action="budget_updated",
                entity_type="budget",
                entity_id=f"{ctx.household_id}:{budget.month}",
                payload={"month": budget.month, "limit_paisa": limit_paisa},
            )

        return {
            "month": budget.month,
            "limit": float(format_pkr(limit_paisa)),
            "limit_paisa": limit_paisa,
        }

    @staticmethod
    def get_budget_summary(
        session: Session,
        ctx: Context,
        month: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Calculates budget utilization and remaining balance for a calendar month."""
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        if month is None:
            try:
                tz = ZoneInfo(settings.TIMEZONE)
                active_month = datetime.now(tz).strftime("%Y-%m")
            except Exception:
                active_month = datetime.utcnow().strftime("%Y-%m")
        else:
            active_month = month.strip()

        # Load budget limit (or default)
        budget = BudgetRepository.get_budget(session, ctx.household_id, active_month)
        limit_paisa = budget.limit_paisa if budget else settings.DEFAULT_MONTHLY_BUDGET_PAISA

        # Compute spending for that month
        spent_paisa = BudgetRepository.get_monthly_spending(session, ctx.household_id, active_month)

        # Domain calculation
        status_info = budget_status(spent_paisa=spent_paisa, limit_paisa=limit_paisa)

        return {
            "month": active_month,
            "limit": float(format_pkr(limit_paisa)),
            "limit_paisa": limit_paisa,
            "spent": float(format_pkr(spent_paisa)),
            "spent_paisa": spent_paisa,
            "remaining": float(format_pkr(status_info["remaining_paisa"])),
            "remaining_paisa": status_info["remaining_paisa"],
            "percent": status_info["percent"],
            "status": status_info["status"],
        }

    @staticmethod
    def get_dashboard(
        session: Session,
        ctx: Context,
        member_id: Optional[Union[str, int]] = None,
    ) -> Dict[str, Any]:
        """Provides composite dashboard data for the mobile home view in a single round-trip."""
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        # 1. Household info
        hh = HouseholdRepository.get_by_id(session, ctx.household_id)
        if not hh:
            raise NotFoundError("Household not found.")

        # 2. Budget summary for active month
        budget_summary = BudgetService.get_budget_summary(session, ctx)

        # 3. Member balance
        my_balance = None
        target_code = None
        if member_id is not None:
            mem = MemberRepository.resolve_member(session, ctx.household_id, member_id)
            if mem:
                target_code = mem.code
        elif ctx.member_code:
            target_code = ctx.member_code

        balances_data = BalanceService.get_household_balances(session, ctx)
        if not target_code and balances_data["members"]:
            target_code = balances_data["members"][0]["member_id"]

        member_dict = None
        if target_code:
            target_mem_item = next(
                (m for m in balances_data["members"] if m["member_id"] == target_code),
                None,
            )
            if target_mem_item:
                net_p = target_mem_item["net_balance_paisa"]
                if net_p > 0:
                    msg = f"You are owed PKR {format_pkr(net_p)}"
                elif net_p < 0:
                    msg = f"You owe PKR {format_pkr(abs(net_p))}"
                else:
                    msg = "You are all settled up"

                member_dict = {
                    "id": target_mem_item["member_id"],
                    "name": target_mem_item["name"],
                    "net_balance": target_mem_item["net_balance"],
                    "net_balance_paisa": net_p,
                    "message": msg,
                }
                my_balance = {
                    "paid": target_mem_item["paid"],
                    "paid_paisa": target_mem_item["paid_paisa"],
                    "owed": target_mem_item["owed"],
                    "owed_paisa": target_mem_item["owed_paisa"],
                    "net_balance": target_mem_item["net_balance"],
                    "net_balance_paisa": target_mem_item["net_balance_paisa"],
                    "status": target_mem_item["status"],
                }

        # 4. Pending shopping items count
        pending_shopping = BudgetRepository.get_pending_shopping_count(session, ctx.household_id)

        # 5. Recent expenses (last 5)
        recent_expenses = ExpenseService.list_expenses(session, ctx, limit=5, offset=0)

        # 6. Recent settlements (last 5)
        recent_settlements = SettlementService.list_settlements(session, ctx, limit=5, offset=0)

        return {
            # Contract exact fields
            "month": budget_summary["month"],
            "spent": budget_summary["spent"],
            "spent_paisa": budget_summary["spent_paisa"],
            "limit": budget_summary["limit"],
            "limit_paisa": budget_summary["limit_paisa"],
            "remaining": budget_summary["remaining"],
            "remaining_paisa": budget_summary["remaining_paisa"],
            "percent": budget_summary["percent"],
            "status": budget_summary["status"],
            "member": member_dict,
            "pending_items_count": pending_shopping,

            # Backwards-compatible extra fields
            "household": {
                "id": hh.id,
                "name": hh.name,
                "currency": hh.currency,
            },
            "active_month": budget_summary["month"],
            "budget": {
                "limit": budget_summary["limit"],
                "limit_paisa": budget_summary["limit_paisa"],
                "spent": budget_summary["spent"],
                "spent_paisa": budget_summary["spent_paisa"],
                "remaining": budget_summary["remaining"],
                "remaining_paisa": budget_summary["remaining_paisa"],
                "percent": budget_summary["percent"],
                "status": budget_summary["status"],
            },
            "my_balance": my_balance,
            "pending_shopping_count": pending_shopping,
            "recent_expenses": recent_expenses,
            "recent_settlements": recent_settlements,
        }

