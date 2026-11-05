from datetime import date
from typing import List, Optional, Tuple
from sqlalchemy import or_, select
from sqlalchemy.orm import Session, joinedload

from app.db.models import Expense, ExpenseSplit

class ExpenseRepository:
    @staticmethod
    def create_expense(
        session: Session,
        household_id: str,
        title: str,
        category: str,
        amount_paisa: int,
        payer_member_id: int,
        split_type: str,
        expense_date: date,
        source: str = "manual",
        created_by_user_id: Optional[str] = None,
    ) -> Expense:
        expense = Expense(
            household_id=household_id,
            title=title,
            category=category,
            amount_paisa=amount_paisa,
            payer_member_id=payer_member_id,
            split_type=split_type,
            expense_date=expense_date,
            source=source,
            created_by_user_id=created_by_user_id,
        )
        session.add(expense)
        session.flush()
        return expense

    @staticmethod
    def create_splits(
        session: Session,
        expense_id: int,
        splits: List[Tuple[int, int]],
    ) -> None:
        """
        Inserts expense split rows in batch.
        splits: List of (member_id, share_paisa)
        """
        for member_id, share_paisa in splits:
            split_row = ExpenseSplit(
                expense_id=expense_id,
                member_id=member_id,
                share_paisa=share_paisa,
            )
            session.add(split_row)
        session.flush()

    @staticmethod
    def get_by_id(
        session: Session,
        household_id: str,
        expense_id: int,
    ) -> Optional[Expense]:
        return (
            session.query(Expense)
            .options(joinedload(Expense.splits))
            .filter(
                Expense.household_id == household_id,
                Expense.id == expense_id,
            )
            .first()
        )

    @staticmethod
    def list_expenses(
        session: Session,
        household_id: str,
        member_id: Optional[int] = None,
        from_date: Optional[date] = None,
        to_date: Optional[date] = None,
        category: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Expense]:
        query = (
            session.query(Expense)
            .options(joinedload(Expense.splits))
            .filter(Expense.household_id == household_id)
        )

        if member_id is not None:
            split_stmt = (
                select(ExpenseSplit.expense_id)
                .where(ExpenseSplit.member_id == member_id)
            )
            query = query.filter(
                or_(
                    Expense.payer_member_id == member_id,
                    Expense.id.in_(split_stmt),
                )
            )

        if from_date is not None:
            query = query.filter(Expense.expense_date >= from_date)

        if to_date is not None:
            query = query.filter(Expense.expense_date <= to_date)

        if category is not None:
            query = query.filter(Expense.category == category)

        return (
            query.order_by(Expense.expense_date.desc(), Expense.id.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )
