import uuid
from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.core.ratelimit import limiter
from app.db.models import AuditLog, ShoppingItem
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
    """Logs in seeded user and returns access token."""
    r = client.post("/api/auth/login", json={"email": email, "password": settings.DEMO_PASSWORD})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]

def create_user_and_household(client: TestClient) -> tuple[str, str]:
    """Helper creating a distinct user with their own private household."""
    email = f"user_{uuid.uuid4().hex[:8]}@test.pk"
    client.post(
        "/api/auth/register",
        json={"email": email, "password": "SecurePassword123!", "display_name": "Test Roommate"},
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

class TestShoppingAPI:
    def test_create_shopping_item_happy_path(self, client):
        """Happy path: create item with valid unit, title, qty returns 201 with pending status."""
        token = login_seeded_user(client)

        payload = {
            "title": "Fresh Milk",
            "unit": "bottle",
            "requested_qty": 2,
        }
        r = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
        )
        assert r.status_code == 201
        data = r.json()
        assert data["title"] == "Fresh Milk"
        assert data["unit"] == "bottle"
        assert data["requested_qty"] == 2
        assert data["status"] == "pending"
        assert isinstance(data["id"], int)

    def test_get_shopping_items_returns_raw_array_newest_first(self, client):
        """Official format: returns raw array of objects, newest item first."""
        token = login_seeded_user(client)

        # Create two distinct items
        item_a_title = f"Item A {uuid.uuid4().hex[:4]}"
        item_b_title = f"Item B {uuid.uuid4().hex[:4]}"

        client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": item_a_title, "unit": "pack", "requested_qty": 1},
        )
        r_b = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": item_b_title, "unit": "bag", "requested_qty": 3},
        )
        id_b = r_b.json()["id"]

        r_list = client.get("/api/shopping", headers={"Authorization": f"Bearer {token}"})
        assert r_list.status_code == 200
        items = r_list.json()
        assert isinstance(items, list)
        assert len(items) >= 2

        # Most recently created item should appear before older ones
        assert items[0]["id"] == id_b
        assert items[0]["title"] == item_b_title
        assert set(items[0].keys()) == {"id", "title", "unit", "requested_qty", "status"}

    def test_validation_blank_title_rejected(self, client):
        """Blank or whitespace-only titles are rejected with 422 VALIDATION_ERROR."""
        token = login_seeded_user(client)

        r = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "   ", "unit": "pack", "requested_qty": 1},
        )
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "VALIDATION_ERROR"

    def test_validation_invalid_unit_rejected(self, client):
        """Units outside allowed set {pack, dozen, bottle, bag} (such as kg and litre) are rejected."""
        token = login_seeded_user(client)

        for invalid_unit in ["kg", "KG", "litre", "liter", "truckload"]:
            r = client.post(
                "/api/shopping",
                headers={"Authorization": f"Bearer {token}"},
                json={"title": "Apples", "unit": invalid_unit, "requested_qty": 1},
            )
            assert r.status_code == 422, f"Expected 422 for unit '{invalid_unit}', got {r.status_code}"
            assert r.json()["error"]["code"] == "VALIDATION_ERROR"
            assert "Invalid unit" in r.text

    def test_validation_allowed_units_accepted(self, client):
        """Allowed units exactly pack, dozen, bottle, bag are accepted."""
        token = login_seeded_user(client)

        for valid_unit in ["pack", "dozen", "bottle", "bag"]:
            r = client.post(
                "/api/shopping",
                headers={"Authorization": f"Bearer {token}"},
                json={"title": f"Valid Item {valid_unit}", "unit": valid_unit, "requested_qty": 1},
            )
            assert r.status_code == 201
            assert r.json()["unit"] == valid_unit

    def test_validation_requested_qty_bounds(self, client):
        """Requested qty <= 0, > 1000, or non-integer rejected with 422."""
        token = login_seeded_user(client)

        invalid_qtys = [0, -5, 1001, 1.5, "five"]
        for q in invalid_qtys:
            r = client.post(
                "/api/shopping",
                headers={"Authorization": f"Bearer {token}"},
                json={"title": "Eggs", "unit": "dozen", "requested_qty": q},
            )
            assert r.status_code == 422, f"Expected 422 for qty {q}, got {r.status_code}"
            assert r.json()["error"]["code"] == "VALIDATION_ERROR"

    def test_mass_assignment_protection_status_forbidden(self, client):
        """Attempting to set status on creation is rejected by extra='forbid'."""
        token = login_seeded_user(client)

        r = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": "Soap", "unit": "pack", "requested_qty": 1, "status": "bought"},
        )
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "VALIDATION_ERROR"

    def test_duplicate_titles_are_allowed(self, client):
        """Households may need two separate entries for the same item name."""
        token = login_seeded_user(client)

        title = f"Sugar {uuid.uuid4().hex[:4]}"
        r1 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": title, "unit": "bag", "requested_qty": 1},
        )
        r2 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": title, "unit": "bag", "requested_qty": 2},
        )
        assert r1.status_code == 201
        assert r2.status_code == 201
        assert r1.json()["id"] != r2.json()["id"]

    def test_cross_household_isolation(self, client):
        """Items created in Household A are invisible to Household B (Hard Rule 3)."""
        _, token_a = create_user_and_household(client)
        _, token_b = create_user_and_household(client)

        # Create item in Household A
        secret_title = f"SecretItem_{uuid.uuid4().hex[:6]}"
        r_create = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token_a}"},
            json={"title": secret_title, "unit": "bottle", "requested_qty": 1},
        )
        assert r_create.status_code == 201

        # Household B lists their items
        r_list_b = client.get("/api/shopping", headers={"Authorization": f"Bearer {token_b}"})
        assert r_list_b.status_code == 200
        titles_b = [i["title"] for i in r_list_b.json()]
        assert secret_title not in titles_b

    def test_idempotent_creation_workflow(self, client):
        """Replaying with same Idempotency-Key returns cached response without duplicate row."""
        token = login_seeded_user(client)
        idemp_key = f"idemp-shop-{uuid.uuid4()}"
        payload = {"title": "Rice", "unit": "bag", "requested_qty": 5}

        # First request
        r1 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r1.status_code == 201
        data1 = r1.json()

        # Replay same request with same key
        r2 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r2.status_code == 201
        data2 = r2.json()
        assert data1["id"] == data2["id"]

        # Replaying same key with different payload triggers 409 IDEMPOTENCY_KEY_REUSED
        different_payload = {"title": "Rice", "unit": "bag", "requested_qty": 10}
        r3 = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": idemp_key},
            json=different_payload,
        )
        assert r3.status_code == 409
        assert r3.json()["error"]["code"] == "IDEMPOTENCY_KEY_REUSED"

    def test_audit_log_recorded_on_creation(self, client):
        """Creating a shopping item records an audit log row in the same transaction."""
        token = login_seeded_user(client)
        title = f"Cooking Oil {uuid.uuid4().hex[:4]}"

        r = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token}"},
            json={"title": title, "unit": "bottle", "requested_qty": 2},
        )
        assert r.status_code == 201
        item_id = r.json()["id"]

        with SessionLocal() as session:
            audit = (
                session.query(AuditLog)
                .filter_by(entity_type="shopping_item", entity_id=str(item_id))
                .first()
            )
            assert audit is not None
            assert audit.action == "shopping_item_created"
            assert audit.payload["title"] == title

