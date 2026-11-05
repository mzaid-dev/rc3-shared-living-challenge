from datetime import date
from decimal import Decimal
from typing import Any, List, Union
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.expense import ExpenseSplitResponse

class CheckoutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    item_ids: List[int] = Field(..., min_length=1, max_length=100)
    total_paid: Union[Decimal, float, str, int]
    payer_id: Union[str, int]
    split_members: List[Union[str, int]] = Field(..., min_length=1, max_length=50)

    @field_validator("item_ids")
    @classmethod
    def validate_item_ids(cls, v: List[int]) -> List[int]:
        if not v:
            raise ValueError("item_ids cannot be empty.")
        if len(v) != len(set(v)):
            raise ValueError("Duplicate item IDs in checkout request.")
        return v

    @field_validator("split_members")
    @classmethod
    def validate_split_members(cls, v: List[Union[str, int]]) -> List[Union[str, int]]:
        if not v:
            raise ValueError("split_members cannot be empty.")
        if len(v) != len(set(v)):
            raise ValueError("Duplicate members in split_members list.")
        return v

class CheckoutItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    status: str

class CheckoutResponse(BaseModel):
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
    items: List[CheckoutItemOut]

