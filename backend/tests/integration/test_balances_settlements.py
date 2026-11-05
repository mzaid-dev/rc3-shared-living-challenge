import uuid
from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.core.ratelimit import limiter
from app.db.models import Settlement
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

def create_fresh_household_with_3_roommates(client: TestClient) -> tuple[str, str, str, str]:
    """Creates a fresh isolated household with 3 roommates: Ali (M01), Ayesha (M02), Bilal (M03)."""
    # 1. Founder (Ali)
    email_ali = f"ali_{uuid.uuid4().hex[:6]}@test.pk"
    client.post("/api/auth/register", json={"email": email_ali, "password": "SecurePassword123!", "display_name": "Ali"})
    r_ali_login = client.post("/api/auth/login", json={"email": email_ali, "password": "SecurePassword123!"})
    token_ali = r_ali_login.json()["access_token"]

    r_hh = client.post("/api/households", headers={"Authorization": f"Bearer {token_ali}"}, json={"name": f"Apartment {uuid.uuid4().hex[:4]}"})
    invite_code = r_hh.json()["invite_code"]

    # 2. Roommate 2 (Ayesha)
    email_ayesha = f"ayesha_{uuid.uuid4().hex[:6]}@test.pk"
    client.post("/api/auth/register", json={"email": email_ayesha, "password": "SecurePassword123!", "display_name": "Ayesha"})
    r_ayesha_login = client.post("/api/auth/login", json={"email": email_ayesha, "password": "SecurePassword123!"})
    token_ayesha = r_ayesha_login.json()["access_token"]
    client.post("/api/households/join", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"invite_code": invite_code})

    # 3. Roommate 3 (Bilal)
    email_bilal = f"bilal_{uuid.uuid4().hex[:6]}@test.pk"
    client.post("/api/auth/register", json={"email": email_bilal, "password": "SecurePassword123!", "display_name": "Bilal"})
    r_bilal_login = client.post("/api/auth/login", json={"email": email_bilal, "password": "SecurePassword123!"})
    token_bilal = r_bilal_login.json()["access_token"]
    client.post("/api/households/join", headers={"Authorization": f"Bearer {token_bilal}"}, json={"invite_code": invite_code})

    return token_ali, token_ayesha, token_bilal, invite_code

class TestBalancesAndSettlements:
    def test_official_benchmark_complete_flow(self, client):
        """
        OFFICIAL SPECIFICATION BENCHMARK (Page 4):
        1. 4 Expenses (780 equal x3, 900 equal Ali+Ayesha, 1500 custom, 1020 equal x3).
        2. Balances check: Total 4200.00. Ali +250.00, Ayesha -450.00, Bilal +200.00. is_balanced: true.
        3. Settlement 1: Ayesha pays Ali 250.00.
        4. Balances check: Ali 0.00 (settled), Ayesha -200.00 (owes), Bilal +200.00 (gets_back).
        5. Settlement 2: Ayesha pays Bilal 200.00.
        6. Balances check: All settled (0.00), is_balanced: true.
        7. Validation checks: Over-settlement 422, self-settlement 422.
        """
        token_ali, token_ayesha, token_bilal, _ = create_fresh_household_with_3_roommates(client)

        # Step 1: Expense 1 - 780.00 PKR equal across M01, M02, M03, paid by Ali (M01)
        r_e1 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={
                "title": "Grocery Trip (Milk & Rice)",
                "category": "Groceries",
                "amount": 780.00,
                "payer_id": "M01",
                "split_type": "equal",
                "split_members": ["M01", "M02", "M03"],
            },
        )
        assert r_e1.status_code == 201

        # Step 2: Expense 2 - 900.00 PKR equal between M01 and M02, paid by Ayesha (M02)
        r_e2 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ayesha}"},
            json={
                "title": "Cleaning Supplies",
                "category": "Household",
                "amount": 900.00,
                "payer_id": "M02",
                "split_type": "equal",
                "split_members": ["M01", "M02"],
            },
        )
        assert r_e2.status_code == 201

        # Step 3: Expense 3 - 1500.00 PKR custom (M01: 500, M02: 300, M03: 700), paid by Bilal (M03)
        r_e3 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_bilal}"},
            json={
                "title": "Internet Bill",
                "category": "Utilities",
                "amount": 1500.00,
                "payer_id": "M03",
                "split_type": "custom",
                "custom_splits": [
                    {"member_id": "M01", "amount": 500.00},
                    {"member_id": "M02", "amount": 300.00},
                    {"member_id": "M03", "amount": 700.00},
                ],
            },
        )
        assert r_e3.status_code == 201

        # Step 4: Expense 4 - 1020.00 PKR equal across M01, M02, M03, paid by Ali (M01)
        r_e4 = client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={
                "title": "Electricity Bill",
                "category": "Utilities",
                "amount": 1020.00,
                "payer_id": "M01",
                "split_type": "equal",
                "split_members": ["M01", "M02", "M03"],
            },
        )
        assert r_e4.status_code == 201

        # Step 5: Check Balances before settlements
        r_bal1 = client.get("/api/balances", headers={"Authorization": f"Bearer {token_ali}"})
        assert r_bal1.status_code == 200
        bal1 = r_bal1.json()

        assert bal1["household_total_spending"] == 4200.0
        assert bal1["household_total_spending_paisa"] == 420000
        assert bal1["is_balanced"] is True

        mem_map1 = {m["member_id"]: m for m in bal1["members"]}
        # Ali M01: paid 1800.00, owed 1550.00, net +250.00 (owed)
        assert mem_map1["M01"]["paid"] == 1800.0
        assert mem_map1["M01"]["owed"] == 1550.0
        assert mem_map1["M01"]["net_balance"] == 250.0
        assert mem_map1["M01"]["net_balance_paisa"] == 25000
        assert mem_map1["M01"]["status"] == "owed"

        # Ayesha M02: paid 900.00, owed 1350.00, net -450.00 (owes)
        assert mem_map1["M02"]["paid"] == 900.0
        assert mem_map1["M02"]["owed"] == 1350.0
        assert mem_map1["M02"]["net_balance"] == -450.0
        assert mem_map1["M02"]["net_balance_paisa"] == -45000
        assert mem_map1["M02"]["status"] == "owes"

        # Bilal M03: paid 1500.00, owed 1300.00, net +200.00 (owed)
        assert mem_map1["M03"]["paid"] == 1500.0
        assert mem_map1["M03"]["owed"] == 1300.0
        assert mem_map1["M03"]["net_balance"] == 200.0
        assert mem_map1["M03"]["net_balance_paisa"] == 20000
        assert mem_map1["M03"]["status"] == "owed"

        # Step 6: Settlement 1 - Ayesha (M02) settles 250.00 to Ali (M01)
        r_s1 = client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_ayesha}"},
            json={"sender_id": "M02", "recipient_id": "M01", "amount": 250.00},
        )
        assert r_s1.status_code == 201
        data_s1 = r_s1.json()
        assert data_s1["sender_id"] == "M02"
        assert data_s1["recipient_id"] == "M01"
        assert data_s1["amount"] == 250.0
        assert data_s1["amount_paisa"] == 25000

        # Step 7: Check Balances after Settlement 1
        r_bal2 = client.get("/api/balances", headers={"Authorization": f"Bearer {token_ali}"})
        assert r_bal2.status_code == 200
        bal2 = r_bal2.json()
        assert bal2["is_balanced"] is True
        mem_map2 = {m["member_id"]: m for m in bal2["members"]}

        # Ali is now settled (net 0.00)
        assert mem_map2["M01"]["net_balance"] == 0.0
        assert mem_map2["M01"]["net_balance_paisa"] == 0
        assert mem_map2["M01"]["status"] == "settled"

        # Ayesha debt reduced to -200.00
        assert mem_map2["M02"]["net_balance"] == -200.0
        assert mem_map2["M02"]["net_balance_paisa"] == -20000
        assert mem_map2["M02"]["status"] == "owes"

        # Bilal still owed +200.00
        assert mem_map2["M03"]["net_balance"] == 200.0
        assert mem_map2["M03"]["net_balance_paisa"] == 20000
        assert mem_map2["M03"]["status"] == "owed"

        # Step 8: Settlement 2 - Ayesha (M02) settles 200.00 to Bilal (M03)
        r_s2 = client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_ayesha}"},
            json={"sender_id": "M02", "recipient_id": "M03", "amount": 200.00},
        )
        assert r_s2.status_code == 201

        # Step 9: Check Balances after Settlement 2 -> ALL 3 SETTLED!
        r_bal3 = client.get("/api/balances", headers={"Authorization": f"Bearer {token_ali}"})
        assert r_bal3.status_code == 200
        bal3 = r_bal3.json()
        assert bal3["is_balanced"] is True
        mem_map3 = {m["member_id"]: m for m in bal3["members"]}

        assert mem_map3["M01"]["status"] == "settled" and mem_map3["M01"]["net_balance_paisa"] == 0
        assert mem_map3["M02"]["status"] == "settled" and mem_map3["M02"]["net_balance_paisa"] == 0
        assert mem_map3["M03"]["status"] == "settled" and mem_map3["M03"]["net_balance_paisa"] == 0

        # Step 9b: Confirm total household spending is STILL 4200.00 PKR (420,000 paisa)
        assert bal3["household_total_spending"] == 4200.0
        assert bal3["household_total_spending_paisa"] == 420000

        r_summary = client.get("/api/budget/summary", headers={"Authorization": f"Bearer {token_ali}"})
        assert r_summary.status_code == 200
        assert r_summary.json()["spent"] == 4200.0
        assert r_summary.json()["spent_paisa"] == 420000

        r_dash = client.get("/api/dashboard", headers={"Authorization": f"Bearer {token_ali}"})
        assert r_dash.status_code == 200
        assert r_dash.json()["spent"] == 4200.0
        assert r_dash.json()["spent_paisa"] == 420000

        # Step 10: Over-settlement attempt -> 422 SETTLE_EXCEEDS_DEBT with message
        r_over = client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_ayesha}"},
            json={"sender_id": "M02", "recipient_id": "M03", "amount": 1.00},
        )
        assert r_over.status_code == 422
        err_over = r_over.json()["error"]
        assert err_over["code"] == "SETTLE_EXCEEDS_DEBT"
        assert "0.00 PKR" in err_over["message"]

        # Step 11: Self-settlement attempt -> 422 SELF_SETTLEMENT
        r_self = client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={"sender_id": "M01", "recipient_id": "M01", "amount": 10.00},
        )
        assert r_self.status_code == 422
        assert r_self.json()["error"]["code"] == "SELF_SETTLEMENT"

    def test_settle_exceeds_credit_validation(self, client):
        """Cannot settle more than the recipient's outstanding credit."""
        token_ali, token_ayesha, _, _ = create_fresh_household_with_3_roommates(client)

        # Ali pays 100.00 split between Ali and Ayesha -> Ali credit is 50.00, Ayesha debt is 50.00
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={"title": "Snacks", "amount": 100.00, "payer_id": "M01", "split_type": "equal", "split_members": ["M01", "M02"]},
        )

        # Ayesha tries to settle 60.00 to Ali (exceeds Ali's credit of 50.00)
        r = client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_ayesha}"},
            json={"sender_id": "M02", "recipient_id": "M01", "amount": 60.00},
        )
        assert r.status_code == 422
        err = r.json()["error"]
        assert err["code"] == "SETTLE_EXCEEDS_DEBT" or err["code"] == "SETTLE_EXCEEDS_CREDIT"

    def test_settlement_idempotency_workflow(self, client):
        """Submitting with same Idempotency-Key returns cached response without duplicate row."""
        token_ali, token_ayesha, _, _ = create_fresh_household_with_3_roommates(client)

        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={"title": "Lunch", "amount": 200.00, "payer_id": "M01", "split_type": "equal", "split_members": ["M01", "M02"]},
        )

        idemp_key = f"idemp-settle-{uuid.uuid4()}"
        payload = {"sender_id": "M02", "recipient_id": "M01", "amount": 50.00}

        r1 = client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_ayesha}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r1.status_code == 201
        data1 = r1.json()

        r2 = client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_ayesha}", "Idempotency-Key": idemp_key},
            json=payload,
        )
        assert r2.status_code == 201
        data2 = r2.json()
        assert data1["id"] == data2["id"]

        with SessionLocal() as session:
            count = session.query(Settlement).filter_by(id=data1["id"]).count()
            assert count == 1

    def test_list_settlements_and_filtering(self, client):
        """GET /api/settlements returns history with optional member_id filter."""
        token_ali, token_ayesha, token_bilal, _ = create_fresh_household_with_3_roommates(client)

        # Create expense and settlement
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={"title": "Coffee", "amount": 300.00, "payer_id": "M01", "split_type": "equal", "split_members": ["M01", "M02", "M03"]},
        )
        client.post(
            "/api/settle",
            headers={"Authorization": f"Bearer {token_ayesha}"},
            json={"sender_id": "M02", "recipient_id": "M01", "amount": 100.00},
        )

        # List all settlements
        r_all = client.get("/api/settlements", headers={"Authorization": f"Bearer {token_ali}"})
        assert r_all.status_code == 200
        items = r_all.json()
        assert len(items) >= 1
        assert items[0]["sender_id"] == "M02"
        assert items[0]["recipient_id"] == "M01"
        assert items[0]["amount"] == 100.0

        # Filter by member_id
        r_mem = client.get("/api/settlements?member_id=M02", headers={"Authorization": f"Bearer {token_ali}"})
        assert r_mem.status_code == 200
        assert len(r_mem.json()) >= 1

    def test_settle_negative_validations(self, client):
        """
        Comprehensive negative settle validation tests:
        0, -5, 'abc', 12.345, self,
        Ayesha->Ali 300 (exceeds credit),
        Ayesha->Bilal 500 (exceeds debt),
        Ayesha->Bilal 300 (exceeds credit),
        Ali->Ayesha 10 (creditor cannot initiate debt settlement).
        """
        token_ali, token_ayesha, token_bilal, _ = create_fresh_household_with_3_roommates(client)

        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={"title": "Exp1", "amount": 780.00, "payer_id": "M01", "split_type": "equal", "split_members": ["M01", "M02", "M03"]},
        )
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ayesha}"},
            json={"title": "Exp2", "amount": 900.00, "payer_id": "M02", "split_type": "equal", "split_members": ["M01", "M02"]},
        )
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_bilal}"},
            json={
                "title": "Exp3",
                "amount": 1500.00,
                "payer_id": "M03",
                "split_type": "custom",
                "custom_splits": [
                    {"member_id": "M01", "amount": 500.00},
                    {"member_id": "M02", "amount": 300.00},
                    {"member_id": "M03", "amount": 700.00},
                ],
            },
        )
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={"title": "Exp4", "amount": 1020.00, "payer_id": "M01", "split_type": "equal", "split_members": ["M01", "M02", "M03"]},
        )

        # 1. amount = 0 -> 422
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"sender_id": "M02", "recipient_id": "M01", "amount": 0})
        assert r.status_code == 422
        assert r.json()["error"]["code"] in ("INVALID_AMOUNT", "VALIDATION_ERROR")

        # 2. amount = -5 -> 422
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"sender_id": "M02", "recipient_id": "M01", "amount": -5})
        assert r.status_code == 422
        assert r.json()["error"]["code"] in ("INVALID_AMOUNT", "VALIDATION_ERROR")

        # 3. amount = "abc" -> 422
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"sender_id": "M02", "recipient_id": "M01", "amount": "abc"})
        assert r.status_code == 422
        assert r.json()["error"]["code"] in ("INVALID_AMOUNT", "VALIDATION_ERROR")

        # 4. amount = 12.345 -> 422
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"sender_id": "M02", "recipient_id": "M01", "amount": 12.345})
        assert r.status_code == 422
        assert r.json()["error"]["code"] in ("INVALID_AMOUNT", "VALIDATION_ERROR")

        # 5. self settlement -> 422 SELF_SETTLEMENT
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"sender_id": "M02", "recipient_id": "M02", "amount": 100})
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "SELF_SETTLEMENT"

        # 6. Ayesha -> Ali 300 CREDIT (Ali credit is 250) -> 422 SETTLE_EXCEEDS_CREDIT
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"sender_id": "M02", "recipient_id": "M01", "amount": 300.00})
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "SETTLE_EXCEEDS_CREDIT"
        assert "250.00 PKR" in r.json()["error"]["message"]

        # 7. Ayesha -> Bilal 500 DEBT (Ayesha debt is 450) -> 422 SETTLE_EXCEEDS_DEBT
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"sender_id": "M02", "recipient_id": "M03", "amount": 500.00})
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "SETTLE_EXCEEDS_DEBT"
        assert "450.00 PKR" in r.json()["error"]["message"]

        # 8. Ayesha -> Bilal 300 CREDIT (Bilal credit is 200) -> 422 SETTLE_EXCEEDS_CREDIT
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ayesha}"}, json={"sender_id": "M02", "recipient_id": "M03", "amount": 300.00})
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "SETTLE_EXCEEDS_CREDIT"
        assert "200.00 PKR" in r.json()["error"]["message"]

        # 9. Ali -> Ayesha 10 (Ali is a creditor +250, not a debtor) -> 422 SETTLE_EXCEEDS_DEBT
        r = client.post("/api/settle", headers={"Authorization": f"Bearer {token_ali}"}, json={"sender_id": "M01", "recipient_id": "M02", "amount": 10.00})
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "SETTLE_EXCEEDS_DEBT"
        assert "not a debtor" in r.json()["error"]["message"]

    def test_two_simultaneous_ayesha_ali_settles(self, client):
        """Two simultaneous Ayesha->Ali 250 settles result in exactly one 201 and one 422."""
        from concurrent.futures import ThreadPoolExecutor

        token_ali, token_ayesha, token_bilal, _ = create_fresh_household_with_3_roommates(client)

        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={"title": "Exp1", "amount": 780.00, "payer_id": "M01", "split_type": "equal", "split_members": ["M01", "M02", "M03"]},
        )
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ayesha}"},
            json={"title": "Exp2", "amount": 900.00, "payer_id": "M02", "split_type": "equal", "split_members": ["M01", "M02"]},
        )
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_bilal}"},
            json={
                "title": "Exp3",
                "amount": 1500.00,
                "payer_id": "M03",
                "split_type": "custom",
                "custom_splits": [
                    {"member_id": "M01", "amount": 500.00},
                    {"member_id": "M02", "amount": 300.00},
                    {"member_id": "M03", "amount": 700.00},
                ],
            },
        )
        client.post(
            "/api/expenses",
            headers={"Authorization": f"Bearer {token_ali}"},
            json={"title": "Exp4", "amount": 1020.00, "payer_id": "M01", "split_type": "equal", "split_members": ["M01", "M02", "M03"]},
        )

        def make_settle():
            return client.post(
                "/api/settle",
                headers={"Authorization": f"Bearer {token_ayesha}"},
                json={"sender_id": "M02", "recipient_id": "M01", "amount": 250.00},
            )

        with ThreadPoolExecutor(max_workers=2) as executor:
            f1 = executor.submit(make_settle)
            f2 = executor.submit(make_settle)
            res1 = f1.result()
            res2 = f2.result()

        status_codes = sorted([res1.status_code, res2.status_code])
        assert status_codes == [201, 422], f"Expected [201, 422], got {status_codes}"

