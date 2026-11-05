from datetime import datetime
import uuid
from zoneinfo import ZoneInfo
from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.core.ratelimit import limiter
from app.main import app

@pytest.fixture(autouse=True)
def reset_rate_limiter():
    limiter.reset()
    yield
    limiter.reset()

@pytest.fixture
def client():
    return TestClient(app)

def create_fresh_household_with_members(client: TestClient) -> tuple[str, str, str]:
    """Creates a fresh isolated household with owner (M01) and member (M02)."""
    # 1. Owner
    email_owner = f"owner_{uuid.uuid4().hex[:6]}@test.pk"
    client.post("/api/auth/register", json={"email": email_owner, "password": "SecurePassword123!", "display_name": "Owner User"})
    r_login = client.post("/api/auth/login", json={"email": email_owner, "password": "SecurePassword123!"})
    token_owner = r_login.json()["access_token"]

    r_hh = client.post(
        "/api/households",
        headers={"Authorization": f"Bearer {token_owner}"},
        json={"name": f"Budget Apartment {uuid.uuid4().hex[:4]}"},
    )
    invite_code = r_hh.json()["invite_code"]

    # 2. Member
    email_mem = f"member_{uuid.uuid4().hex[:6]}@test.pk"
    client.post("/api/auth/register", json={"email": email_mem, "password": "SecurePassword123!", "display_name": "Member User"})
    r_mem_login = client.post("/api/auth/login", json={"email": email_mem, "password": "SecurePassword123!"})
    token_mem = r_mem_login.json()["access_token"]
    client.post("/api/households/join", headers={"Authorization": f"Bearer {token_mem}"}, json={"invite_code": invite_code})

    return token_owner, token_mem, invite_code

class TestBudgetAndDashboard:
    def test_set_budget_rbac(self, client):
        """Owner can update monthly budget limit; non-owner member receives 403 FORBIDDEN."""
        token_owner, token_mem, _ = create_fresh_household_with_members(client)

        month_target = "2026-06"
        payload = {"month": month_target, "limit": 7500.00}

        # 1. Member attempt -> 403
        r_forbidden = client.put(
            "/api/budget",
            headers={"Authorization": f"Bearer {token_mem}"},
            json=payload,
        )
        assert r_forbidden.status_code == 403
        assert r_forbidden.json()["error"]["code"] == "FORBIDDEN"

        # 2. Owner attempt -> 200 OK
        r_ok = client.put(
            "/api/budget",
            headers={"Authorization": f"Bearer {token_owner}"},
            json=payload,
        )
        assert r_ok.status_code == 200
        data = r_ok.json()
        assert data["month"] == month_target
        assert data["limit"] == 7500.0
        assert data["limit_paisa"] == 750000

    def test_budget_summary_and_over_budget_transition(self, client):
        """
        Budget utilization transitions:
        - 4200 / 5000 = 84% -> near_limit, remaining 800.00 PKR
        - Adding 1000 -> 5200 / 5000 = 104% -> over_budget, remaining -200.00 PKR
        """
        token_owner, _, _ = create_fresh_household_with_members(client)

        try:
            tz = ZoneInfo(settings.TIMEZONE)
            current_month = datetime.now(tz).strftime("%Y-%m")
        except Exception:
            current_month = datetime.utcnow().strftime("%Y-%m")

        # 1. Set budget limit to 5000.00 PKR
        client.put(
            "/api/budget",
            headers={"Authorization": f"Bearer {token_owner}"},
            json={"month": current_month, "limit": 5000.00},
        )

        # 2. Record 4200.00 PKR in expenses
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_owner}"},
            json={
                "title": "Groceries",
                "amount": 4200.00,
                "payer_id": "M01",
                "split_type": "equal",
                "split_members": ["M01"],
            },
        )

        # 3. GET /api/budget/summary -> 84% near_limit
        r_summary1 = client.get(
            "/api/budget/summary",
            headers={"Authorization": f"Bearer {token_owner}"},
        )
        assert r_summary1.status_code == 200
        s1 = r_summary1.json()
        assert s1["month"] == current_month
        assert s1["limit"] == 5000.0
        assert s1["limit_paisa"] == 500000
        assert s1["spent"] == 4200.0
        assert s1["spent_paisa"] == 420000
        assert s1["remaining"] == 800.0
        assert s1["remaining_paisa"] == 80000
        assert s1["percent"] == 84
        assert s1["status"] == "near_limit"

        # 4. Add another expense of 1000.00 PKR
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_owner}"},
            json={
                "title": "Extra Bill",
                "amount": 1000.00,
                "payer_id": "M01",
                "split_type": "equal",
                "split_members": ["M01"],
            },
        )

        # 5. GET /api/budget/summary -> 104% over_budget, remaining negative
        r_summary2 = client.get(
            "/api/budget/summary",
            headers={"Authorization": f"Bearer {token_owner}"},
        )
        assert r_summary2.status_code == 200
        s2 = r_summary2.json()
        assert s2["spent"] == 5200.0
        assert s2["spent_paisa"] == 520000
        assert s2["remaining"] == -200.0
        assert s2["remaining_paisa"] == -20000
        assert s2["percent"] == 104
        assert s2["status"] == "over_budget"

    def test_dashboard_aggregate_response(self, client):
        """GET /api/dashboard returns all composite home tab widgets in 1 round trip."""
        token_owner, token_mem, _ = create_fresh_household_with_members(client)

        # 1. Add shopping items
        client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token_owner}"},
            json={"title": "Coffee", "unit": "pack", "requested_qty": 1},
        )
        client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token_owner}"},
            json={"title": "Tea", "unit": "pack", "requested_qty": 2},
        )

        # 2. Add an expense split with member M02
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_owner}"},
            json={
                "title": "Groceries Trip",
                "amount": 600.00,
                "payer_id": "M01",
                "split_type": "equal",
                "split_members": ["M01", "M02"],
            },
        )

        # 3. Add a settlement
        client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_mem}"},
            json={"sender_id": "M02", "recipient_id": "M01", "amount": 100.00},
        )

        # 4. Query Dashboard as Owner
        r_dash = client.get(
            "/api/dashboard",
            headers={"Authorization": f"Bearer {token_owner}"},
        )
        assert r_dash.status_code == 200
        dash = r_dash.json()

        # Check household section
        assert "household" in dash
        assert "id" in dash["household"]
        assert dash["household"]["currency"] == "PKR"

        # Check active month and budget
        assert "active_month" in dash
        assert "budget" in dash
        assert dash["budget"]["limit"] > 0
        assert dash["budget"]["spent"] == 600.0

        # Check exact top-level contract fields
        assert "month" in dash
        assert dash["spent"] == 600.0
        assert dash["spent_paisa"] == 60000
        assert "limit" in dash
        assert "limit_paisa" in dash
        assert "remaining" in dash
        assert "remaining_paisa" in dash
        assert "percent" in dash
        assert "status" in dash
        assert dash["pending_items_count"] == 2

        # Check member field
        assert dash["member"] is not None
        assert dash["member"]["id"] == "M01"
        assert dash["member"]["net_balance"] == 200.0
        assert dash["member"]["net_balance_paisa"] == 20000
        assert dash["member"]["message"] == "You are owed PKR 200.00"

        # Check personalized my_balance for owner (M01)
        assert dash["my_balance"] is not None
        assert dash["my_balance"]["status"] == "owed"
        assert dash["my_balance"]["paid"] == 600.0

        # Check pending shopping count
        assert dash["pending_shopping_count"] == 2

        # Check recent expenses and settlements
        assert len(dash["recent_expenses"]) >= 1
        assert len(dash["recent_settlements"]) >= 1

        # Query Dashboard with member_id=M02 query parameter
        r_dash_m02 = client.get(
            "/api/dashboard?member_id=M02",
            headers={"Authorization": f"Bearer {token_owner}"},
        )
        assert r_dash_m02.status_code == 200
        dash_m02 = r_dash_m02.json()
        assert dash_m02["member"]["id"] == "M02"
        assert dash_m02["member"]["message"] == "You owe PKR 200.00"
        assert dash_m02["my_balance"]["status"] == "owes"
        assert dash_m02["my_balance"]["net_balance"] == -200.0  # owed 300, paid 100 back in settlement

    def test_dashboard_month_boundary_asia_karachi(self, client):
        """
        Month boundary test:
        Expense at 23:59:59 Asia/Karachi on last day of month (2026-10-31)
        vs Expense at 00:00:00 Asia/Karachi on next month (2026-11-01).
        Verifies that spending correctly partitions into the respective months.
        """
        token_owner, _, _ = create_fresh_household_with_members(client)

        # 1. Expense on 2026-10-31 (last day of October at 23:59:59 PKT)
        dt_oct = datetime(2026, 10, 31, 23, 59, 59, tzinfo=ZoneInfo("Asia/Karachi"))
        r_oct = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_owner}"},
            json={
                "title": "October Late Expense",
                "amount": 1000.00,
                "payer_id": "M01",
                "split_type": "equal",
                "split_members": ["M01"],
                "expense_date": dt_oct.date().isoformat(),
            },
        )
        assert r_oct.status_code == 201

        # 2. Expense on 2026-11-01 (first day of November at 00:00:00 PKT)
        # Note: 2026-10-31 19:00:00 UTC is exactly 2026-11-01 00:00:00 Asia/Karachi (+5 UTC)
        dt_nov = datetime(2026, 11, 1, 0, 0, 0, tzinfo=ZoneInfo("Asia/Karachi"))
        r_nov = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_owner}"},
            json={
                "title": "November Early Expense",
                "amount": 2000.00,
                "payer_id": "M01",
                "split_type": "equal",
                "split_members": ["M01"],
                "expense_date": dt_nov.date().isoformat(),
            },
        )
        assert r_nov.status_code == 201

        # 3. Verify October budget summary
        r_oct_summary = client.get(
            "/api/budget/summary?month=2026-10",
            headers={"Authorization": f"Bearer {token_owner}"},
        )
        assert r_oct_summary.status_code == 200
        data_oct = r_oct_summary.json()
        assert data_oct["spent"] == 1000.00
        assert data_oct["spent_paisa"] == 100000

        # 4. Verify November budget summary
        r_nov_summary = client.get(
            "/api/budget/summary?month=2026-11",
            headers={"Authorization": f"Bearer {token_owner}"},
        )
        assert r_nov_summary.status_code == 200
        data_nov = r_nov_summary.json()
        assert data_nov["spent"] == 2000.00
        assert data_nov["spent_paisa"] == 200000


