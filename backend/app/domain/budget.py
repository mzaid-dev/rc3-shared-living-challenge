import math
from typing import Any, Dict

def budget_status(spent_paisa: int, limit_paisa: int) -> Dict[str, Any]:
    """
    Computes budget utilization percentage, remaining balance, and status.
    
    Invariants & Rules:
    - percent = floor(spent_paisa * 100 / limit_paisa).
    - remaining_paisa = limit_paisa - spent_paisa (may be negative).
    - status:
        * 'on_track' if percent < 80
        * 'near_limit' if 80 <= percent < 100
        * 'over_budget' if percent >= 100
    - limit_paisa <= 0 handled safely.
    """
    remaining = limit_paisa - spent_paisa

    if limit_paisa <= 0:
        percent = 100 if spent_paisa > 0 else 0
        status = "over_budget" if spent_paisa > 0 else "on_track"
    else:
        percent = math.floor(spent_paisa * 100 / limit_paisa)
        if percent < 80:
            status = "on_track"
        elif percent < 100:
            status = "near_limit"
        else:
            status = "over_budget"

    return {
        "percent": percent,
        "remaining_paisa": remaining,
        "status": status,
    }
