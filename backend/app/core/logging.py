import json
import logging
import re
from typing import Any, Dict

SENSITIVE_PATTERNS = [
    re.compile(r'"password":\s*"[^"]*"', re.IGNORECASE),
    re.compile(r'"password_hash":\s*"[^"]*"', re.IGNORECASE),
    re.compile(r'"token":\s*"[^"]*"', re.IGNORECASE),
    re.compile(r'"access_token":\s*"[^"]*"', re.IGNORECASE),
    re.compile(r'"refresh_token":\s*"[^"]*"', re.IGNORECASE),
    re.compile(r'"authorization":\s*"[^"]*"', re.IGNORECASE),
]

class SensitiveDataRedactor(logging.Filter):
    """
    Log filter that scrubs credentials, tokens, and authorization headers
    from all log records.
    """
    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.msg, str):
            msg = record.msg
            for pattern in SENSITIVE_PATTERNS:
                msg = pattern.sub('"***REDACTED***"', msg)
            record.msg = msg
        return True

def setup_logging() -> logging.Logger:
    logger = logging.getLogger("rc3_shared_living")
    logger.setLevel(logging.INFO)
    
    if not logger.handlers:
        handler = logging.StreamHandler()
        formatter = logging.Formatter(
            '{"timestamp":"%(asctime)s", "level":"%(levelname)s", "logger":"%(name)s", "message":"%(message)s"}'
        )
        handler.setFormatter(formatter)
        handler.addFilter(SensitiveDataRedactor())
        logger.addHandler(handler)
        
    return logger

logger = setup_logging()

