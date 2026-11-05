class DomainError(Exception):
    """Base domain exception with zero external dependencies."""
    pass

class InvalidAmount(DomainError):
    """Raised when an amount is <=0, non-finite, >2 decimal places, or exceeds maximum limit."""
    pass

class DuplicateSplitMember(DomainError):
    """Raised when duplicate members are detected in an expense split."""
    pass

class SplitSumMismatch(DomainError):
    """Raised when the sum of split allocations does not match the total expense."""
    def __init__(self, expected: int, actual: int):
        self.expected = expected
        self.actual = actual
        self.difference = actual - expected
        super().__init__(
            f"Split sum mismatch: expected {expected} paisa, got {actual} paisa (difference: {self.difference} paisa)."
        )

class LedgerImbalance(DomainError):
    """Raised when the sum of net balances in a household does not equal zero."""
    pass

class SelfSettlement(DomainError):
    """Raised when a member attempts to settle debt with themselves."""
    pass

class SettleExceedsDebt(DomainError):
    """Raised when settlement amount exceeds the debtor's outstanding debt or sender is not a debtor."""
    def __init__(self, message: str, max_allowed_paisa: int = 0):
        self.max_allowed_paisa = max_allowed_paisa
        super().__init__(message)

class SettleExceedsCredit(DomainError):
    """Raised when settlement amount exceeds the creditor's outstanding credit or recipient is not a creditor."""
    def __init__(self, message: str, max_allowed_paisa: int = 0):
        self.max_allowed_paisa = max_allowed_paisa
        super().__init__(message)

