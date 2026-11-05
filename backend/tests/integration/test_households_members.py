import uuid
from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.core.ratelimit import limiter
from app.db.models import Household, Member, User
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

def create_and_login_user(client: TestClient, display_name: str = "Test User") -> tuple[str, str]:
    """Helper to register and login a user, returning (email, access_token)."""
    email = f"user_{uuid.uuid4().hex[:8]}@test.pk"
    password = "SecurePassword123!"
    r_reg = client.post(
        "/api/auth/register",
        json={"email": email, "password": password, "display_name": display_name},
    )
    assert r_reg.status_code == 201, r_reg.text

    r_login = client.post(
        "/api/auth/login",
        json={"email": email, "password": password},
    )
    assert r_login.status_code == 200, r_login.text
    token = r_login.json()["access_token"]
    return email, token

class TestHouseholdsAndMembers:
    def test_official_get_members_returns_raw_array(self, client):
        """
        OFFICIAL REQUIREMENT:
        GET /api/members must return a raw array matching:
        [{"id": "M01", "name": "Ali"}, {"id": "M02", "name": "Ayesha"}, {"id": "M03", "name": "Bilal"}]
        No wrapper like {"data": ...}.
        """
        # Login as seeded user Ali
        r_login = client.post(
            "/api/auth/login",
            json={"email": "ali@demo.pk", "password": settings.DEMO_PASSWORD},
        )
        assert r_login.status_code == 200
        token = r_login.json()["access_token"]

        r = client.get("/api/members", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        members = r.json()
        assert isinstance(members, list)
        assert len(members) >= 3

        # Verify exact shape of elements: id and name
        m01 = next((m for m in members if m["id"] == "M01"), None)
        m02 = next((m for m in members if m["id"] == "M02"), None)
        m03 = next((m for m in members if m["id"] == "M03"), None)

        assert m01 is not None and m01["name"] == "Ali"
        assert m02 is not None and m02["name"] == "Ayesha"
        assert m03 is not None and m03["name"] == "Bilal"
        assert set(m01.keys()) == {"id", "name"}

    def test_get_members_detail_mode(self, client):
        """GET /api/members?detail=true includes role and linked status."""
        r_login = client.post(
            "/api/auth/login",
            json={"email": "ali@demo.pk", "password": settings.DEMO_PASSWORD},
        )
        token = r_login.json()["access_token"]

        r = client.get("/api/members?detail=true", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        members = r.json()
        assert isinstance(members, list)
        m01 = next(m for m in members if m["id"] == "M01")
        assert "role" in m01
        assert m01["role"] == "owner"
        assert "linked" in m01
        assert m01["linked"] is True

    def test_get_current_household_owner_vs_member_privacy(self, client):
        """Invite code is only visible to owner/admin, hidden for regular members."""
        # 1. Owner (Ali)
        r_ali = client.post("/api/auth/login", json={"email": "ali@demo.pk", "password": settings.DEMO_PASSWORD})
        t_ali = r_ali.json()["access_token"]

        r_curr_ali = client.get("/api/households/current", headers={"Authorization": f"Bearer {t_ali}"})
        assert r_curr_ali.status_code == 200
        data_ali = r_curr_ali.json()
        assert data_ali["name"] == "Lahore Apartment"
        assert data_ali["invite_code"] == "LAHORE2026"

        # 2. Member (Ayesha)
        r_ayesha = client.post("/api/auth/login", json={"email": "ayesha@demo.pk", "password": settings.DEMO_PASSWORD})
        t_ayesha = r_ayesha.json()["access_token"]

        r_curr_ayesha = client.get("/api/households/current", headers={"Authorization": f"Bearer {t_ayesha}"})
        assert r_curr_ayesha.status_code == 200
        data_ayesha = r_curr_ayesha.json()
        assert data_ayesha["name"] == "Lahore Apartment"
        assert data_ayesha["invite_code"] is None

    def test_create_household_and_join_lifecycle(self, client):
        """Full lifecycle: Create household -> get invite code -> join -> list members."""
        _, t_founder = create_and_login_user(client, display_name="Hamza Founder")
        _, t_joiner = create_and_login_user(client, display_name="Zain Roommate")

        # 1. Founder creates household
        hh_name = f"Apartment {uuid.uuid4().hex[:6]}"
        r_create = client.post(
            "/api/households",
            headers={"Authorization": f"Bearer {t_founder}"},
            json={"name": hh_name},
        )
        assert r_create.status_code == 201
        hh_data = r_create.json()
        assert hh_data["name"] == hh_name
        invite_code = hh_data["invite_code"]
        assert invite_code is not None

        # Founder is M01
        r_mem_founder = client.get("/api/members", headers={"Authorization": f"Bearer {t_founder}"})
        assert r_mem_founder.status_code == 200
        members = r_mem_founder.json()
        assert len(members) == 1
        assert members[0]["id"] == "M01"
        assert members[0]["name"] == "Hamza Founder"

        # 2. Joiner joins household using invite code
        r_join = client.post(
            "/api/households/join",
            headers={"Authorization": f"Bearer {t_joiner}"},
            json={"invite_code": invite_code},
        )
        assert r_join.status_code == 201
        join_data = r_join.json()
        assert join_data["name"] == hh_name
        assert join_data["invite_code"] is None  # joiner is normal member

        # Joiner sees updated member list with M01 and M02
        r_mem_joiner = client.get("/api/members", headers={"Authorization": f"Bearer {t_joiner}"})
        assert r_mem_joiner.status_code == 200
        joined_members = r_mem_joiner.json()
        assert len(joined_members) == 2
        assert joined_members[0] == {"id": "M01", "name": "Hamza Founder"}
        assert joined_members[1] == {"id": "M02", "name": "Zain Roommate"}

    def test_user_cannot_join_or_create_second_household(self, client):
        """A user cannot belong to multiple households."""
        _, token = create_and_login_user(client, display_name="Single User")

        # Create first household
        r1 = client.post(
            "/api/households",
            headers={"Authorization": f"Bearer {token}"},
            json={"name": "First Home"},
        )
        assert r1.status_code == 201

        # Attempt to create second household -> 422
        r2 = client.post(
            "/api/households",
            headers={"Authorization": f"Bearer {token}"},
            json={"name": "Second Home"},
        )
        assert r2.status_code == 422
        assert r2.json()["error"]["code"] == "VALIDATION_ERROR"

        # Attempt to join another household -> 422
        r3 = client.post(
            "/api/households/join",
            headers={"Authorization": f"Bearer {token}"},
            json={"invite_code": "ANYCODE1"},
        )
        assert r3.status_code == 422

    def test_rotate_invite_code_rbac_and_invalidation(self, client):
        """Only owner/admin can rotate code; old code stops working."""
        _, t_owner = create_and_login_user(client, display_name="Owner X")
        _, t_member = create_and_login_user(client, display_name="Member Y")
        _, t_outsider = create_and_login_user(client, display_name="Outsider Z")

        # Create household
        r_create = client.post(
            "/api/households",
            headers={"Authorization": f"Bearer {t_owner}"},
            json={"name": "Secret Base"},
        )
        old_code = r_create.json()["invite_code"]

        # Member Y joins
        client.post(
            "/api/households/join",
            headers={"Authorization": f"Bearer {t_member}"},
            json={"invite_code": old_code},
        )

        # Member Y attempts to rotate invite code -> 403 FORBIDDEN
        r_rot_forbidden = client.post(
            "/api/households/current/invite-code",
            headers={"Authorization": f"Bearer {t_member}"},
        )
        assert r_rot_forbidden.status_code == 403
        assert r_rot_forbidden.json()["error"]["code"] == "FORBIDDEN"

        # Owner rotates invite code -> 200 OK
        r_rot_ok = client.post(
            "/api/households/current/invite-code",
            headers={"Authorization": f"Bearer {t_owner}"},
        )
        assert r_rot_ok.status_code == 200
        new_code = r_rot_ok.json()["invite_code"]
        assert new_code != old_code

        # Outsider Z tries to join with old code -> 404 NOT_FOUND
        r_join_old = client.post(
            "/api/households/join",
            headers={"Authorization": f"Bearer {t_outsider}"},
            json={"invite_code": old_code},
        )
        assert r_join_old.status_code == 404
        assert r_join_old.json()["error"]["code"] == "NOT_FOUND"

        # Outsider Z joins with new code -> 201 CREATED
        r_join_new = client.post(
            "/api/households/join",
            headers={"Authorization": f"Bearer {t_outsider}"},
            json={"invite_code": new_code},
        )
        assert r_join_new.status_code == 201

    def test_admin_create_unlinked_member(self, client):
        """Owner/admin can create unlinked members; members cannot."""
        _, t_owner = create_and_login_user(client, display_name="Host")
        _, t_member = create_and_login_user(client, display_name="Guest")

        r_create = client.post(
            "/api/households",
            headers={"Authorization": f"Bearer {t_owner}"},
            json={"name": "Villa 101"},
        )
        code = r_create.json()["invite_code"]
        client.post(
            "/api/households/join",
            headers={"Authorization": f"Bearer {t_member}"},
            json={"invite_code": code},
        )

        # Member attempts to create unlinked member -> 403
        r_unauth = client.post(
            "/api/members",
            headers={"Authorization": f"Bearer {t_member}"},
            json={"name": "Grandpa"},
        )
        assert r_unauth.status_code == 403

        # Owner creates unlinked member -> 201
        r_auth = client.post(
            "/api/members",
            headers={"Authorization": f"Bearer {t_owner}"},
            json={"name": "Grandpa"},
        )
        assert r_auth.status_code == 201
        created_mem = r_auth.json()
        assert created_mem["id"] == "M03"
        assert created_mem["name"] == "Grandpa"

        # Duplicate member name in same household is rejected
        r_dup = client.post(
            "/api/members",
            headers={"Authorization": f"Bearer {t_owner}"},
            json={"name": "Grandpa"},
        )
        assert r_dup.status_code == 422
        assert r_dup.json()["error"]["code"] == "VALIDATION_ERROR"

    def test_unaffiliated_user_endpoints_return_404(self, client):
        """User without a household gets 404 NOT_FOUND on current household & members."""
        _, token = create_and_login_user(client, display_name="No Household User")

        r_curr = client.get("/api/households/current", headers={"Authorization": f"Bearer {token}"})
        assert r_curr.status_code == 404
        assert r_curr.json()["error"]["code"] == "NOT_FOUND"

        r_mem = client.get("/api/members", headers={"Authorization": f"Bearer {token}"})
        assert r_mem.status_code == 404
        assert r_mem.json()["error"]["code"] == "NOT_FOUND"
