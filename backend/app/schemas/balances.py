from typing import List, Literal
from pydantic import BaseModel, ConfigDict

class MemberBalanceItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    member_id: str
    name: str
    paid: float
    paid_paisa: int
    owed: float
    owed_paisa: int
    net_balance: float
    net_balance_paisa: int
    status: Literal["owes", "owed", "settled"]

class BalancesResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    household_total_spending: float
    household_total_spending_paisa: int
    members: List[MemberBalanceItem]
    is_balanced: bool

class DebtSimplificationItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    sender_id: str
    recipient_id: str
    amount: float
    amount_paisa: int

