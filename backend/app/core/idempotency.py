from datetime import datetime, timezone, timedelta
import hashlib
import json
from typing import Any, Dict, Optional, Tuple

from sqlalchemy.orm import Session

from app.core.errors import IdempotencyKeyReusedError, ValidationAppError
from app.db.models import IdempotencyKey

def compute_request_hash(payload: Any) -> str:
    """Computes a deterministic SHA-256 hash of canonical JSON."""
    if payload is None:
        canonical_bytes = b""
    elif isinstance(payload, bytes):
        canonical_bytes = payload
    elif isinstance(payload, str):
        canonical_bytes = payload.encode("utf-8")
    else:
        canonical_bytes = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(canonical_bytes).hexdigest()

def validate_idempotency_key(key: Optional[str]) -> Optional[str]:
    """Validates that optional Idempotency-Key header is 8-128 characters."""
    if key is None:
        return None
    key_clean = key.strip()
    if len(key_clean) < 8 or len(key_clean) > 128:
        raise ValidationAppError("Header 'Idempotency-Key' must be between 8 and 128 characters.")
    return key_clean

def check_idempotency(
    session: Session,
    user_id: str,
    endpoint: str,
    key: Optional[str],
    request_hash: str,
) -> Optional[Tuple[int, Dict[str, Any]]]:
    """
    Checks if an idempotent operation was already completed.
    
    Invariants:
    - If key is None: returns None (idempotency is optional).
    - If key exists with same hash within 24h: returns (status_code, response_body).
    - If key exists with different hash: raises IdempotencyKeyReusedError (409).
    - If record is older than 24h: silently deletes it and allows re-execution.
    """
    if not key:
        return None

    record = (
        session.query(IdempotencyKey)
        .filter_by(user_id=user_id, endpoint=endpoint, key=key)
        .first()
    )
    if not record:
        return None

    # Check 24-hour expiration
    now = datetime.now(timezone.utc)
    created = record.created_at
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)

    if (now - created) > timedelta(hours=24):
        session.delete(record)
        session.flush()
        return None

    if record.request_hash != request_hash:
        raise IdempotencyKeyReusedError(
            f"Idempotency key '{key}' was previously used with a different request payload."
        )

    return record.response_status, record.response_body

def record_idempotency(
    session: Session,
    user_id: str,
    endpoint: str,
    key: Optional[str],
    request_hash: str,
    response_status: int,
    response_body: Dict[str, Any],
) -> None:
    """
    Inserts idempotency record inside the active transaction.
    Commits or rolls back atomically with the business entity.
    """
    if not key:
        return

    entry = IdempotencyKey(
        user_id=user_id,
        endpoint=endpoint,
        key=key,
        request_hash=request_hash,
        response_status=response_status,
        response_body=response_body,
    )
    session.add(entry)

