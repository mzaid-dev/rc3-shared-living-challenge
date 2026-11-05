import datetime
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.core.config import settings
from app.db.base import Base
from app.db.models import (
    CheckoutItem,
    Expense,
    ExpenseSplit,
    Household,
    Member,
    Settlement,
    ShoppingItem,
    User,
)
from app.db.seed import seed_demo_data
from app.db.session import SessionLocal, engine, unit_of_work
from app.main import app

@pytest.fixture(scope="module", autouse=True)
def setup_test_db():
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as session:
        seed_demo_data(session)
    yield

class TestFoundation:
    def test_app_boots_and_health_endpoint(self):
        """Proves that app boots and GET /health returns db ok."""
        with TestClient(app) as client:
            response = client.get("/health")
            assert response.status_code == 200
            assert response.json() == {"status": "ok", "database": "ok"}

    def test_foreign_keys_pragma_is_active(self):
        """Proves that foreign_keys PRAGMA is ON by attempting an orphaned member insert."""
        with SessionLocal() as session:
            # Query pragma directly
            result = session.execute(text("PRAGMA foreign_keys;")).scalar()
            assert result == 1, "PRAGMA foreign_keys is not active"

            # Attempt to insert a member with non-existent household_id
            orphaned_member = Member(
                household_id="non-existent-hh-id",
                code="M99",
                name="Orphan",
                role="member",
            )
            session.add(orphaned_member)
            with pytest.raises(IntegrityError):
                session.commit()
            session.rollback()

    def test_check_constraints_reject_invalid_financial_data(self):
        """Proves that database CHECK constraints reject amount <= 0 and sender == recipient."""
        with SessionLocal() as session:
            hh = session.query(Household).first()
            assert hh is not None
            m1 = session.query(Member).filter_by(household_id=hh.id, code="M01").first()
            m2 = session.query(Member).filter_by(household_id=hh.id, code="M02").first()
            assert m1 is not None and m2 is not None

            # 1. Reject settlement with amount_paisa <= 0
            invalid_settle_zero = Settlement(
                household_id=hh.id,
                sender_member_id=m1.id,
                recipient_member_id=m2.id,
                amount_paisa=0,
            )
            session.add(invalid_settle_zero)
            with pytest.raises(IntegrityError):
                session.commit()
            session.rollback()

            # 2. Reject self-settlement (sender == recipient)
            self_settle = Settlement(
                household_id=hh.id,
                sender_member_id=m1.id,
                recipient_member_id=m1.id,
                amount_paisa=5000,
            )
            session.add(self_settle)
            with pytest.raises(IntegrityError):
                session.commit()
            session.rollback()

            # 3. Reject expense with amount_paisa <= 0
            invalid_expense = Expense(
                household_id=hh.id,
                title="Invalid Zero Expense",
                amount_paisa=-100,
                payer_member_id=m1.id,
                split_type="equal",
                expense_date=datetime.date.today(),
            )
            session.add(invalid_expense)
            with pytest.raises(IntegrityError):
                session.commit()
            session.rollback()

    def test_seed_is_idempotent(self):
        """Proves that running seed_demo_data multiple times creates zero duplicate rows."""
        with SessionLocal() as session:
            count_users_before = session.query(User).count()
            count_members_before = session.query(Member).count()
            count_hh_before = session.query(Household).count()

            # Re-run seed
            seed_demo_data(session)

            assert session.query(User).count() == count_users_before
            assert session.query(Member).count() == count_members_before
            assert session.query(Household).count() == count_hh_before

            # Verify Lahore Apartment seeded members Ali, Ayesha, Bilal
            hh = session.query(Household).filter_by(name="Lahore Apartment").first()
            assert hh is not None
            members = session.query(Member).filter_by(household_id=hh.id).order_by(Member.code).all()
            codes = [m.code for m in members]
            names = [m.name for m in members]
            assert codes == ["M01", "M02", "M03"]
            assert names == ["Ali", "Ayesha", "Bilal"]

    def test_unique_item_id_on_checkout_items_rejects_duplicates(self):
        """Proves that UNIQUE(item_id) on checkout_items rejects duplicate checkouts of the same item."""
        import uuid
        with SessionLocal() as session:
            # Create dedicated isolated test household
            test_hh = Household(
                name=f"CI Test HH {uuid.uuid4().hex[:6]}",
                currency="PKR",
                timezone=settings.TIMEZONE,
                invite_code=f"CIT{uuid.uuid4().hex[:5].upper()}",
            )
            session.add(test_hh)
            session.flush()

            test_payer = Member(
                household_id=test_hh.id,
                name="CI Payer",
                role="owner",
                code="M01",
                sort_order=1,
            )
            session.add(test_payer)
            session.flush()

            # Create a shopping item
            item = ShoppingItem(
                household_id=test_hh.id,
                title="Milk Bottle",
                unit="bottle",
                requested_qty=1,
                status="pending",
            )
            session.add(item)
            session.commit()

            # Create an expense
            expense = Expense(
                household_id=test_hh.id,
                title="Grocery Checkout",
                amount_paisa=26000,
                payer_member_id=test_payer.id,
                split_type="equal",
                expense_date=datetime.date.today(),
            )
            session.add(expense)
            session.flush()

            # Add split so ledger remains balanced
            split = ExpenseSplit(
                expense_id=expense.id,
                member_id=test_payer.id,
                share_paisa=26000,
            )
            session.add(split)
            session.commit()

            # Add checkout item
            ci1 = CheckoutItem(expense_id=expense.id, item_id=item.id)
            session.add(ci1)
            session.commit()

            # Attempt duplicate checkout of the exact same item
            ci2 = CheckoutItem(expense_id=expense.id, item_id=item.id)
            session.add(ci2)
            with pytest.raises(IntegrityError):
                session.commit()
            session.rollback()

    def test_restart_keeps_data_persistence(self):
        """Proves that data persists across database session closures / simulated restarts."""
        test_email = f"persistence_test_{datetime.datetime.now().timestamp()}@demo.pk"
        with unit_of_work(write=True) as session:
            user = User(
                email=test_email,
                password_hash="fake-hash",
                display_name="Persist Guy",
                is_active=True,
            )
            session.add(user)

        # Reopen with a fresh session
        with SessionLocal() as fresh_session:
            persisted = fresh_session.query(User).filter_by(email=test_email).first()
            assert persisted is not None
            assert persisted.display_name == "Persist Guy"

