from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.deps import Context, get_context, get_db, get_idempotency_key
from app.schemas.shopping import ShoppingItemCreate, ShoppingItemResponse
from app.services.shopping_service import ShoppingService

router = APIRouter(prefix="/api/shopping", tags=["Shopping"])

@router.get(
    "",
    response_model=List[ShoppingItemResponse],
    status_code=status.HTTP_200_OK,
)
def get_shopping_items(
    status: Optional[str] = Query(None, description="Filter items by status ('pending' or 'bought')"),
    include_bought: Optional[bool] = Query(None, description="Include bought items if true"),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Fetches shopping list items for current household, newest first.
    Returns raw array of [{id, title, unit, requested_qty, status}].
    """
    return ShoppingService.list_shopping_items(
        session=session,
        ctx=ctx,
        status=status,
        include_bought=include_bought,
    )

@router.post(
    "",
    response_model=ShoppingItemResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_shopping_item(
    payload: ShoppingItemCreate,
    idempotency_key: Optional[str] = Depends(get_idempotency_key),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Adds a new shopping list item to the household.
    Extra fields (e.g. status) are strictly forbidden to prevent mass-assignment.
    """
    return ShoppingService.create_shopping_item(
        session=session,
        ctx=ctx,
        payload=payload,
        idempotency_key=idempotency_key,
    )

