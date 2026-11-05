import uuid
import pytest
from fastapi.testclient import TestClient

from app.core.security import hash_password
from app.db.models import Household, Member, ShoppingItem, User
from app.db.session import SessionLocal
from app.main import app

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
def db_session():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()

@pytest.fixture
def auth_headers(client: TestClient, db_session):
    """Logs in as Ali (demo owner) and returns authorization headers."""
    resp = client.post(
        "/api/auth/login",
        json={"email": "ali@demo.pk", "password": "DemoPass123!"},
    )
    assert resp.status_code == 200, resp.text
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def isolated_outsider_household(db_session):
    """Creates a second, isolated household with an outsider member."""
    suffix = uuid.uuid4().hex[:6]
    hh2 = Household(
        name=f"Islamabad Flat {suffix}",
        currency="PKR",
        timezone="Asia/Karachi",
        invite_code=f"ISB_{suffix}",
    )
    db_session.add(hh2)
    db_session.flush()

    user2 = User(
        email=f"outsider_{suffix}@isb.pk",
        password_hash=hash_password("DemoPass123!"),
        display_name="Outsider User",
        is_active=True,
    )
    db_session.add(user2)
    db_session.flush()

    member2 = Member(
        household_id=hh2.id,
        user_id=user2.id,
        code=f"X{suffix[:2]}",
        name="Outsider Member",
        role="owner",
        sort_order=1,
    )
    db_session.add(member2)

    item2 = ShoppingItem(
        household_id=hh2.id,
        title="Outsider Coffee",
        unit="pack",
        requested_qty=1,
        status="pending",
    )
    db_session.add(item2)
    db_session.commit()

    return {
        "household_id": hh2.id,
        "member_id": member2.id,
        "member_code": member2.code,
        "item_id": item2.id,
    }

def test_member_switching_preserves_authenticated_session(client: TestClient, auth_headers):
    """
    Option A Verification:
    Switching dashboard perspective across authorized roommates (Ali, Ayesha, Bilal)
    does NOT alter the authenticated user or require re-authentication.
    """
    # 1. View Ali's perspective
    res_ali = client.get("/api/dashboard?member_id=M01", headers=auth_headers)
    assert res_ali.status_code == 200
    data_ali = res_ali.json()
    assert data_ali["member"]["id"] == "M01"
    assert data_ali["member"]["name"] == "Ali"

    # 2. View Ayesha's perspective
    res_ayesha = client.get("/api/dashboard?member_id=M02", headers=auth_headers)
    assert res_ayesha.status_code == 200
    data_ayesha = res_ayesha.json()
    assert data_ayesha["member"]["id"] == "M02"
    assert data_ayesha["member"]["name"] == "Ayesha"

    # 3. View Bilal's perspective
    res_bilal = client.get("/api/dashboard?member_id=M03", headers=auth_headers)
    assert res_bilal.status_code == 200
    data_bilal = res_bilal.json()
    assert data_bilal["member"]["id"] == "M03"
    assert data_bilal["member"]["name"] == "Bilal"

    # 4. Verify /me confirms authenticated identity is STILL Ali throughout
    res_me = client.get("/api/auth/me", headers=auth_headers)
    assert res_me.status_code == 200
    me_data = res_me.json()
    assert me_data["user"]["email"] == "ali@demo.pk"
    assert me_data["member"]["id"] == "M01"

def test_dashboard_rejects_cross_household_and_invalid_members(
    client: TestClient, auth_headers, isolated_outsider_household
):
    """
    IDOR Protection: Requesting dashboard for non-existent or other-household member returns 404.
    """
    # Non-existent member
    res_invalid = client.get("/api/dashboard?member_id=INVALID_999", headers=auth_headers)
    assert res_invalid.status_code == 404
    assert res_invalid.json()["error"]["code"] == "NOT_FOUND"

    # Member belonging to another household
    outsider_code = isolated_outsider_household["member_code"]
    res_cross = client.get(f"/api/dashboard?member_id={outsider_code}", headers=auth_headers)
    assert res_cross.status_code == 404
    assert res_cross.json()["error"]["code"] == "NOT_FOUND"

def test_balances_with_member_id_filter_and_idor_protection(
    client: TestClient, auth_headers, isolated_outsider_household
):
    """
    Tests GET /api/balances?member_id={id} returns single authorized member balance
    and rejects cross-household member lookups.
    """
    # 1. Full balances when no member_id provided
    res_all = client.get("/api/balances", headers=auth_headers)
    assert res_all.status_code == 200
    assert len(res_all.json()["members"]) >= 3

    # 2. Filtered balance for Ali
    res_ali = client.get("/api/balances?member_id=M01", headers=auth_headers)
    assert res_ali.status_code == 200
    members_ali = res_ali.json()["members"]
    assert len(members_ali) == 1
    assert members_ali[0]["member_id"] == "M01"

    # 3. Filtered balance for Ayesha
    res_ayesha = client.get("/api/balances?member_id=M02", headers=auth_headers)
    assert res_ayesha.status_code == 200
    members_ayesha = res_ayesha.json()["members"]
    assert len(members_ayesha) == 1
    assert members_ayesha[0]["member_id"] == "M02"

    # 4. Reject cross-household member
    res_cross = client.get(
        f"/api/balances?member_id={isolated_outsider_household['member_code']}",
        headers=auth_headers,
    )
    assert res_cross.status_code == 404

    # 5. Reject invalid member
    res_nonexistent = client.get("/api/balances?member_id=M_GHOST", headers=auth_headers)
    assert res_nonexistent.status_code == 404

def test_simplify_debts_endpoint(client: TestClient, auth_headers):
    """
    Verifies GET /api/balances/simplify returns optimized debt settlement suggestions.
    """
    # Unauthenticated rejected with 401
    res_unauth = client.get("/api/balances/simplify")
    assert res_unauth.status_code == 401

    # Authenticated succeeds
    res_simplify = client.get("/api/balances/simplify", headers=auth_headers)
    assert res_simplify.status_code == 200
    suggestions = res_simplify.json()
    assert isinstance(suggestions, list)
    for s in suggestions:
        assert "sender_id" in s
        assert "recipient_id" in s
        assert "amount" in s
        assert "amount_paisa" in s
        assert s["amount_paisa"] > 0

def test_financial_operations_cross_household_idor_prevention(
    client: TestClient, auth_headers, isolated_outsider_household
):
    """
    Verifies that expenses, checkout, and settlements strictly reject
    any member or item from another household.
    """
    outsider_code = isolated_outsider_household["member_code"]
    outsider_item = isolated_outsider_household["item_id"]

    # 1. Payer from another household
    res_exp_payer = client.post(
        "/api/expenses",
        headers=auth_headers,
        json={
            "title": "Cross House Bill",
            "category": "Utilities",
            "amount": "100.00",
            "payer_id": outsider_code,
            "split_type": "equal",
            "split_members": ["M01", "M02"],
        },
    )
    assert res_exp_payer.status_code == 404

    # 2. Split participant from another household
    res_exp_split = client.post(
        "/api/expenses",
        headers=auth_headers,
        json={
            "title": "Cross House Bill",
            "category": "Utilities",
            "amount": "100.00",
            "payer_id": "M01",
            "split_type": "equal",
            "split_members": ["M01", outsider_code],
        },
    )
    assert res_exp_split.status_code == 404

    # 3. Checkout with item from another household
    res_checkout = client.post(
        "/api/shopping/checkout",
        headers=auth_headers,
        json={
            "item_ids": [outsider_item],
            "total_paid": "500.00",
            "payer_id": "M01",
            "split_members": ["M01", "M02"],
        },
    )
    assert res_checkout.status_code == 404

    # 4. Settle with outsider as sender or recipient
    res_settle_sender = client.post(
        "/api/settle",
        headers=auth_headers,
        json={
            "sender_id": outsider_code,
            "recipient_id": "M01",
            "amount": "10.00",
        },
    )
    assert res_settle_sender.status_code == 404

    res_settle_recipient = client.post(
        "/api/settle",
        headers=auth_headers,
        json={
            "sender_id": "M02",
            "recipient_id": outsider_code,
            "amount": "10.00",
        },
    )
    assert res_settle_recipient.status_code == 404
