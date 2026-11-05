from datetime import datetime
from typing import Any, Dict, Optional
from pydantic import BaseModel, ConfigDict

class AuditLogItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    action: str
    entity_type: str
    entity_id: str
    user_id: Optional[str] = None
    payload: Optional[Dict[str, Any]] = None
    created_at: datetime

