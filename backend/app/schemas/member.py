from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class MemberOfficialOut(BaseModel):
    """Official PDF format for GET /api/members."""
    model_config = ConfigDict(from_attributes=True)
    id: str  # Code e.g. "M01"
    name: str

class MemberDetailOut(BaseModel):
    """Extended format when ?detail=true is requested."""
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    role: str
    linked: bool

class MemberCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=100)

