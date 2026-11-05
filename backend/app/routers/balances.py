from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db
from app.schemas.balances import BalancesResponse
from app.services.balance_service import BalanceService

router = APIRouter(prefix="/api/balances", tags=["Balances"])

@router.get(
    "",
    response_model=BalancesResponse,
    status_code=status.HTTP_200_OK,
)
def get_household_balances(
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Returns household total spending and current net balances for every member.
    Enforces exact zero-sum ledger conservation.
    """
    return BalanceService.get_household_balances(session=session, ctx=ctx)

