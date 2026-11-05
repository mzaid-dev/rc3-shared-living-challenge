from typing import Any, Dict, List
from app.domain.exceptions import LedgerImbalance

def compute_net(
    paid: Dict[Any, int],
    owed: Dict[Any, int],
    received: Dict[Any, int],
    sent: Dict[Any, int],
    member_ids: List[Any],
) -> Dict[Any, int]:
    """
    Computes net balances for all members using the financial conservation formula:
    Net = (paid - owed) + (sent - received)
    
    A debtor paying back debt increases their net toward zero (+ sent).
    A creditor receiving repayment decreases their credit toward zero (- received).
    
    Invariant:
    - Returns a mapping of member_id to net paisa.
    - Sum of net balances across the closed system is conserved.
    """
    net: Dict[Any, int] = {}
    for mid in member_ids:
        p = paid.get(mid, 0)
        o = owed.get(mid, 0)
        r = received.get(mid, 0)
        s = sent.get(mid, 0)
        net[mid] = p - o + s - r
    return net

def assert_ledger_balanced(net: Dict[Any, int]) -> None:
    """
    Asserts the fundamental ledger conservation invariant:
    The sum of all net balances in the household MUST equal zero.
    
    Raises:
    - LedgerImbalance if sum(net.values()) != 0.
    """
    total = sum(net.values())
    if total != 0:
        raise LedgerImbalance(
            f"Ledger conservation invariant violated: sum of net balances is {total} paisa (expected 0)."
        )
