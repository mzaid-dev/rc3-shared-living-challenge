from datetime import datetime
from decimal import Decimal
from typing import Union
from pydantic import BaseModel, ConfigDict

class SettlementCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    sender_id: Union[str, int]
    recipient_id: Union[str, int]
    amount: Union[Decimal, float, str, int]

class SettlementResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender_id: str
    recipient_id: str
    amount: float
    amount_paisa: int
    created_at: datetime

