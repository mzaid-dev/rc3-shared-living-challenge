from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class HouseholdCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=100)

class HouseholdJoin(BaseModel):
    model_config = ConfigDict(extra="forbid")
    invite_code: str = Field(min_length=4, max_length=32)

class HouseholdCurrentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    currency: str = "PKR"
    timezone: str = "Asia/Karachi"
    invite_code: Optional[str] = None

