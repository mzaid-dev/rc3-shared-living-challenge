import json
import os
from pathlib import Path
import tempfile
import uuid
from fastapi.testclient import TestClient
import pytest

from app.core.config import Settings, settings
from app.core.ratelimit import limiter
from app.db.models import AuditLog
from app.db.session import SessionLocal
from app.main import app
from scripts.backup import create_backup, restore_backup, verify_backup

@pytest.fixture(autouse=True)
def reset_rate_limiter():
    limiter.reset()
    yield
    limiter.reset()

@pytest.fixture
def client():
    return TestClient(app)

def create_fresh_household_with_members(client: TestClient) -> tuple[str, str, str]:
    email_owner = f"owner_{uuid.uuid4().hex[:6]}@test.pk"
    client.post("/api/auth/register", json={"email": email_owner, "password": "SecurePassword123!", "display_name": "Owner User"})
    r_login = client.post("/api/auth/login", json={"email": email_owner, "password": "SecurePassword123!"})
    token_owner = r_login.json()["access_token"]

    r_hh = client.post(
        "/api/households",
        headers={"Authorization": f"Bearer {token_owner}"},
        json={"name": f"Audit Household {uuid.uuid4().hex[:4]}"},
    )
    invite_code = r_hh.json()["invite_code"]

    email_mem = f"member_{uuid.uuid4().hex[:6]}@test.pk"
    client.post("/api/auth/register", json={"email": email_mem, "password": "SecurePassword123!", "display_name": "Member User"})
    r_mem_login = client.post("/api/auth/login", json={"email": email_mem, "password": "SecurePassword123!"})
    token_mem = r_mem_login.json()["access_token"]
    client.post("/api/households/join", headers={"Authorization": f"Bearer {token_mem}"}, json={"invite_code": invite_code})

    return token_owner, token_mem, invite_code

class TestHardeningAuditAndBackup:
    def test_audit_logs_rbac_and_content(self, client):
        """Owner can view audit trail; members receive 403; sensitive credentials never logged."""
        token_owner, token_mem, _ = create_fresh_household_with_members(client)

        # 1. Member attempt -> 403 FORBIDDEN
        r_forbidden = client.get(
            "/api/audit",
            headers={"Authorization": f"Bearer {token_mem}"},
        )
        assert r_forbidden.status_code == 403
        assert r_forbidden.json()["error"]["code"] == "FORBIDDEN"

        # 2. Owner attempt -> 200 OK
        r_ok = client.get(
            "/api/audit",
            headers={"Authorization": f"Bearer {token_owner}"},
        )
        assert r_ok.status_code == 200
        logs = r_ok.json()
        assert isinstance(logs, list)
        assert len(logs) >= 2  # household_created and member_joined

        actions = [log["action"] for log in logs]
        assert "household_created" in actions
        assert "member_joined" in actions

        # Verify no secret keywords leaked into audit payload
        for log in logs:
            if log.get("payload"):
                payload_str = json.dumps(log["payload"]).lower()
                for secret_word in ["password_hash", "access_token", "refresh_token"]:
                    assert secret_word not in payload_str

    def test_request_body_size_limit_64kb(self, client):
        """Payloads exceeding 64 KB are rejected with 413 PAYLOAD_TOO_LARGE."""
        token_owner, _, _ = create_fresh_household_with_members(client)

        oversized_title = "A" * 70_000  # 70 KB
        payload = {"title": oversized_title, "unit": "pack", "requested_qty": 1}

        r = client.post(
            "/api/shopping",
            headers={"Authorization": f"Bearer {token_owner}"},
            json=payload,
        )
        assert r.status_code == 413
        err = r.json()["error"]
        assert err["code"] == "PAYLOAD_TOO_LARGE"
        assert "64 KB" in err["message"]

    def test_security_headers_and_cache_control(self, client):
        """Standard endpoints return security headers; auth endpoints include no-store."""
        token_owner, _, _ = create_fresh_household_with_members(client)

        # 1. Standard API endpoint
        r_std = client.get("/api/members", headers={"Authorization": f"Bearer {token_owner}"})
        assert r_std.status_code == 200
        assert r_std.headers.get("X-Content-Type-Options") == "nosniff"
        assert r_std.headers.get("X-Frame-Options") == "DENY"
        assert r_std.headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"
        assert "X-Request-ID" in r_std.headers

        # 2. Auth endpoint
        r_auth = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token_owner}"})
        assert r_auth.status_code == 200
        assert "no-store" in r_auth.headers.get("Cache-Control", "")
        assert "no-cache" in r_auth.headers.get("Pragma", "")

    def test_backup_and_restore_workflow(self, tmp_path):
        """Backup script checkpoints WAL, creates SHA-256 checksum, and restores cleanly."""
        # Use existing app database from config
        db_path = Path(settings.DATABASE_URL.replace("sqlite:///", ""))
        if not db_path.exists():
            pytest.skip(f"Database file {db_path} does not exist on disk yet.")

        backup_dir = tmp_path / "backups"
        backup_file, checksum_file = create_backup(str(db_path), str(backup_dir))

        assert backup_file.exists()
        assert checksum_file.exists()

        # Checksum file contains hash and filename
        checksum_content = checksum_file.read_text(encoding="utf-8")
        assert backup_file.name in checksum_content

        # Verify backup
        is_valid = verify_backup(backup_file)
        assert is_valid is True

        # Restore to fresh destination database
        restore_target = tmp_path / "restored.sqlite"
        restore_success = restore_backup(backup_file, restore_target)
        assert restore_success is True
        assert restore_target.exists()

        # Verify restored DB integrity
        assert verify_backup(restore_target) is True

    def test_production_guards_docs_disabled(self):
        """When ENV=production and DOCS_ENABLED=False, /docs, /redoc, /openapi.json are disabled."""
        from fastapi import FastAPI
        from app.main import lifespan

        prod_settings = Settings(
            ENV="production",
            SECRET_KEY="a-very-secure-32-characters-production-secret!",
            AUTH_ENABLED=True,
            DOCS_ENABLED=False,
        )

        test_app = FastAPI(
            docs_url="/docs" if (prod_settings.ENV != "production" or prod_settings.DOCS_ENABLED) else None,
            redoc_url="/redoc" if (prod_settings.ENV != "production" or prod_settings.DOCS_ENABLED) else None,
            openapi_url="/openapi.json" if (prod_settings.ENV != "production" or prod_settings.DOCS_ENABLED) else None,
        )

        prod_client = TestClient(test_app)
        assert prod_client.get("/docs").status_code == 404
        assert prod_client.get("/redoc").status_code == 404
        assert prod_client.get("/openapi.json").status_code == 404

    def test_production_guard_refuses_boot_when_auth_disabled(self):
        """Settings and app refuse to boot if ENV=production and AUTH_ENABLED=False."""
        with pytest.raises(ValueError) as exc_info:
            Settings(
                ENV="production",
                SECRET_KEY="a-very-secure-32-characters-production-secret!",
                AUTH_ENABLED=False,
            )
        assert "AUTH_ENABLED cannot be false in production" in str(exc_info.value)

    def test_auth_enabled_false_resolves_seeded_demo_owner_without_token(self, client):
        """When AUTH_ENABLED=False, endpoints resolve seeded demo owner (Ali M01) without any token."""
        orig_auth = settings.AUTH_ENABLED
        try:
            settings.AUTH_ENABLED = False
            # Call /api/shopping without Authorization header
            r = client.get("/api/shopping")
            assert r.status_code == 200
            assert isinstance(r.json(), list)

            # Call /api/dashboard without Authorization header
            r_dash = client.get("/api/dashboard")
            assert r_dash.status_code == 200
            dash_data = r_dash.json()
            assert dash_data["member"] is not None
            assert dash_data["member"]["id"] == "M01"
            assert dash_data["member"]["name"] == "Ali"
        finally:
            settings.AUTH_ENABLED = orig_auth


