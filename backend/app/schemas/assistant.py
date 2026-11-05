from datetime import datetime
from typing import Any, Dict, List, Optional, Union
from pydantic import BaseModel, Field

class ChatRequest(BaseModel):
    conversation_id: Optional[str] = Field(None, description="Optional existing conversation ID.")
    message: str = Field(..., min_length=1, max_length=2000, description="Natural language prompt.")
    active_member_id: Optional[Union[str, int]] = Field(None, description="Contextual viewing member lens.")

class ActionPayload(BaseModel):
    action_id: str
    action_type: str  # 'create_expense', 'add_shopping_item', 'shopping_checkout', 'settle_debt'
    title: Optional[str] = None
    amount: Optional[str] = None
    currency: str = "PKR"
    payer: Optional[str] = None
    participants: Optional[List[str]] = None
    items: Optional[List[Dict[str, Any]]] = None
    details: Optional[Dict[str, Any]] = None
    confirmation_required: bool = True

class AssistantResponsePayload(BaseModel):
    type: str  # 'text', 'expense_summary', 'balance_summary', 'shopping_list', 'budget_summary', 'settlement_suggestions', 'confirmation_required', 'action_success', 'action_error', 'action_rejected'
    message: str
    action: Optional[ActionPayload] = None
    data: Optional[Any] = None

class ChatResponse(BaseModel):
    success: bool = True
    conversation_id: str
    response: AssistantResponsePayload
    requires_confirmation: bool = False

class ConfirmRequest(BaseModel):
    conversation_id: str = Field(..., description="Target conversation ID.")
    action_id: str = Field(..., description="Target pending action ID.")
    confirmed: bool = Field(True, description="True to execute the action; False to cancel/reject.")

class ConfirmResponse(BaseModel):
    success: bool
    conversation_id: str
    response: AssistantResponsePayload
    requires_confirmation: bool = False

class ConversationSummary(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    message_count: int

class ConversationMessage(BaseModel):
    id: int
    role: str
    content: str
    metadata: Optional[Dict[str, Any]] = None
    created_at: datetime

class ConversationDetail(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    messages: List[ConversationMessage]
