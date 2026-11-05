from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict

from app.schemas.expense import ExpenseResponse
from app.schemas.settle import SettlementResponse

class DashboardHousehold(BaseModel):
    id: str
    name: str
    currency: str

class DashboardBudget(BaseModel):
    limit: float
    limit_paisa: int
    spent: float
    spent_paisa: int
    remaining: float
    remaining_paisa: int
    percent: int
    status: str

class DashboardMyBalance(BaseModel):
    paid: float
    paid_paisa: int
    owed: float
    owed_paisa: int
    net_balance: float
    net_balance_paisa: int
    status: str

class DashboardMember(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="allow")

    id: str
    name: str
    net_balance: float
    net_balance_paisa: int
    message: str

class DashboardResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="allow")

    # Contract exact fields
    month: str
    spent: float
    spent_paisa: int
    limit: float
    limit_paisa: int
    remaining: float
    remaining_paisa: int
    percent: int
    status: str
    member: Optional[DashboardMember] = None
    pending_items_count: int

    # Extra backward-compatible fields
    household: Optional[DashboardHousehold] = None
    active_month: Optional[str] = None
    budget: Optional[DashboardBudget] = None
    my_balance: Optional[DashboardMyBalance] = None
    pending_shopping_count: Optional[int] = None
    recent_expenses: Optional[List[ExpenseResponse]] = None
    recent_settlements: Optional[List[SettlementResponse]] = None
