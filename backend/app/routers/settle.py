from typing import List, Optional, Union
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db, get_idempotency_key
from app.schemas.settle import SettlementCreate, SettlementResponse
from app.services.settlement_service import SettlementService

router = APIRouter(prefix="/api", tags=["Settlements"])

@router.post(
    "/settle",
    response_model=SettlementResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_settlement(
    payload: SettlementCreate,
    idempotency_key: Optional[str] = Depends(get_idempotency_key),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Records a debt settlement between two roommates.
    Executes atomically in ONE write transaction with net balance validation and row locks.
    """
    return SettlementService.create_settlement(
        session=session,
        ctx=ctx,
        payload=payload,
        idempotency_key=idempotency_key,
    )

@router.get(
    "/settlements",
    response_model=List[SettlementResponse],
    status_code=status.HTTP_200_OK,
)
def list_settlements(
    member_id: Optional[Union[str, int]] = Query(None, description="Filter settlements involving member as sender or recipient"),
    limit: int = Query(50, ge=1, le=100, description="Page limit"),
    offset: int = Query(0, ge=0, description="Page offset"),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    Lists household settlement history ordered newest first.
    """
    return SettlementService.list_settlements(
        session=session,
        ctx=ctx,
        member_id=member_id,
        limit=limit,
        offset=offset,
    )

