import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.core.ratelimit import limiter
from app.db.models import CheckoutItem, Expense, ShoppingItem
from app.db.session import SessionLocal
from app.main import app

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
    assert r.status_code == 200
    return r.json()["access_token"]

class TestCheckoutConcurrency:
    @pytest.mark.parametrize("iteration", range(20))
    def test_concurrent_checkout_exact_one_winner(self, client, iteration):
        """
        CONCURRENCY INVARIANT:
        When two concurrent requests attempt to check out the exact same shopping item
        at the exact same microsecond:
        - Exactly ONE request receives 201 CREATED.
        - The other request receives 409 ITEM_ALREADY_BOUGHT.
        - Exactly ONE expense and ONE checkout_item row are persisted in the database.
        - SQLite BEGIN IMMEDIATE + CAS prevent race conditions, double-buys, and deadlocks.
        Verified over 20 consecutive iterations.
        """
        token = login_seeded_user(client)

        # 1. Create a fresh shopping item
        item_title = f"Concurrent Butter {iteration}_{uuid.uuid4().hex[:4]}"
        r_create = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": item_title, "unit": "pack", "requested_qty": 1},
        )
        assert r_create.status_code == 201
        item_id = r_create.json()["id"]

        # 2. Setup simultaneous execution with Barrier
        barrier = threading.Barrier(2)
        results = []

        payload = {
            "item_ids": [item_id],
            "total_paid": 500.00,
            "payer_id": "M01",
            "split_members": ["M01", "M02", "M03"],
        }

        def attempt_checkout(worker_id: int):
            # Each worker uses a dedicated TestClient instance to avoid client session locking
            worker_client = TestClient(app)
            # Wait for both threads to reach synchronization barrier
            barrier.wait(timeout=5)
            response = worker_client.post(
                "/api/shopping/checkout",
                headers={"Authorization": f"Bearer {token}"},
                json=payload,
            )
            return response.status_code, response.json()

        with ThreadPoolExecutor(max_workers=2) as executor:
            future1 = executor.submit(attempt_checkout, 1)
            future2 = executor.submit(attempt_checkout, 2)
            results.append(future1.result())
            results.append(future2.result())

        status_codes = sorted([r[0] for r in results])

        # Assert exactly one 201 and one 409
        assert status_codes == [201, 409], (
            f"Expected [201, 409] but got {status_codes}. "
            f"Responses: {[r[1] for r in results]}"
        )

        # 3. Database verification
        with SessionLocal() as session:
            # Shopping item is bought
            item = session.query(ShoppingItem).filter_by(id=item_id).first()
            assert item.status == "bought"

            # Exactly one checkout_item record exists for this item
            checkout_rows = session.query(CheckoutItem).filter_by(item_id=item_id).all()
            assert len(checkout_rows) == 1

            # Expense exists and corresponds to the checkout row
            expense_id = checkout_rows[0].expense_id
            expense = session.query(Expense).filter_by(id=expense_id).first()
            assert expense is not None
            assert expense.source == "checkout"

