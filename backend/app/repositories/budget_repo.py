from datetime import date, timedelta
from typing import Optional
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Expense, MonthlyBudget, ShoppingItem

class BudgetRepository:
    @staticmethod
    def get_budget(
        session: Session,
        household_id: str,
        month: str,
    ) -> Optional[MonthlyBudget]:
        return (
            session.query(MonthlyBudget)
            .filter_by(household_id=household_id, month=month)
            .first()
        )

    @staticmethod
    def upsert_budget(
        session: Session,
        household_id: str,
        month: str,
        limit_paisa: int,
    ) -> MonthlyBudget:
        budget = (
            session.query(MonthlyBudget)
            .filter_by(household_id=household_id, month=month)
            .first()
        )
        if budget:
            budget.limit_paisa = limit_paisa
        else:
            budget = MonthlyBudget(
                household_id=household_id,
                month=month,
                limit_paisa=limit_paisa,
            )
            session.add(budget)
        session.flush()
        return budget

    @staticmethod
    def get_monthly_spending(
        session: Session,
        household_id: str,
        month: str,
    ) -> int:
        """Computes total household expenses for the given calendar month."""
        year, m = map(int, month.split("-"))
        start_date = date(year, m, 1)
        if m == 12:
            next_start = date(year + 1, 1, 1)
        else:
            next_start = date(year, m + 1, 1)
        end_date = next_start - timedelta(days=1)

        total = (
            session.query(func.coalesce(func.sum(Expense.amount_paisa), 0))
            .filter(
                Expense.household_id == household_id,
                Expense.expense_date >= start_date,
                Expense.expense_date <= end_date,
            )
            .scalar()
        )
        return int(total)

    @staticmethod
    def get_pending_shopping_count(
        session: Session,
        household_id: str,
    ) -> int:
        return (
            session.query(ShoppingItem)
            .filter(
                ShoppingItem.household_id == household_id,
                ShoppingItem.status == "pending",
            )
            .count()
        )

