import datetime
from typing import Optional
import uuid
from fastapi import APIRouter, Depends, Header
from fastapi.testclient import TestClient
from pydantic import BaseModel, Field
import pytest

from app.core.errors import AppError, NotFoundError
from app.core.idempotency import (
    check_idempotency,
    compute_request_hash,
    record_idempotency,
    validate_idempotency_key,
)
from app.db.models import IdempotencyKey
from app.db.session import SessionLocal, unit_of_work
from app.domain.exceptions import (
    InvalidAmount,
    LedgerImbalance,
    SelfSettlement,
    SettleExceedsCredit,
    SettleExceedsDebt,
    SplitSumMismatch,
)
from app.main import app

# Test router to exercise plumbing
test_router = APIRouter(prefix="/test-plumbing", tags=["testing"])

class SamplePayload(BaseModel):
    name: str = Field(min_length=2)
    amount: int = Field(gt=0)

@test_router.post("/validation")
def endpoint_validation(payload: SamplePayload):
    return {"status": "ok", "received": payload.model_dump()}

@test_router.get("/not-found")
def endpoint_not_found():
    raise NotFoundError("The requested entity does not exist.")

@test_router.get("/unhandled-500")
def endpoint_unhandled_500():
    raise RuntimeError("Sensitive internal database connection string: postgres://user:secret@db/prod")

@test_router.get("/domain-error/{error_type}")
def endpoint_domain_error(error_type: str):
    if error_type == "invalid-amount":
        raise InvalidAmount("Invalid monetary amount.")
    elif error_type == "split-mismatch":
        raise SplitSumMismatch(expected=1000, actual=990)
    elif error_type == "self-settlement":
        raise SelfSettlement("Cannot settle debt with oneself.")
    elif error_type == "exceeds-debt":
        raise SettleExceedsDebt("Settlement amount exceeds debt.")
    elif error_type == "exceeds-credit":
        raise SettleExceedsCredit("Settlement amount exceeds credit.")
    elif error_type == "ledger-imbalance":
        raise LedgerImbalance("Ledger conservation broken.")
    return {"status": "ok"}

@test_router.post("/idempotent-action")
def endpoint_idempotent_action(
    payload: SamplePayload,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    key = validate_idempotency_key(idempotency_key)
    body_dict = payload.model_dump()
    req_hash = compute_request_hash(body_dict)
    
    with SessionLocal() as session:
        from app.db.models import User
        user = session.query(User).filter_by(email="ali@demo.pk").first()
        user_id = user.id if user else "test_user_fallback"
        endpoint = "/test-plumbing/idempotent-action"

        # Check idempotency
        cached = check_idempotency(session, user_id, endpoint, key, req_hash)
        if cached:
            status_code, response_data = cached
            from fastapi.responses import JSONResponse
            res = JSONResponse(status_code=status_code, content=response_data)
            res.headers["Idempotent-Replay"] = "true"
            return res

    with unit_of_work(write=True) as session:
        # Business logic: return response and record idempotency atomically
        response_data = {"status": "created", "item_id": 999, "name": payload.name}
        status_code = 201
        record_idempotency(session, user_id, endpoint, key, req_hash, status_code, response_data)

    from fastapi.responses import JSONResponse
    return JSONResponse(status_code=status_code, content=response_data)

app.include_router(test_router)

class TestPlumbingAndEnvelope:
    def test_request_id_generation_and_propagation(self):
        client = TestClient(app)
        
        # 1. Auto-generated when absent
        r1 = client.get("/health")
        assert "X-Request-ID" in r1.headers
        assert len(r1.headers["X-Request-ID"]) > 10

        # 2. Propagated when supplied by caller
        custom_id = "custom-client-trace-12345"
        r2 = client.get("/health", headers={"X-Request-ID": custom_id})
        assert r2.headers["X-Request-ID"] == custom_id

    def test_uniform_envelope_422_validation_error(self):
        client = TestClient(app)
        # Missing required amount, name too short
        r = client.post("/test-plumbing/validation", json={"name": "a"})
        assert r.status_code == 422
        body = r.json()
        assert "error" in body
        err = body["error"]
        assert err["code"] == "VALIDATION_ERROR"
        assert "fields" in err
        fields = [f["field"] for f in err["fields"]]
        assert any("name" in f for f in fields)
        assert any("amount" in f for f in fields)

    def test_uniform_envelope_404_not_found(self):
        client = TestClient(app)
        r = client.get("/test-plumbing/not-found")
        assert r.status_code == 404
        body = r.json()
        assert body["error"]["code"] == "NOT_FOUND"
        assert body["error"]["message"] == "The requested entity does not exist."

    def test_uniform_envelope_400_malformed_json(self):
        client = TestClient(app)
        r = client.post(
            "/test-plumbing/validation",
            content="{'invalid': json,}",
            headers={"Content-Type": "application/json"},
        )
        assert r.status_code == 400
        body = r.json()
        assert body["error"]["code"] == "MALFORMED_JSON"

    def test_uniform_envelope_500_never_leaks_traceback(self):
        client = TestClient(app, raise_server_exceptions=False)
        r = client.get("/test-plumbing/unhandled-500")
        assert r.status_code == 500
        body = r.json()
        assert body["error"]["code"] == "INTERNAL_ERROR"
        assert body["error"]["message"] == "An internal server error occurred."
        # Verify secret DB string is NEVER leaked to client
        assert "postgres://" not in str(body)

    def test_domain_exception_translation_to_envelope(self):
        client = TestClient(app)
        
        # 1. InvalidAmount -> 422 INVALID_AMOUNT
        r1 = client.get("/test-plumbing/domain-error/invalid-amount")
        assert r1.status_code == 422
        assert r1.json()["error"]["code"] == "INVALID_AMOUNT"

        # 2. SplitSumMismatch -> 422 SPLIT_SUM_MISMATCH
        r2 = client.get("/test-plumbing/domain-error/split-mismatch")
        assert r2.status_code == 422
        assert r2.json()["error"]["code"] == "SPLIT_SUM_MISMATCH"

        # 3. SelfSettlement -> 422 SELF_SETTLEMENT
        r3 = client.get("/test-plumbing/domain-error/self-settlement")
        assert r3.status_code == 422
        assert r3.json()["error"]["code"] == "SELF_SETTLEMENT"

        # 4. SettleExceedsDebt -> 422 SETTLE_EXCEEDS_DEBT
        r4 = client.get("/test-plumbing/domain-error/exceeds-debt")
        assert r4.status_code == 422
        assert r4.json()["error"]["code"] == "SETTLE_EXCEEDS_DEBT"

        # 5. SettleExceedsCredit -> 422 SETTLE_EXCEEDS_CREDIT
        r5 = client.get("/test-plumbing/domain-error/exceeds-credit")
        assert r5.status_code == 422
        assert r5.json()["error"]["code"] == "SETTLE_EXCEEDS_CREDIT"

        # 6. LedgerImbalance -> 500 LEDGER_IMBALANCE
        r6 = client.get("/test-plumbing/domain-error/ledger-imbalance")
        assert r6.status_code == 500
        assert r6.json()["error"]["code"] == "LEDGER_IMBALANCE"

    def test_idempotency_workflow(self):
        client = TestClient(app)
        valid_key = f"idemp-key-{uuid.uuid4()}"
        payload = {"name": "Test Item", "amount": 100}

        # 1. First execution -> creates resource (201)
        r1 = client.post(
            "/test-plumbing/idempotent-action",
            json=payload,
            headers={"Idempotency-Key": valid_key},
        )
        assert r1.status_code == 201
        assert "Idempotent-Replay" not in r1.headers
        assert r1.json()["item_id"] == 999

        # Verify exactly one row in DB
        with SessionLocal() as session:
            count = session.query(IdempotencyKey).filter_by(key=valid_key).count()
            assert count == 1

        # 2. Replay with identical body -> returns cached response (201) with Idempotent-Replay header
        r2 = client.post(
            "/test-plumbing/idempotent-action",
            json=payload,
            headers={"Idempotency-Key": valid_key},
        )
        assert r2.status_code == 201
        assert r2.headers.get("Idempotent-Replay") == "true"
        assert r2.json() == r1.json()

        # Verify still only 1 row in DB
        with SessionLocal() as session:
            count = session.query(IdempotencyKey).filter_by(key=valid_key).count()
            assert count == 1

        # 3. Same key with DIFFERENT payload -> 409 IDEMPOTENCY_KEY_REUSED
        different_payload = {"name": "Test Item Mutated", "amount": 200}
        r3 = client.post(
            "/test-plumbing/idempotent-action",
            json=different_payload,
            headers={"Idempotency-Key": valid_key},
        )
        assert r3.status_code == 409
        assert r3.json()["error"]["code"] == "IDEMPOTENCY_KEY_REUSED"

    def test_idempotency_key_length_validation(self):
        client = TestClient(app)
        
        # Too short (< 8 chars)
        r1 = client.post(
            "/test-plumbing/idempotent-action",
            json={"name": "Item", "amount": 50},
            headers={"Idempotency-Key": "short"},
        )
        assert r1.status_code == 422
        assert "between 8 and 128" in r1.json()["error"]["message"]

        # Too long (> 128 chars)
        r2 = client.post(
            "/test-plumbing/idempotent-action",
            json={"name": "Item", "amount": 50},
            headers={"Idempotency-Key": "k" * 129},
        )
        assert r2.status_code == 422
        assert "between 8 and 128" in r2.json()["error"]["message"]
