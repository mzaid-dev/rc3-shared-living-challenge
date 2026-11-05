from typing import List, Optional
from fastapi import APIRouter, Depends, Path, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db
from app.schemas.assistant import (
    ChatRequest,
    ChatResponse,
    ConfirmRequest,
    ConfirmResponse,
    ConversationDetail,
    ConversationSummary,
)
from app.services.assistant_service import AssistantService

router = APIRouter(prefix="/api/assistant", tags=["AI Assistant"])

@router.post(
    "/chat",
    response_model=ChatResponse,
    status_code=status.HTTP_200_OK,
    summary="Send chat message to Hisab AI Assistant",
)
async def chat_with_assistant(
    payload: ChatRequest,
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    Interprets natural language inquiries using LangChain (Groq / DeepSeek / Fallback)
    and routes queries to existing financial services or generates structured mutation proposals.
    """
    return await AssistantService.chat(
        session=session,
        ctx=ctx,
        payload=payload,
    )

@router.post(
    "/confirm",
    response_model=ConfirmResponse,
    status_code=status.HTTP_200_OK,
    summary="Confirm or reject a proposed pending action",
)
def confirm_proposed_action(
    payload: ConfirmRequest,
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    Executes or cancels a pending action proposal with strict household authorization,
    expiration verification, single-use guarantees, and transactional integrity.
    """
    return AssistantService.confirm_action(
        session=session,
        ctx=ctx,
        payload=payload,
    )

@router.get(
    "/conversations",
    response_model=List[ConversationSummary],
    status_code=status.HTTP_200_OK,
    summary="List active user conversations in household",
)
def list_conversations(
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """Retrieves all conversation sessions belonging to the authenticated user in this household."""
    return AssistantService.list_conversations(
        session=session,
        ctx=ctx,
    )

@router.post(
    "/conversations",
    response_model=ConversationSummary,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new conversation session",
)
def create_conversation(
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """Creates a new isolated conversation thread for the authenticated user and household."""
    return AssistantService.create_conversation(
        session=session,
        ctx=ctx,
    )

@router.get(
    "/conversations/{conversation_id}",
    response_model=ConversationDetail,
    status_code=status.HTTP_200_OK,
    summary="Get conversation history",
)
def get_conversation_history(
    conversation_id: str = Path(..., description="UUID of the conversation"),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """Retrieves message history for a conversation, enforcing household and user ownership."""
    return AssistantService.get_conversation_detail(
        session=session,
        ctx=ctx,
        conversation_id=conversation_id,
    )

