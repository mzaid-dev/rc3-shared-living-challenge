from typing import Dict, List, Optional
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.db.models import Expense, ExpenseSplit, Settlement

class LedgerRepository:
    @staticmethod
    def get_household_total_spending(session: Session, household_id: str) -> int:
        """Returns total spending in paisa for the household."""
        total = (
            session.query(func.coalesce(func.sum(Expense.amount_paisa), 0))
            .filter(Expense.household_id == household_id)
            .scalar()
        )
        return int(total)

    @staticmethod
    def get_paid_by_member(session: Session, household_id: str) -> Dict[int, int]:
        """Returns mapping of member_id -> total paid in paisa."""
        rows = (
            session.query(Expense.payer_member_id, func.sum(Expense.amount_paisa))
            .filter(Expense.household_id == household_id)
            .group_by(Expense.payer_member_id)
            .all()
        )
        return {r[0]: int(r[1]) for r in rows if r[0] is not None}

    @staticmethod
    def get_owed_by_member(session: Session, household_id: str) -> Dict[int, int]:
        """Returns mapping of member_id -> total owed in paisa from expense splits."""
        rows = (
            session.query(ExpenseSplit.member_id, func.sum(ExpenseSplit.share_paisa))
            .join(Expense, ExpenseSplit.expense_id == Expense.id)
            .filter(Expense.household_id == household_id)
            .group_by(ExpenseSplit.member_id)
            .all()
        )
        return {r[0]: int(r[1]) for r in rows if r[0] is not None}

    @staticmethod
    def get_sent_by_member(session: Session, household_id: str) -> Dict[int, int]:
        """Returns mapping of member_id -> total sent in settlements in paisa."""
        rows = (
            session.query(Settlement.sender_member_id, func.sum(Settlement.amount_paisa))
            .filter(Settlement.household_id == household_id)
            .group_by(Settlement.sender_member_id)
            .all()
        )
        return {r[0]: int(r[1]) for r in rows if r[0] is not None}

    @staticmethod
    def get_received_by_member(session: Session, household_id: str) -> Dict[int, int]:
        """Returns mapping of member_id -> total received in settlements in paisa."""
        rows = (
            session.query(Settlement.recipient_member_id, func.sum(Settlement.amount_paisa))
            .filter(Settlement.household_id == household_id)
            .group_by(Settlement.recipient_member_id)
            .all()
        )
        return {r[0]: int(r[1]) for r in rows if r[0] is not None}

    @staticmethod
    def create_settlement(
        session: Session,
        household_id: str,
        sender_member_id: int,
        recipient_member_id: int,
        amount_paisa: int,
        created_by_user_id: Optional[str] = None,
    ) -> Settlement:
        """Inserts and flushes a new settlement transfer record."""
        settlement = Settlement(
            household_id=household_id,
            sender_member_id=sender_member_id,
            recipient_member_id=recipient_member_id,
            amount_paisa=amount_paisa,
            created_by_user_id=created_by_user_id,
        )
        session.add(settlement)
        session.flush()
        return settlement

    @staticmethod
    def list_settlements(
        session: Session,
        household_id: str,
        member_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Settlement]:
        """Lists settlements for household ordered newest first."""
        query = session.query(Settlement).filter(Settlement.household_id == household_id)
        if member_id is not None:
            query = query.filter(
                or_(
                    Settlement.sender_member_id == member_id,
                    Settlement.recipient_member_id == member_id,
                )
            )
        return (
            query.order_by(Settlement.created_at.desc(), Settlement.id.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )

