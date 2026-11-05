"""
DEFINITIONS:
authentication = who you are (tokens);
authorization = what you may do (household membership + role).
"""

from datetime import datetime, timedelta, timezone
import hashlib
import secrets
from typing import Any, Dict, Optional
import uuid

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
import jwt

from app.core.config import settings
from app.core.errors import (
    TokenExpiredError,
    TokenInvalidError,
    ValidationAppError,
)

ph = PasswordHasher()
# Pre-computed dummy hash to guarantee constant-time verification for non-existent users
DUMMY_HASH = ph.hash("timing_attack_mitigation_passphrase_2026")

def hash_password(password: str) -> str:
    """Hashes a plaintext password using Argon2id."""
    return ph.hash(password)

def verify_password(stored_hash: str, password: str) -> bool:
    """Verifies a password against an Argon2id hash."""
    try:
        return ph.verify(stored_hash, password)
    except (VerifyMismatchError, Exception):
        return False

def dummy_verify(password: str) -> None:
    """Executes a dummy verification to prevent timing attacks on unknown emails."""
    try:
        ph.verify(DUMMY_HASH, password)
    except Exception:
        pass

def validate_password_policy(password: str, email: str) -> None:
    """
    Enforces password complexity rules:
    - 8 to 128 characters.
    - Password must not equal email.
    """
    if len(password) < 8 or len(password) > 128:
        raise ValidationAppError("Password must be between 8 and 128 characters.")
    if password.strip().lower() == email.strip().lower():
        raise ValidationAppError("Password cannot be identical to email address.")

def create_access_token(user_id: str) -> str:
    """
    Generates an HS256 signed JWT access token.
    Claims: sub=user_id, iat, exp (15 min), jti, typ='access'.
    """
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=settings.ACCESS_TOKEN_MINUTES)
    payload = {
        "sub": user_id,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "jti": str(uuid.uuid4()),
        "typ": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

def decode_access_token(token: str) -> Dict[str, Any]:
    """
    Decodes and validates a JWT access token.
    Rejects 'none' or unapproved algorithms, expired tokens, and wrong token types.
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
            options={"require": ["sub", "exp", "typ"]},
        )
    except jwt.ExpiredSignatureError:
        raise TokenExpiredError("Access token has expired.")
    except jwt.PyJWTError:
        raise TokenInvalidError("Invalid or tampered access token.")

    if payload.get("typ") != "access":
        raise TokenInvalidError("Invalid token type: expected access token.")

    return payload

def generate_refresh_token() -> str:
    """Generates a secure 256-bit random opaque refresh token."""
    return secrets.token_urlsafe(32)

def hash_refresh_token(token: str) -> str:
    """Computes SHA-256 hash of opaque refresh token for persistent storage."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
