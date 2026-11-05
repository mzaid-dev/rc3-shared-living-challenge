import uuid
from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.core.ratelimit import limiter
from app.db.models import AuditLog, CheckoutItem, Expense, ExpenseSplit, ShoppingItem
from app.db.session import SessionLocal
from app.main import app
from app.repositories.expense_repo import ExpenseRepository

@pytest.fixture(autouse=True)
def reset_rate_limiter():
    limiter.reset()
    yield
    limiter.reset()

@pytest.fixture
def client():
    return TestClient(app)

def login_seeded_user(client: TestClient, email: str = "ali@demo.pk") -> str:
    r = client.post("/api/auth/login", json={"email": email, "password": settings.DEMO_PASSWORD})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]

def create_user_and_household(client: TestClient) -> tuple[str, str]:
    email = f"user_{uuid.uuid4().hex[:8]}@test.pk"
    client.post(
        "/api/auth/register",
        json={"email": email, "password": "SecurePassword123!", "display_name": "Test User"},
    )
    r_login = client.post(
        "/api/auth/login",
        json={"email": email, "password": "SecurePassword123!"},
    )
    token = r_login.json()["access_token"]
    client.post(
        "/api/households",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": f"Home {uuid.uuid4().hex[:6]}"},
    )
    return email, token

class TestCheckoutAPI:
    def test_checkout_happy_path(self, client):
        """Happy path: 2 items checked out for 780.00 split 3 ways -> 260.00 each, status 'bought'."""
        token = login_seeded_user(client, "ali@demo.pk")

        # 1. Create two shopping items
        r1 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "Milk", "unit": "bottle", "requested_qty": 2},
        )
        assert r1.status_code == 201
        id1 = r1.json()["id"]

        r2 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "Bread", "unit": "pack", "requested_qty": 1},
        )
        assert r2.status_code == 201
        id2 = r2.json()["id"]

        # 2. Checkout
        checkout_payload = {
            "item_ids": [id1, id2],
            "total_paid": 780.00,
            "payer_id": "M01",
            "split_members": ["M01", "M02", "M03"],
        }
        r_co = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}"},
            json=checkout_payload,
        )
        assert r_co.status_code == 201, r_co.text
        data = r_co.json()
        assert data["amount"] == 780.0
        assert data["amount_paisa"] == 78000
        assert data["payer_id"] == "M01"
        assert data["source"] == "checkout"
        assert data["category"] == "Groceries"
        assert "Grocery: Milk, Bread" in data["title"]
        assert len(data["splits"]) == 3
        assert len(data["items"]) == 2

        for item_out in data["items"]:
            assert item_out["status"] == "bought"

        # 3. Verify items in DB are status 'bought'
        with SessionLocal() as session:
            db_item1 = session.query(ShoppingItem).filter_by(id=id1).first()
            assert db_item1.status == "bought"
            db_item2 = session.query(ShoppingItem).filter_by(id=id2).first()
            assert db_item2.status == "bought"

            # Verify checkout_items records exist
            co_records = session.query(CheckoutItem).filter_by(expense_id=data["id"]).all()
            assert len(co_records) == 2
            assert {r.item_id for r in co_records} == {id1, id2}

    def test_checkout_splits_only_across_split_members_subset(self, client):
        """Checkout 900.00 with split_members [M01, M02] -> 450.00 each, M03 owes nothing."""
        token = login_seeded_user(client, "ali@demo.pk")

        r_item = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": f"Split Item {uuid.uuid4().hex[:4]}", "unit": "bag", "requested_qty": 2},
        )
        assert r_item.status_code == 201
        item_id = r_item.json()["id"]

        checkout_payload = {
            "item_ids": [item_id],
            "total_paid": 900.00,
            "payer_id": "M01",
            "split_members": ["M01", "M02"],
        }
        r_co = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}"},
            json=checkout_payload,
        )
        assert r_co.status_code == 201
        data = r_co.json()
        assert data["amount"] == 900.0
        assert data["amount_paisa"] == 90000

        # Verify splits: exactly M01 and M02 each owe 450.00; M03 owes nothing (no split row)
        split_map = {s["member_id"]: s for s in data["splits"]}
        assert "M01" in split_map
        assert "M02" in split_map
        assert "M03" not in split_map
        assert split_map["M01"]["amount"] == 450.0
        assert split_map["M01"]["amount_paisa"] == 45000
        assert split_map["M02"]["amount"] == 450.0
        assert split_map["M02"]["amount_paisa"] == 45000


    def test_checkout_item_already_bought_returns_409(self, client):
        """Attempting to checkout an item that is already bought returns 409 ITEM_ALREADY_BOUGHT."""
        token = login_seeded_user(client, "ali@demo.pk")

        # 1. Create and checkout item
        r1 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "Eggs", "unit": "dozen", "requested_qty": 1},
        )
        item_id = r1.json()["id"]

        checkout_payload = {
            "item_ids": [item_id],
            "total_paid": 200.00,
            "payer_id": "M01",
            "split_members": ["M01", "M02"],
        }
        r_first = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}"},
            json=checkout_payload,
        )
        assert r_first.status_code == 201

        # Count expenses before duplicate attempt
        with SessionLocal() as session:
            count_before = session.query(Expense).count()

        # 2. Attempt to checkout the same item again
        r_second = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}"},
            json=checkout_payload,
        )
        assert r_second.status_code == 409
        err = r_second.json()["error"]
        assert err["code"] == "ITEM_ALREADY_BOUGHT"

        # Verify no new expense was created
        with SessionLocal() as session:
            count_after = session.query(Expense).count()
            assert count_after == count_before

    def test_checkout_bad_id_among_valid_ids_rolls_back(self, client):
        """If one ID is non-existent, 404 is returned and valid items remain pending."""
        token = login_seeded_user(client, "ali@demo.pk")

        r1 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "Juice", "unit": "bottle", "requested_qty": 1},
        )
        valid_id = r1.json()["id"]
        invalid_id = 999999

        payload = {
            "item_ids": [valid_id, invalid_id],
            "total_paid": 400.00,
            "payer_id": "M01",
            "split_members": ["M01", "M02"],
        }
        r = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
        )
        assert r.status_code == 404
        assert r.json()["error"]["code"] == "NOT_FOUND"

        # Verify valid item is STILL pending
        with SessionLocal() as session:
            item = session.query(ShoppingItem).filter_by(id=valid_id).first()
            assert item.status == "pending"

    def test_checkout_cross_household_item_returns_404(self, client):
        """Attempting to checkout an item belonging to another household returns 404."""
        _, token_a = create_user_and_household(client)
        _, token_b = create_user_and_household(client)

        # Create item in household A
        r_item = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token_a}"},
            json={"title": "Household A Milk", "unit": "bottle", "requested_qty": 1},
        )
        item_id_a = r_item.json()["id"]

        # Household B attempts to checkout item from household A
        payload_b = {
            "item_ids": [item_id_a],
            "total_paid": 150.00,
            "payer_id": "M01",
            "split_members": ["M01"],
        }
        r_co = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token_b}"},
            json=payload_b,
        )
        assert r_co.status_code == 404
        assert r_co.json()["error"]["code"] == "NOT_FOUND"

    def test_checkout_idempotency_workflow(self, client):
        """Submitting twice with same Idempotency-Key returns cached result without duplicate expense."""
        token = login_seeded_user(client, "ali@demo.pk")

        r1 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "Apples", "unit": "bag", "requested_qty": 1},
        )
        item_id = r1.json()["id"]

        idemp_key = f"idemp-co-{uuid.uuid4()}"
        payload = {
            "item_ids": [item_id],
            "total_paid": 500.00,
            "payer_id": "M01",
            "split_members": ["M01", "M02"],
        }

        # First checkout submission
        r_first = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r_first.status_code == 201
        data_first = r_first.json()

        # Replay submission with same key
        r_second = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r_second.status_code == 201
        data_second = r_second.json()
        assert data_first["id"] == data_second["id"]

    def test_checkout_remainder_split_distribution(self, client):
        """1000.00 checkout over 3 members gives 333.34 to M01, 333.33 to M02 and M03."""
        token = login_seeded_user(client, "ali@demo.pk")

        r = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "Rice 10kg", "unit": "bag", "requested_qty": 1},
        )
        item_id = r.json()["id"]

        payload = {
            "item_ids": [item_id],
            "total_paid": 1000.00,
            "payer_id": "M01",
            "split_members": ["M03", "M01", "M02"],
        }
        r_co = client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
        )
        assert r_co.status_code == 201
        splits_map = {s["member_id"]: s for s in r_co.json()["splits"]}
        assert splits_map["M01"]["amount_paisa"] == 33334
        assert splits_map["M02"]["amount_paisa"] == 33333
        assert splits_map["M03"]["amount_paisa"] == 33333

    def test_checkout_rollback_on_failure_leaves_db_untouched(self, monkeypatch):
        """If an error occurs after expense creation, entire transaction rolls back."""
        error_client = TestClient(app, raise_server_exceptions=False)
        token = login_seeded_user(error_client, "ali@demo.pk")

        r = error_client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "Flour", "unit": "bag", "requested_qty": 1},
        )
        item_id = r.json()["id"]

        # Monkeypatch ExpenseRepository.create_splits to raise an intentional error
        def mock_create_splits(*args, **kwargs):
            raise RuntimeError("Simulated transient database error during split insert")

        monkeypatch.setattr(ExpenseRepository, "create_splits", mock_create_splits)

        payload = {
            "item_ids": [item_id],
            "total_paid": 300.00,
            "payer_id": "M01",
            "split_members": ["M01", "M02"],
        }

        r_co = error_client.post(
            "/api/shopping/checkout",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
        )
        assert r_co.status_code == 500

        # Verify that rollback was complete:
        # 1. ShoppingItem must still be pending
        with SessionLocal() as session:
            item = session.query(ShoppingItem).filter_by(id=item_id).first()
            assert item.status == "pending"

            # 2. No orphan expense created
            orphan_exp = session.query(Expense).filter_by(title="Grocery: Flour").first()
            assert orphan_exp is None
