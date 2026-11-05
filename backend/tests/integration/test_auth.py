from datetime import datetime, timedelta, timezone
import uuid
from fastapi.testclient import TestClient
import jwt
import pytest

from app.core.config import Settings, settings
from app.core.security import create_access_token
from app.db.models import RefreshSession, User
from app.db.session import SessionLocal
from app.main import app

@pytest.fixture
def client():
    return TestClient(app)

class TestAuthentication:
    def test_register_and_login_happy_path(self, client):
        test_email = f"user_{uuid.uuid4().hex[:8]}@test.pk"
        test_pass = "SecurePass123!"

        # 1. Register
        r_reg = client.post(
            "/api/auth/register",
            json={"email": test_email, "password": test_pass, "display_name": "Test User"},
        )
        assert r_reg.status_code == 201
        reg_data = r_reg.json()
        assert reg_data["email"] == test_email.lower()
        assert "password" not in reg_data
        assert "password_hash" not in reg_data

        # 2. Login
        r_login = client.post(
            "/api/auth/login",
            json={"email": test_email, "password": test_pass},
        )
        assert r_login.status_code == 200
        login_data = r_login.json()
        assert "access_token" in login_data
        assert "refresh_token" in login_data
        assert login_data["token_type"] == "bearer"
        assert login_data["expires_in"] == 900
        assert login_data["user"]["email"] == test_email.lower()

        # 3. GET /me with Bearer token
        token = login_data["access_token"]
        r_me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert r_me.status_code == 200
        me_data = r_me.json()
        assert me_data["user"]["email"] == test_email.lower()
        assert me_data["household"] is None  # Registered user has not joined/created a household yet

    def test_duplicate_email_rejected_with_409(self, client):
        email = f"dup_{uuid.uuid4().hex[:8]}@test.pk"
        # Register first time
        client.post(
            "/api/auth/register",
            json={"email": email, "password": "Password123!", "display_name": "First"},
        )
        # Register second time with different casing/spacing
        r_dup = client.post(
            "/api/auth/register",
            json={"email": f"  {email.upper()}  ", "password": "Password123!", "display_name": "Second"},
        )
        assert r_dup.status_code == 409
        assert r_dup.json()["error"]["code"] == "EMAIL_TAKEN"

    def test_wrong_password_and_unknown_email_return_identical_response(self, client):
        # 1. Unknown email
        r_unknown = client.post(
            "/api/auth/login",
            json={"email": "non_existent_email_12345@test.pk", "password": "Password123!"},
        )
        assert r_unknown.status_code == 401
        unknown_body = r_unknown.json()

        # 2. Known email with wrong password
        r_wrong_pw = client.post(
            "/api/auth/login",
            json={"email": "ali@demo.pk", "password": "WrongPassword123!"},
        )
        assert r_wrong_pw.status_code == 401
        wrong_pw_body = r_wrong_pw.json()

        # Responses must be identical (anti-enumeration)
        assert unknown_body["error"]["code"] == wrong_pw_body["error"]["code"] == "INVALID_CREDENTIALS"
        assert unknown_body["error"]["message"] == wrong_pw_body["error"]["message"]

    def test_expired_access_token_rejected(self, client):
        # Generate an expired token
        past = datetime.now(timezone.utc) - timedelta(minutes=10)
        payload = {
            "sub": "some_user_id",
            "iat": int((past - timedelta(minutes=15)).timestamp()),
            "exp": int(past.timestamp()),
            "jti": str(uuid.uuid4()),
            "typ": "access",
        }
        expired_token = jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

        r = client.get("/api/auth/me", headers={"Authorization": f"Bearer {expired_token}"})
        assert r.status_code == 401
        assert r.json()["error"]["code"] == "TOKEN_EXPIRED"

    def test_tampered_access_token_rejected(self, client):
        valid_token = create_access_token("test_sub")
        tampered_token = valid_token[:-4] + "abcd"

        r = client.get("/api/auth/me", headers={"Authorization": f"Bearer {tampered_token}"})
        assert r.status_code == 401
        assert r.json()["error"]["code"] == "TOKEN_INVALID"

    def test_alg_none_token_rejected(self, client):
        payload = {
            "sub": "hacker_sub",
            "exp": int((datetime.now(timezone.utc) + timedelta(minutes=15)).timestamp()),
            "typ": "access",
        }
        # Insecure alg=none
        none_token = jwt.encode(payload, key="", algorithm="none")

        r = client.get("/api/auth/me", headers={"Authorization": f"Bearer {none_token}"})
        assert r.status_code == 401
        assert r.json()["error"]["code"] == "TOKEN_INVALID"

    def test_refresh_token_rotation_and_reuse_detection(self, client):
        # 1. Login to get initial pair
        r_login = client.post(
            "/api/auth/login",
            json={"email": "ali@demo.pk", "password": settings.DEMO_PASSWORD},
        )
        assert r_login.status_code == 200
        tok1 = r_login.json()["refresh_token"]

        # 2. Rotate once: exchange tok1 -> tok2
        r_ref1 = client.post("/api/auth/refresh", json={"refresh_token": tok1})
        assert r_ref1.status_code == 200
        tok2 = r_ref1.json()["refresh_token"]
        assert tok2 != tok1

        # 3. REUSE ATTACK: Presenting tok1 again must revoke the entire family!
        r_reuse = client.post("/api/auth/refresh", json={"refresh_token": tok1})
        assert r_reuse.status_code == 401
        assert r_reuse.json()["error"]["code"] == "REFRESH_REUSED"

        # 4. Now tok2 must also fail because the family was revoked!
        r_tok2 = client.post("/api/auth/refresh", json={"refresh_token": tok2})
        assert r_tok2.status_code == 401
        assert r_tok2.json()["error"]["code"] == "REFRESH_REUSED"

    def test_logout_revokes_refresh_family(self, client):
        r_login = client.post(
            "/api/auth/login",
            json={"email": "ayesha@demo.pk", "password": settings.DEMO_PASSWORD},
        )
        refresh_tok = r_login.json()["refresh_token"]

        # Logout
        r_logout = client.post("/api/auth/logout", json={"refresh_token": refresh_tok})
        assert r_logout.status_code == 204

        # Refresh must now be rejected
        r_ref = client.post("/api/auth/refresh", json={"refresh_token": refresh_tok})
        assert r_ref.status_code == 401
        assert r_ref.json()["error"]["code"] == "REFRESH_REUSED"

    def test_logout_all_revokes_all_sessions_for_user(self, client):
        # Login twice (simulate 2 devices)
        r1 = client.post(
            "/api/auth/login",
            json={"email": "bilal@demo.pk", "password": settings.DEMO_PASSWORD},
        )
        r2 = client.post(
            "/api/auth/login",
            json={"email": "bilal@demo.pk", "password": settings.DEMO_PASSWORD},
        )
        tok_dev1 = r1.json()["refresh_token"]
        tok_dev2 = r2.json()["refresh_token"]
        access_tok = r2.json()["access_token"]

        # Call logout-all
        r_logout_all = client.post(
            "/api/auth/logout-all",
            headers={"Authorization": f"Bearer {access_tok}"},
        )
        assert r_logout_all.status_code == 204

        # Both refresh tokens must now be rejected
        assert client.post("/api/auth/refresh", json={"refresh_token": tok_dev1}).status_code == 401
        assert client.post("/api/auth/refresh", json={"refresh_token": tok_dev2}).status_code == 401

    def test_password_hash_is_argon2id_and_never_leaked(self, client):
        with SessionLocal() as session:
            user = session.query(User).filter_by(email="ali@demo.pk").first()
            assert user.password_hash.startswith("$argon2id$")

        # Check endpoints never include password_hash
        r = client.post(
            "/api/auth/login",
            json={"email": "ali@demo.pk", "password": settings.DEMO_PASSWORD},
        )
        assert "password_hash" not in str(r.json())
        assert "$argon2id$" not in str(r.json())

    def test_auth_enabled_false_bypass_works_without_token(self, monkeypatch):
        # Temporarily disable AUTH_ENABLED
        from app.deps import get_context
        monkeypatch.setattr(settings, "AUTH_ENABLED", False)

        with SessionLocal() as session:
            ctx = get_context(request=None, auth=None, session=session)
            assert ctx.user is not None
            assert ctx.user.email == "ali@demo.pk"
            assert ctx.role == "owner"
            assert ctx.member_code == "M01"

    def test_production_guards_refuses_to_boot_with_insecure_settings(self):
        # 1. Refuses boot if ENV=production and AUTH_ENABLED=False
        with pytest.raises(ValueError) as exc1:
            Settings(
                ENV="production",
                AUTH_ENABLED=False,
                SECRET_KEY="a" * 32,
            )
        assert "AUTH_ENABLED cannot be false" in str(exc1.value)

        # 2. Refuses boot if ENV=production and default SECRET_KEY
        with pytest.raises(ValueError) as exc2:
            Settings(
                ENV="production",
                AUTH_ENABLED=True,
                SECRET_KEY="change-me-to-a-very-secure-secret-key-at-least-32-chars-long",
            )
        assert "Default or insecure SECRET_KEY" in str(exc2.value)

    def test_rate_limiting_triggers_429(self, client, monkeypatch):
        # Enable rate limiting specifically for this test
        monkeypatch.setattr(settings, "RATE_LIMIT_ENABLED", True)
        from app.core.ratelimit import limiter
        limiter.enabled = True

        status_codes = []
        for _ in range(12):
            res = client.post(
                "/api/auth/login",
                json={"email": "rate_limit_test@test.pk", "password": "WrongPassword!"},
            )
            status_codes.append(res.status_code)

        # Reset limiter for subsequent tests
        limiter.enabled = settings.RATE_LIMIT_ENABLED

        # At least one request must have been rate-limited with 429
        assert 429 in status_codes

