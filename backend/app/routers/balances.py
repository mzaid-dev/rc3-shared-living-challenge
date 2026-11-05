from typing import List, Optional, Union
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db
from app.schemas.balances import BalancesResponse, DebtSimplificationItem
from app.services.balance_service import BalanceService

router = APIRouter(prefix="/api/balances", tags=["Balances"])

@router.get(
    "",
    response_model=BalancesResponse,
    status_code=status.HTTP_200_OK,
)
def get_household_balances(
    member_id: Optional[Union[str, int]] = Query(None, description="Optional member ID or code to view specific member balance"),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Returns household total spending and current net balances for every member.
    If member_id is provided, returns that member's balance after verifying household authorization.
    Enforces exact zero-sum ledger conservation.
    """
    return BalanceService.get_household_balances(
        session=session,
        ctx=ctx,
        member_id=member_id,
    )

@router.get(
    "/simplify",
    response_model=List[DebtSimplificationItem],
    status_code=status.HTTP_200_OK,
)
def simplify_debts(
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    SURPRISE TASK ENDPOINT: Generates optimized settlement suggestions that minimize
    the total number of debt-settlement transactions needed to clear all household balances.
    """
    return BalanceService.simplify_household_debts(session=session, ctx=ctx)
