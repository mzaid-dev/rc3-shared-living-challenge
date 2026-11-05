from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class RegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=100)

class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=1, max_length=128)

class RefreshRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    refresh_token: str = Field(min_length=10)

class LogoutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    refresh_token: str = Field(min_length=10)

class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    email: str
    display_name: str
    is_active: bool
    created_at: datetime

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = 900
    user: UserOut

class HouseholdSummary(BaseModel):
    id: str
    name: str

class MemberSummary(BaseModel):
    id: str  # Code, e.g. "M01"
    name: str
    role: str

class AuthMeResponse(BaseModel):
    user: UserOut
    household: Optional[HouseholdSummary] = None
    member: Optional[MemberSummary] = None

