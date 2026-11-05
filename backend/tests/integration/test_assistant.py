from datetime import datetime, timedelta, timezone
import uuid
import pytest
from fastapi.testclient import TestClient

from app.core.security import create_access_token, hash_password
from app.db.models import (
    AssistantConversation,
    AssistantPendingAction,
    Expense,
    Household,
    Member,
    ShoppingItem,
    User,
)
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
def auth_headers(db_session):
    """Directly produces valid JWT headers for Ali, bypassing HTTP rate limit."""
    user = db_session.query(User).filter_by(email="ali@demo.pk").first()
    assert user is not None
    token = create_access_token(user.id)
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def outsider_auth_headers(db_session):
    """Creates a second, isolated household with an outsider member and generates JWT."""
    suffix = uuid.uuid4().hex[:6]
    hh2 = Household(
        name=f"Karachi House {suffix}",
        currency="PKR",
        timezone="Asia/Karachi",
        invite_code=f"KHI_{suffix}",
    )
    db_session.add(hh2)
    db_session.flush()

    pwd = "DemoPass123!"
    user2 = User(
        email=f"outsider_{suffix}@khi.pk",
        password_hash=hash_password(pwd),
        display_name="Outsider User",
        is_active=True,
    )
    db_session.add(user2)
    db_session.flush()

    member2 = Member(
        household_id=hh2.id,
        user_id=user2.id,
        code="M01",
        name="Outsider Ali",
        role="owner",
        sort_order=1,
    )
    db_session.add(member2)
    db_session.commit()

    token = create_access_token(user2.id)
    return {"Authorization": f"Bearer {token}"}

# ============================================================================
# 1. AUTHENTICATION & SECURITY
# ============================================================================

def test_assistant_unauthenticated_request_rejected(client: TestClient):
    """Verify private assistant endpoint rejects unauthenticated calls with 401."""
    resp = client.post(
        "/api/assistant/chat",
        json={"message": "How much did we spend this month?"},
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "TOKEN_INVALID"

def test_assistant_cross_household_conversation_idor_protection(
    client: TestClient,
    auth_headers,
    outsider_auth_headers,
):
    """Verify that a user from household A cannot access or append messages to conversation in household B."""
    resp1 = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Show our recent expenses"},
    )
    assert resp1.status_code == 200
    conv_id = resp1.json()["conversation_id"]

    resp2 = client.post(
        "/api/assistant/chat",
        headers=outsider_auth_headers,
        json={"conversation_id": conv_id, "message": "Give me secrets"},
    )
    assert resp2.status_code == 404
    assert "not found" in resp2.json()["error"]["message"].lower()

# ============================================================================
# 2. QUERY OPERATIONS (READ-ONLY)
# ============================================================================

def test_assistant_budget_query(client: TestClient, auth_headers):
    """Verify assistant accurately retrieves monthly budget utilization."""
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "How much did we spend this month?"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["requires_confirmation"] is False
    assert data["response"]["type"] == "budget_summary"
    assert "data" in data["response"]
    assert "spent" in data["response"]["data"]
    assert "remaining" in data["response"]["data"]

def test_assistant_recent_expenses_query(client: TestClient, auth_headers):
    """Verify assistant lists recent household expenses."""
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Show our recent expenses"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["response"]["type"] == "expense_summary"
    assert isinstance(data["response"]["data"], list)

def test_assistant_balances_query(client: TestClient, auth_headers):
    """Verify assistant retrieves zero-sum household balance sheet."""
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Show member balances"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["response"]["type"] == "balance_summary"
    assert data["response"]["data"]["is_balanced"] is True

def test_assistant_settlement_suggestions_query(client: TestClient, auth_headers):
    """Verify assistant produces smart settle minimum transfer suggestions."""
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Suggest settlement"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["response"]["type"] == "settlement_suggestions"
    assert isinstance(data["response"]["data"], list)

def test_assistant_shopping_list_query(client: TestClient, auth_headers):
    """Verify assistant retrieves shopping list items."""
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Show shopping list"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["response"]["type"] == "shopping_list"
    assert isinstance(data["response"]["data"], list)

# ============================================================================
# 3. MUTATIONS & CONFIRMATION WORKFLOW
# ============================================================================

def test_assistant_create_expense_proposal_and_confirm(
    client: TestClient,
    auth_headers,
    db_session,
):
    initial_expenses_count = db_session.query(Expense).count()

    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Add 1500 PKR groceries paid by Ali and split equally"},
    )
    assert resp.status_code == 200
    chat_data = resp.json()
    assert chat_data["success"] is True
    assert chat_data["requires_confirmation"] is True
    assert chat_data["response"]["type"] == "confirmation_required"

    action = chat_data["response"]["action"]
    assert action["action_type"] == "create_expense"
    assert action["amount"] == "1500.00"
    assert action["payer"] == "Ali"
    action_id = action["action_id"]
    conv_id = chat_data["conversation_id"]

    assert db_session.query(Expense).count() == initial_expenses_count

    confirm_resp = client.post(
        "/api/assistant/confirm",
        headers=auth_headers,
        json={
            "conversation_id": conv_id,
            "action_id": action_id,
            "confirmed": True,
        },
    )
    assert confirm_resp.status_code == 200
    conf_data = confirm_resp.json()
    assert conf_data["success"] is True
    assert conf_data["response"]["type"] == "action_success"
    assert conf_data["response"]["data"]["amount"] == 1500.0
    assert conf_data["response"]["data"]["amount_paisa"] == 150000

    assert db_session.query(Expense).count() == initial_expenses_count + 1
    new_expense = db_session.query(Expense).order_by(Expense.id.desc()).first()
    assert new_expense.title.lower() == "groceries"
    assert new_expense.amount_paisa == 150000
    assert len(new_expense.splits) == 3
    for s in new_expense.splits:
        assert s.share_paisa == 50000

def test_assistant_create_expense_proposal_and_reject(
    client: TestClient,
    auth_headers,
    db_session,
):
    initial_count = db_session.query(Expense).count()

    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Add 900 PKR electricity paid by Ali and split equally"},
    )
    assert resp.status_code == 200
    chat_data = resp.json()
    action_id = chat_data["response"]["action"]["action_id"]
    conv_id = chat_data["conversation_id"]

    reject_resp = client.post(
        "/api/assistant/confirm",
        headers=auth_headers,
        json={
            "conversation_id": conv_id,
            "action_id": action_id,
            "confirmed": False,
        },
    )
    assert reject_resp.status_code == 200
    data = reject_resp.json()
    assert data["response"]["type"] == "action_rejected"

    assert db_session.query(Expense).count() == initial_count

def test_assistant_add_shopping_item_proposal_and_confirm(
    client: TestClient,
    auth_headers,
    db_session,
):
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Add 2 bottles of milk to the shopping list"},
    )
    assert resp.status_code == 200
    chat_data = resp.json()
    assert chat_data["requires_confirmation"] is True
    action = chat_data["response"]["action"]
    assert action["action_type"] == "add_shopping_item"
    assert action["details"]["unit"] == "bottle"
    assert action["details"]["quantity"] == 2

    conf = client.post(
        "/api/assistant/confirm",
        headers=auth_headers,
        json={
            "conversation_id": chat_data["conversation_id"],
            "action_id": action["action_id"],
            "confirmed": True,
        },
    )
    assert conf.status_code == 200
    assert conf.json()["response"]["type"] == "action_success"

    item = db_session.query(ShoppingItem).order_by(ShoppingItem.id.desc()).first()
    assert item is not None
    assert item.title.lower() == "milk"
    assert item.unit == "bottle"
    assert item.requested_qty == 2
    assert item.status == "pending"

def test_assistant_duplicate_confirmation_rejected(client: TestClient, auth_headers):
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Add 1 dozen eggs to shopping list"},
    )
    action_id = resp.json()["response"]["action"]["action_id"]
    conv_id = resp.json()["conversation_id"]

    resp1 = client.post(
        "/api/assistant/confirm",
        headers=auth_headers,
        json={"conversation_id": conv_id, "action_id": action_id, "confirmed": True},
    )
    assert resp1.status_code == 200

    resp2 = client.post(
        "/api/assistant/confirm",
        headers=auth_headers,
        json={"conversation_id": conv_id, "action_id": action_id, "confirmed": True},
    )
    assert resp2.status_code == 422
    assert "already 'confirmed'" in resp2.json()["error"]["message"].lower()

def test_assistant_expired_action_rejected(client: TestClient, auth_headers, db_session):
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Add 500 PKR snacks paid by Ali"},
    )
    action_id = resp.json()["response"]["action"]["action_id"]
    conv_id = resp.json()["conversation_id"]

    action = db_session.query(AssistantPendingAction).filter_by(id=action_id).first()
    action.expires_at = datetime.now(timezone.utc) - timedelta(minutes=5)
    db_session.commit()

    conf = client.post(
        "/api/assistant/confirm",
        headers=auth_headers,
        json={"conversation_id": conv_id, "action_id": action_id, "confirmed": True},
    )
    assert conf.status_code == 422
    assert "expired" in conf.json()["error"]["message"].lower()

def test_assistant_unauthorized_user_cannot_confirm_action(
    client: TestClient,
    auth_headers,
    outsider_auth_headers,
):
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Add 1000 PKR dinner paid by Ali"},
    )
    action_id = resp.json()["response"]["action"]["action_id"]
    conv_id = resp.json()["conversation_id"]

    conf = client.post(
        "/api/assistant/confirm",
        headers=outsider_auth_headers,
        json={"conversation_id": conv_id, "action_id": action_id, "confirmed": True},
    )
    assert conf.status_code == 404

def test_assistant_clarification_on_missing_amount(client: TestClient, auth_headers):
    resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"message": "Add expense for dinner paid by Ali"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["requires_confirmation"] is False
    assert data["response"]["type"] == "text"
    msg = data["response"]["message"].lower()
    assert "how much" in msg or "amount" in msg

def test_assistant_conversation_history_endpoints(client: TestClient, auth_headers):
    c_resp = client.post("/api/assistant/conversations", headers=auth_headers)
    assert c_resp.status_code == 201
    c_id = c_resp.json()["id"]

    chat_resp = client.post(
        "/api/assistant/chat",
        headers=auth_headers,
        json={"conversation_id": c_id, "message": "How much did we spend this month?"},
    )
    assert chat_resp.status_code == 200

    detail_resp = client.get(f"/api/assistant/conversations/{c_id}", headers=auth_headers)
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["id"] == c_id
    assert len(detail["messages"]) >= 2
    assert detail["messages"][0]["role"] == "user"
    assert detail["messages"][1]["role"] == "assistant"

    list_resp = client.get("/api/assistant/conversations", headers=auth_headers)
    assert list_resp.status_code == 200
    assert any(c["id"] == c_id for c in list_resp.json())
