from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db, require_role
from app.schemas.budget import BudgetSetRequest, BudgetSetResponse, BudgetSummaryResponse
from app.services.budget_service import BudgetService

router = APIRouter(prefix="/api/budget", tags=["Budget"])

@router.put(
    "",
    response_model=BudgetSetResponse,
    status_code=status.HTTP_200_OK,
)
def set_monthly_budget(
    payload: BudgetSetRequest,
    ctx: Context = Depends(require_role("owner", "admin")),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Sets or updates the monthly budget limit.
    Restricted to household owner and admin.
    """
    return BudgetService.set_budget(
        session=session,
        ctx=ctx,
        payload=payload,
    )

@router.get(
    "/summary",
    response_model=BudgetSummaryResponse,
    status_code=status.HTTP_200_OK,
)
def get_budget_summary(
    month: Optional[str] = Query(None, pattern=r"^\d{4}-(0[1-9]|1[0-2])$", description="Calendar month (YYYY-MM)"),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    Returns monthly budget limit, spending to date, remaining balance, and threshold status.
    """
    return BudgetService.get_budget_summary(
        session=session,
        ctx=ctx,
        month=month,
    )

