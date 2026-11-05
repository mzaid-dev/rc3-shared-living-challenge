from typing import Optional, Union
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db
from app.schemas.dashboard import DashboardResponse
from app.services.budget_service import BudgetService

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])

@router.get(
    "",
    response_model=DashboardResponse,
    status_code=status.HTTP_200_OK,
)
def get_dashboard(
    member_id: Optional[Union[str, int]] = Query(None, description="Optional member ID or code to view personalized balance"),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    Returns aggregated mobile dashboard data in a single round-trip:
    household info, active month budget, personal balance, pending shopping count, recent expenses and settlements.
    """
    return BudgetService.get_dashboard(
        session=session,
        ctx=ctx,
        member_id=member_id,
    )

