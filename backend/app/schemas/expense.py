from datetime import date
from decimal import Decimal
from typing import Any, List, Literal, Optional, Union
from pydantic import BaseModel, ConfigDict, Field, field_validator

class CustomSplitItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    member_id: Union[str, int]
    amount: Union[Decimal, float, str, int]

class ExpenseCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(..., min_length=1, max_length=200)
    category: str = Field(default="General", max_length=100)
    amount: Union[Decimal, float, str, int]
    payer_id: Union[str, int]
    split_type: Literal["equal", "custom"]
    split_members: Optional[List[Union[str, int]]] = None
    custom_splits: Optional[List[CustomSplitItem]] = None
    expense_date: Optional[date] = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        clean = v.strip()
        if not clean:
            raise ValueError("Expense title cannot be blank or whitespace.")
        return clean

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        clean = v.strip()
        return clean if clean else "General"

class ExpenseSplitResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    member_id: str
    amount: float
    amount_paisa: int

class ExpenseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    category: str
    amount: float
    amount_paisa: int
    payer_id: str
    split_type: str
    expense_date: date
    source: str
    splits: List[ExpenseSplitResponse]

