from datetime import date
from typing import List, Optional, Union
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db, get_idempotency_key
from app.schemas.expense import ExpenseCreate, ExpenseResponse
from app.services.expense_service import ExpenseService

router = APIRouter(prefix="/api/expenses", tags=["Expenses"])

@router.post(
    "",
    response_model=ExpenseResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_expense(
    payload: ExpenseCreate,
    idempotency_key: Optional[str] = Depends(get_idempotency_key),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Records a shared expense with equal or custom splits.
    All operations execute atomically inside one transaction (BEGIN IMMEDIATE).
    """
    return ExpenseService.create_expense(
        session=session,
        ctx=ctx,
        payload=payload,
        idempotency_key=idempotency_key,
    )

@router.get(
    "",
    response_model=List[ExpenseResponse],
    status_code=status.HTTP_200_OK,
)
def list_expenses(
    member_id: Optional[Union[str, int]] = Query(None, description="Filter expenses involving member as payer or split participant"),
    from_date: Optional[date] = Query(None, description="Start date (inclusive, YYYY-MM-DD)"),
    to_date: Optional[date] = Query(None, description="End date (inclusive, YYYY-MM-DD)"),
    category: Optional[str] = Query(None, description="Filter by expense category"),
    limit: int = Query(50, ge=1, le=100, description="Page size limit"),
    offset: int = Query(0, ge=0, description="Page offset"),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    Lists household expenses ordered newest first, with eager-loaded splits.
    """
    return ExpenseService.list_expenses(
        session=session,
        ctx=ctx,
        member_id=member_id,
        from_date=from_date,
        to_date=to_date,
        category=category,
        limit=limit,
        offset=offset,
    )

