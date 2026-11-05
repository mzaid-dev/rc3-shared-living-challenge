from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator

ALLOWED_UNITS = {"pack", "dozen", "bottle", "bag"}

class ShoppingItemCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(..., min_length=1, max_length=100)
    unit: str = Field(..., min_length=1, max_length=50)
    requested_qty: int = Field(..., ge=1, le=1000)

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        clean = v.strip()
        if not clean:
            raise ValueError("Item title cannot be blank or whitespace.")
        return clean

    @field_validator("unit")
    @classmethod
    def validate_unit(cls, v: str) -> str:
        clean = v.strip().lower()
        if clean not in ALLOWED_UNITS:
            allowed_list = sorted(list(ALLOWED_UNITS))
            raise ValueError(f"Invalid unit '{v}'. Allowed units: {allowed_list}")
        return clean

class ShoppingItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    unit: str
    requested_qty: int
    status: str

