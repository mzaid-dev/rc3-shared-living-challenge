from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field

from app.domain.exceptions import (
    DomainError,
    DuplicateSplitMember,
    InvalidAmount,
    LedgerImbalance,
    SelfSettlement,
    SettleExceedsCredit,
    SettleExceedsDebt,
    SplitSumMismatch,
)

class FieldError(BaseModel):
    field: str
    issue: str

class ErrorDetail(BaseModel):
    code: str
    message: str
    fields: Optional[List[FieldError]] = None

class ErrorEnvelope(BaseModel):
    error: ErrorDetail

class AppError(Exception):
    """Base application exception mapped to the uniform error contract."""
    code: str = "INTERNAL_ERROR"
    status_code: int = 500
    message: str = "An unexpected error occurred."
    fields: Optional[List[FieldError]] = None

    def __init__(
        self,
        message: Optional[str] = None,
        code: Optional[str] = None,
        status_code: Optional[int] = None,
        fields: Optional[List[FieldError]] = None,
    ):
        if message is not None:
            self.message = message
        if code is not None:
            self.code = code
        if status_code is not None:
            self.status_code = status_code
        if fields is not None:
            self.fields = fields
        super().__init__(self.message)

    def to_envelope(self) -> Dict[str, Any]:
        data: Dict[str, Any] = {
            "code": self.code,
            "message": self.message,
        }
        if self.fields:
            data["fields"] = [f.model_dump() for f in self.fields]
        return {"error": data}

# Specific Subclasses mapping to HTTP Status Codes
class ValidationAppError(AppError):
    code = "VALIDATION_ERROR"
    status_code = 422

class InvalidAmountError(AppError):
    code = "INVALID_AMOUNT"
    status_code = 422

class SplitSumMismatchError(AppError):
    code = "SPLIT_SUM_MISMATCH"
    status_code = 422

class DuplicateSplitMemberError(AppError):
    code = "DUPLICATE_SPLIT_MEMBER"
    status_code = 422

class SelfSettlementError(AppError):
    code = "SELF_SETTLEMENT"
    status_code = 422

class SettleExceedsDebtError(AppError):
    code = "SETTLE_EXCEEDS_DEBT"
    status_code = 422

class SettleExceedsCreditError(AppError):
    code = "SETTLE_EXCEEDS_CREDIT"
    status_code = 422

class NotFoundError(AppError):
    code = "NOT_FOUND"
    status_code = 404

class ItemAlreadyBoughtError(AppError):
    code = "ITEM_ALREADY_BOUGHT"
    status_code = 409

class IdempotencyKeyReusedError(AppError):
    code = "IDEMPOTENCY_KEY_REUSED"
    status_code = 409

class EmailTakenError(AppError):
    code = "EMAIL_TAKEN"
    status_code = 409

class InvalidCredentialsError(AppError):
    code = "INVALID_CREDENTIALS"
    status_code = 401

class TokenExpiredError(AppError):
    code = "TOKEN_EXPIRED"
    status_code = 401

class TokenInvalidError(AppError):
    code = "TOKEN_INVALID"
    status_code = 401

class RefreshReusedError(AppError):
    code = "REFRESH_REUSED"
    status_code = 401

class ForbiddenError(AppError):
    code = "FORBIDDEN"
    status_code = 403

class MalformedJsonError(AppError):
    code = "MALFORMED_JSON"
    status_code = 400

class RateLimitedError(AppError):
    code = "RATE_LIMITED"
    status_code = 429

class LedgerImbalanceError(AppError):
    code = "LEDGER_IMBALANCE"
    status_code = 500

class InternalError(AppError):
    code = "INTERNAL_ERROR"
    status_code = 500

def domain_to_app_error(exc: DomainError) -> AppError:
    """
    Translates pure domain layer exceptions into corresponding AppErrors in ONE central place.
    """
    if isinstance(exc, InvalidAmount):
        return InvalidAmountError(str(exc))
    elif isinstance(exc, SplitSumMismatch):
        return SplitSumMismatchError(str(exc))
    elif isinstance(exc, DuplicateSplitMember):
        return DuplicateSplitMemberError(str(exc))
    elif isinstance(exc, SelfSettlement):
        return SelfSettlementError(str(exc))
    elif isinstance(exc, SettleExceedsDebt):
        return SettleExceedsDebtError(str(exc))
    elif isinstance(exc, SettleExceedsCredit):
        return SettleExceedsCreditError(str(exc))
    elif isinstance(exc, LedgerImbalance):
        return LedgerImbalanceError(str(exc))
    else:
        return InternalError(str(exc))
