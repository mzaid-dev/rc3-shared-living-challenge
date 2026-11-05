from typing import Any, Dict
from app.domain.exceptions import (
    InvalidAmount,
    SelfSettlement,
    SettleExceedsCredit,
    SettleExceedsDebt,
)
from app.domain.money import format_pkr

def validate_settlement(
    net: Dict[Any, int],
    sender: Any,
    recipient: Any,
    amount_paisa: int,
) -> None:
    """
    Validates a debt settlement transfer between two members against the current net balance sheet.
    
    Model: Net-based (not pairwise).
    
    Invariants & Rules:
    - amount_paisa must be strictly positive (> 0).
    - sender != recipient (cannot settle debt with oneself).
    - sender must be a debtor (net[sender] < 0); amount cannot exceed -net[sender].
    - recipient must be a creditor (net[recipient] > 0); amount cannot exceed net[recipient].
    - Exception messages explicitly include the max allowed amount in PKR.
    """
    if amount_paisa <= 0:
        raise InvalidAmount("Settlement amount must be greater than zero.")

    if sender == recipient:
        raise SelfSettlement("Cannot settle debt with oneself.")

    sender_net = net.get(sender, 0)
    if sender_net >= 0:
        raise SettleExceedsDebt(
            f"Member {sender} is not a debtor (net balance: {format_pkr(sender_net)} PKR). Max allowed settlement is 0.00 PKR.",
            max_allowed_paisa=0,
        )

    max_debt_paisa = -sender_net
    if amount_paisa > max_debt_paisa:
        max_debt_pkr = format_pkr(max_debt_paisa)
        raise SettleExceedsDebt(
            f"Settlement amount ({format_pkr(amount_paisa)} PKR) exceeds member {sender}'s debt ({max_debt_pkr} PKR). Max allowed is {max_debt_pkr} PKR.",
            max_allowed_paisa=max_debt_paisa,
        )

    recipient_net = net.get(recipient, 0)
    if recipient_net <= 0:
        raise SettleExceedsCredit(
            f"Member {recipient} is not a creditor (net balance: {format_pkr(recipient_net)} PKR). Max allowed settlement is 0.00 PKR.",
            max_allowed_paisa=0,
        )

    max_credit_paisa = recipient_net
    if amount_paisa > max_credit_paisa:
        max_credit_pkr = format_pkr(max_credit_paisa)
        raise SettleExceedsCredit(
            f"Settlement amount ({format_pkr(amount_paisa)} PKR) exceeds member {recipient}'s credit ({max_credit_pkr} PKR). Max allowed is {max_credit_pkr} PKR.",
            max_allowed_paisa=max_credit_paisa,
        )

def simplify_debts(net: Dict[Any, int]) -> list[Dict[str, Any]]:
    """
    Minimizes the number of settlement cash transactions among members using a greedy matching algorithm.
    
    Given a net balance dictionary where positive amounts are owed to creditors
    and negative amounts are owed by debtors (with sum(net.values()) == 0):
    
    Returns a minimal list of transactions:
    [{"sender": debtor, "recipient": creditor, "amount_paisa": amount}, ...]
    
    Guarantees:
    - Pure in-memory domain function (no DB or external calls).
    - Preserves exact integer paisa arithmetic.
    - Zero net remainder.
    """
    debtors: list[list[Any]] = []
    creditors: list[list[Any]] = []

    for member, balance in net.items():
        if balance < 0:
            debtors.append([member, -balance])
        elif balance > 0:
            creditors.append([member, balance])

    # Deterministic sorting: sort by amount descending, then by numeric member key
    from app.domain.split import _member_numeric_sort_key
    debtors.sort(key=lambda x: (-x[1], _member_numeric_sort_key(x[0])))
    creditors.sort(key=lambda x: (-x[1], _member_numeric_sort_key(x[0])))

    transactions: list[Dict[str, Any]] = []
    d_idx = 0
    c_idx = 0

    while d_idx < len(debtors) and c_idx < len(creditors):
        debtor, debt = debtors[d_idx]
        creditor, credit = creditors[c_idx]

        settle_amt = min(debt, credit)
        if settle_amt > 0:
            transactions.append({
                "sender": debtor,
                "recipient": creditor,
                "amount_paisa": settle_amt,
            })

        debtors[d_idx][1] -= settle_amt
        creditors[c_idx][1] -= settle_amt

        if debtors[d_idx][1] == 0:
            d_idx += 1
        if creditors[c_idx][1] == 0:
            c_idx += 1

    return transactions

