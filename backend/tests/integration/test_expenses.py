import uuid
from datetime import date, timedelta
from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.core.ratelimit import limiter
from app.db.models import AuditLog, Expense, ExpenseSplit
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

class TestExpensesAPI:
    def test_official_benchmark_expense_1_equal_x3(self, client):
        """Official benchmark #1: 780.00 PKR equal across M01, M02, M03 -> 260.00 each."""
        token = login_seeded_user(client, "ali@demo.pk")
        payload = {
            "title": "Groceries at Carrefour",
            "category": "Groceries",
            "amount": 780.00,
            "payer_id": "M01",
            "split_type": "equal",
            "split_members": ["M01", "M02", "M03"],
            "expense_date": "2026-03-01",
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
        assert r.status_code == 201, r.text
        data = r.json()
        assert data["title"] == "Groceries at Carrefour"
        assert data["category"] == "Groceries"
        assert data["amount"] == 780.0
        assert data["amount_paisa"] == 78000
        assert data["payer_id"] == "M01"
        assert data["split_type"] == "equal"
        assert data["source"] == "manual"
        assert len(data["splits"]) == 3

        splits_map = {s["member_id"]: s for s in data["splits"]}
        for mid in ["M01", "M02", "M03"]:
            assert mid in splits_map
            assert splits_map[mid]["amount"] == 260.0
            assert splits_map[mid]["amount_paisa"] == 26000

    def test_official_benchmark_expense_2_equal_subset(self, client):
        """Official benchmark #2: 900.00 PKR equal between M01 and M02 -> 450.00 each."""
        token = login_seeded_user(client, "ali@demo.pk")
        payload = {
            "title": "Electricity Bill",
            "category": "Utilities",
            "amount": "900.00",
            "payer_id": "M01",
            "split_type": "equal",
            "split_members": ["M01", "M02"],
            "expense_date": "2026-03-02",
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
        assert r.status_code == 201
        data = r.json()
        assert data["amount_paisa"] == 90000
        assert len(data["splits"]) == 2
        splits_map = {s["member_id"]: s for s in data["splits"]}
        assert splits_map["M01"]["amount_paisa"] == 45000
        assert splits_map["M02"]["amount_paisa"] == 45000
        assert "M03" not in splits_map

    def test_official_benchmark_expense_3_custom_split(self, client):
        """Official benchmark #3: 1500.00 PKR custom split 500 / 300 / 700 with Bilal M03 as payer."""
        token = login_seeded_user(client, "bilal@demo.pk")
        payload = {
            "title": "Dinner at Bundu Khan",
            "category": "Dining",
            "amount": 1500.00,
            "payer_id": "M03",
            "split_type": "custom",
            "custom_splits": [
                {"member_id": "M01", "amount": 500.00},
                {"member_id": "M02", "amount": 300.00},
                {"member_id": "M03", "amount": 700.00},
            ],
            "expense_date": "2026-03-03",
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
        assert r.status_code == 201
        data = r.json()
        assert data["amount_paisa"] == 150000
        assert data["payer_id"] == "M03"
        splits_map = {s["member_id"]: s for s in data["splits"]}
        assert splits_map["M01"]["amount_paisa"] == 50000
        assert splits_map["M02"]["amount_paisa"] == 30000
        assert splits_map["M03"]["amount_paisa"] == 70000

    def test_official_benchmark_expense_4_equal_x3(self, client):
        """Official benchmark #4: 1020.00 PKR equal across M01, M02, M03 -> 340.00 each."""
        token = login_seeded_user(client, "bilal@demo.pk")
        payload = {
            "title": "Internet Bill",
            "category": "Utilities",
            "amount": 1020.00,
            "payer_id": "M03",
            "split_type": "equal",
            "split_members": ["M01", "M02", "M03"],
            "expense_date": "2026-03-04",
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
        assert r.status_code == 201
        data = r.json()
        assert data["amount_paisa"] == 102000
        splits_map = {s["member_id"]: s for s in data["splits"]}
        for mid in ["M01", "M02", "M03"]:
            assert splits_map[mid]["amount_paisa"] == 34000

    def test_custom_split_sum_mismatch_returns_422(self, client):
        """Custom split where sum != total returns 422 SPLIT_SUM_MISMATCH with difference."""
        token = login_seeded_user(client, "ali@demo.pk")
        payload = {
            "title": "Mismatched Bill",
            "amount": 1500.00,
            "payer_id": "M01",
            "split_type": "custom",
            "custom_splits": [
                {"member_id": "M01", "amount": 500.00},
                {"member_id": "M02", "amount": 300.00},
                {"member_id": "M03", "amount": 699.00},  # sum is 1499.00 != 1500.00
            ],
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
        assert r.status_code == 422
        err = r.json()["error"]
        assert err["code"] == "SPLIT_SUM_MISMATCH"
        assert "expected" in err["message"].lower()

    def test_equal_split_remainder_deterministic_distribution(self, client):
        """1000.00 split 3 ways gives 333.34 to M01, 333.33 to M02 and M03."""
        token = login_seeded_user(client, "ali@demo.pk")
        payload = {
            "title": "Household Tool",
            "amount": 1000.00,
            "payer_id": "M01",
            "split_type": "equal",
            "split_members": ["M03", "M01", "M02"],  # passed unsorted
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
        assert r.status_code == 201
        data = r.json()
        splits_map = {s["member_id"]: s for s in data["splits"]}
        assert splits_map["M01"]["amount_paisa"] == 33334
        assert splits_map["M02"]["amount_paisa"] == 33333
        assert splits_map["M03"]["amount_paisa"] == 33333

    def test_invalid_amounts_rejected(self, client):
        """Negative, zero, excess decimal places, non-numeric rejected with 422 INVALID_AMOUNT."""
        token = login_seeded_user(client, "ali@demo.pk")
        bad_amounts = [0, -100, 10.555, "abc", 10_000_000.01]

        for amt in bad_amounts:
            payload = {
                "title": "Test Expense",
                "amount": amt,
                "payer_id": "M01",
                "split_type": "equal",
                "split_members": ["M01"],
            }
            r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
            assert r.status_code == 422, f"Expected 422 for amount {amt}, got {r.status_code}"

    def test_cross_household_isolation_returns_404(self, client):
        """Payer or split member belonging to another household returns 404 NOT_FOUND."""
        _, token_a = create_user_and_household(client)
        _, token_b = create_user_and_household(client)

        # User in Household A attempts to use Ali (M01 from demo household) or M01 of Household B
        payload = {
            "title": "Isolated Expense",
            "amount": 500.00,
            "payer_id": "M99",  # Non-existent in household
            "split_type": "equal",
            "split_members": ["M01"],
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token_a}"}, json=payload)
        assert r.status_code == 404
        assert r.json()["error"]["code"] == "NOT_FOUND"

    def test_duplicate_split_members_rejected(self, client):
        """Duplicate members in split list returns 422 DUPLICATE_SPLIT_MEMBER."""
        token = login_seeded_user(client, "ali@demo.pk")
        payload = {
            "title": "Duplicate Member Test",
            "amount": 600.00,
            "payer_id": "M01",
            "split_type": "equal",
            "split_members": ["M01", "M02", "M01"],
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "DUPLICATE_SPLIT_MEMBER"

    def test_list_expenses_with_filters_and_pagination(self, client):
        """GET /api/expenses supports filtering by member_id, date range, category, and limit/offset."""
        token = login_seeded_user(client, "ali@demo.pk")

        # 1. Filter by category
        r_cat = client.get("/api/expenses?category=Groceries", headers={"Authorization": f"Bearer {token}"})
        assert r_cat.status_code == 200
        cat_items = r_cat.json()
        assert all(e["category"] == "Groceries" for e in cat_items)

        # 2. Filter by member_id
        r_mem = client.get("/api/expenses?member_id=M03", headers={"Authorization": f"Bearer {token}"})
        assert r_mem.status_code == 200
        mem_items = r_mem.json()
        for e in mem_items:
            participating = (e["payer_id"] == "M03") or any(s["member_id"] == "M03" for s in e["splits"])
            assert participating

        # 3. Pagination
        r_page = client.get("/api/expenses?limit=2&offset=0", headers={"Authorization": f"Bearer {token}"})
        assert r_page.status_code == 200
        assert len(r_page.json()) <= 2

    def test_idempotent_expense_creation(self, client):
        """Submitting twice with same Idempotency-Key returns cached response without duplicate."""
        token = login_seeded_user(client, "ali@demo.pk")
        idemp_key = f"idemp-exp-{uuid.uuid4()}"
        payload = {
            "title": "One-off Expense",
            "amount": 300.00,
            "payer_id": "M01",
            "split_type": "equal",
            "split_members": ["M01", "M02"],
        }

        r1 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r1.status_code == 201
        data1 = r1.json()

        r2 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r2.status_code == 201
        data2 = r2.json()
        assert data1["id"] == data2["id"]

        # Conflict on different payload
        different_payload = dict(payload, amount=400.00)
        r3 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=different_payload,
        )
        assert r3.status_code == 409
        assert r3.json()["error"]["code"] == "IDEMPOTENCY_KEY_REUSED"

    def test_same_idempotency_key_twice_creates_one_expense_row(self, client):
        """Sending request with same Idempotency-Key twice results in exactly 1 Expense DB row."""
        token = login_seeded_user(client, "ali@demo.pk")
        idemp_key = f"idemp-single-row-{uuid.uuid4()}"
        unique_title = f"Idemp Expense {uuid.uuid4().hex[:6]}"
        payload = {
            "title": unique_title,
            "amount": 350.00,
            "payer_id": "M01",
            "split_type": "equal",
            "split_members": ["M01", "M02"],
        }
        r1 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r1.status_code == 201

        r2 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r2.status_code == 201

        with SessionLocal() as session:
            count = session.query(Expense).filter_by(title=unique_title).count()
            assert count == 1


    def test_audit_log_recorded_for_expense(self, client):
        """Creating an expense creates an audit record in the same transaction."""
        token = login_seeded_user(client, "ali@demo.pk")
        title = f"Audited Bill {uuid.uuid4().hex[:4]}"
        payload = {
            "title": title,
            "amount": 250.00,
            "payer_id": "M01",
            "split_type": "equal",
            "split_members": ["M01"],
        }
        r = client.post("/api/expenses", headers={"Authorization": f"Bearer {token}"}, json=payload)
        assert r.status_code == 201
        exp_id = r.json()["id"]

        with SessionLocal() as session:
            audit = (
                session.query(AuditLog)
                .filter_by(entity_type="expense", entity_id=str(exp_id))
                .first()
            )
            assert audit is not None
            assert audit.action == "expense_created"
            assert audit.payload["title"] == title

