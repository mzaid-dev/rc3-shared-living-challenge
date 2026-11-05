from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.config import settings

def email_or_ip_key(request: Request) -> str:
    """Combines client IP and optional request email for targeted rate-limiting."""
    ip = get_remote_address(request)
    return ip

limiter = Limiter(
    key_func=email_or_ip_key,
    enabled=settings.RATE_LIMIT_ENABLED,
    default_limits=[settings.RATE_LIMIT_DEFAULT],
)

