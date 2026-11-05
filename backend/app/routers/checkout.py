from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db, get_idempotency_key
from app.schemas.checkout import CheckoutRequest, CheckoutResponse
from app.services.checkout_service import CheckoutService

router = APIRouter(prefix="/api/shopping", tags=["Shopping"])

@router.post(
    "/checkout",
    response_model=CheckoutResponse,
    status_code=status.HTTP_201_CREATED,
)
def checkout_shopping_items(
    payload: CheckoutRequest,
    idempotency_key: str = Depends(get_idempotency_key),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Atomically converts pending shopping items into an expense.
    Executes in ONE transaction (BEGIN IMMEDIATE) with CAS verification and unique constraint backstop.
    """
    return CheckoutService.checkout(
        session=session,
        ctx=ctx,
        payload=payload,
        idempotency_key=idempotency_key,
    )

