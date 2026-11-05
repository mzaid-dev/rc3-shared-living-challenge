import re
from typing import Any, Dict, List
from app.domain.exceptions import (
    DuplicateSplitMember,
    InvalidAmount,
    SplitSumMismatch,
)

def _member_numeric_sort_key(member_id: Any) -> tuple[int, Any]:
    """
    Extracts numeric sorting key so that M2 sorts before M10, 2 before 10.
    """
    if isinstance(member_id, int):
        return (0, member_id)
    s = str(member_id).strip()
    match = re.search(r"\d+", s)
    if match:
        return (1, int(match.group()))
    return (2, s)

def equal_split(total_paisa: int, member_ids: List[Any]) -> Dict[Any, int]:
    """
    Divides total_paisa equally among member_ids with deterministic remainder allocation.
    
    Invariants:
    - Rejects empty member list or duplicates (raises DuplicateSplitMember).
    - Rejects total_paisa <= 0 (raises InvalidAmount).
    - Sorts members ascending by numeric/sort_order code (e.g., M2 before M10).
    - base, rem = divmod(total, n); first `rem` members receive base + 1.
    - Invariants asserted: sum(result.values()) == total_paisa; max - min <= 1.
    """
    if not member_ids:
        raise DuplicateSplitMember("At least one member is required to split an expense.")

    if len(member_ids) != len(set(member_ids)):
        raise DuplicateSplitMember("Duplicate member detected in split list.")

    if total_paisa <= 0:
        raise InvalidAmount("Total amount to split must be greater than zero.")

    sorted_members = sorted(member_ids, key=_member_numeric_sort_key)
    n = len(sorted_members)
    base, rem = divmod(total_paisa, n)

    allocations: Dict[Any, int] = {}
    for idx, mid in enumerate(sorted_members):
        allocations[mid] = base + (1 if idx < rem else 0)

    # Invariant assertions
    assert sum(allocations.values()) == total_paisa, "Sum conservation invariant failed."
    assert (max(allocations.values()) - min(allocations.values())) <= 1, "Spread constraint failed."

    return allocations

def custom_split_validate(total_paisa: int, allocations: Dict[Any, int]) -> Dict[Any, int]:
    """
    Validates custom member allocations against the total paisa expense.
    
    Invariants:
    - Allocations dictionary cannot be empty.
    - Each member allocation must be strictly positive (> 0 paisa).
    - The sum of member allocations must exactly equal total_paisa.
    - Raises SplitSumMismatch carrying expected, actual, and difference on discrepancy.
    """
    if not allocations:
        raise SplitSumMismatch(expected=total_paisa, actual=0)

    for mid, share in allocations.items():
        if share <= 0:
            raise InvalidAmount(f"Share for member {mid} must be greater than zero.")

    actual_sum = sum(allocations.values())
    if actual_sum != total_paisa:
        raise SplitSumMismatch(expected=total_paisa, actual=actual_sum)

    return allocations
