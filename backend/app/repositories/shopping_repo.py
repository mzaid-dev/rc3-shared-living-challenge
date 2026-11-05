from typing import List, Optional
from sqlalchemy.orm import Session

from app.db.models import ShoppingItem

class ShoppingRepository:
    @staticmethod
    def list_items(
        session: Session,
        household_id: str,
        status: Optional[str] = None,
    ) -> List[ShoppingItem]:
        """Lists shopping items for a household, ordered newest first."""
        query = session.query(ShoppingItem).filter(ShoppingItem.household_id == household_id)
        if status is not None:
            query = query.filter(ShoppingItem.status == status)
        return query.order_by(ShoppingItem.id.desc()).all()

    @staticmethod
    def get_by_id(
        session: Session,
        household_id: str,
        item_id: int,
    ) -> Optional[ShoppingItem]:
        """Finds a single shopping item scoped to the household."""
        return (
            session.query(ShoppingItem)
            .filter(
                ShoppingItem.household_id == household_id,
                ShoppingItem.id == item_id,
            )
            .first()
        )

    @staticmethod
    def get_by_ids(
        session: Session,
        household_id: str,
        item_ids: List[int],
    ) -> List[ShoppingItem]:
        """Finds multiple shopping items scoped to the household."""
        if not item_ids:
            return []
        return (
            session.query(ShoppingItem)
            .filter(
                ShoppingItem.household_id == household_id,
                ShoppingItem.id.in_(item_ids),
            )
            .all()
        )

    @staticmethod
    def create_item(
        session: Session,
        household_id: str,
        title: str,
        unit: str,
        requested_qty: int,
        created_by_member_id: Optional[int] = None,
    ) -> ShoppingItem:
        """Creates a new shopping item with status 'pending'."""
        item = ShoppingItem(
            household_id=household_id,
            title=title,
            unit=unit,
            requested_qty=requested_qty,
            status="pending",
            created_by_member_id=created_by_member_id,
        )
        session.add(item)
        session.flush()
        return item

