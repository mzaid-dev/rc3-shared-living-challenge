from decimal import Decimal
from typing import Literal, Union
from pydantic import BaseModel, ConfigDict, Field

class BudgetSetRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    month: str = Field(..., pattern=r"^\d{4}-(0[1-9]|1[0-2])$")
    limit: Union[Decimal, float, str, int]

class BudgetSetResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    month: str
    limit: float
    limit_paisa: int

class BudgetSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    month: str
    limit: float
    limit_paisa: int
    spent: float
    spent_paisa: int
    remaining: float
    remaining_paisa: int
    percent: int
    status: Literal["on_track", "near_limit", "over_budget"]

