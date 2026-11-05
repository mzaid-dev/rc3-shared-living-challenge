from decimal import Decimal, InvalidOperation
from typing import Union
from app.domain.exceptions import InvalidAmount

MAX_AMOUNT_PKR = Decimal("10000000.00")
PAISA_FACTOR = Decimal("100")
TWO_DP = Decimal("0.01")

def parse_pkr(value: Union[int, str, Decimal, float]) -> int:
    """
    Parses an input value into an exact integer paisa amount.
    
    Invariants & Rules:
    - Uses Decimal(str(value)) for precision.
    - Rejects non-finite values (NaN, Inf).
    - Rejects amounts <= 0.
    - Rejects values with > 2 decimal places.
    - Rejects amounts > 10,000,000.00 PKR.
    - Returns exact integer paisa.
    """
    if value is None:
        raise InvalidAmount("Amount is required.")

    try:
        val_str = str(value).strip()
        dec = Decimal(val_str)
    except (InvalidOperation, ValueError, TypeError):
        raise InvalidAmount("Invalid monetary format.")

    if not dec.is_finite():
        raise InvalidAmount("Amount must be a finite number.")

    if dec <= Decimal("0"):
        raise InvalidAmount("Amount must be greater than zero.")

    if dec > MAX_AMOUNT_PKR:
        raise InvalidAmount("Amount exceeds maximum allowed limit of 10,000,000.00 PKR.")

    exponent = dec.as_tuple().exponent
    if isinstance(exponent, int) and exponent < -2:
        raise InvalidAmount("Amount cannot have more than 2 decimal places.")

    return int(dec * PAISA_FACTOR)

def format_pkr(paisa: int) -> Decimal:
    """
    Formats integer paisa into a Decimal quantized to 2 decimal places (for display only).
    
    Invariant:
    - paisa is an integer.
    - Output is strictly quantized to 2 decimal places.
    """
    return (Decimal(paisa) / PAISA_FACTOR).quantize(TWO_DP)
