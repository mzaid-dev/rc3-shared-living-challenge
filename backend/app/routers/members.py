from typing import Any, List
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.deps import Context, get_context, get_db, require_role
from app.schemas.member import MemberCreate, MemberOfficialOut
from app.services.household_service import HouseholdService

router = APIRouter(prefix="/api/members", tags=["Members"])

@router.get(
    "",
    response_model=List[Any],
    status_code=status.HTTP_200_OK,
)
def get_members(
    detail: bool = Query(False, description="Include role and linked user flag"),
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """
    OFFICIAL ENDPOINT: Fetches household members list.
    Default response is strictly raw array of [{id: 'M01', name: 'Ali'}, ...] matching the PDF specification.
    """
    if not ctx.household_id:
        raise NotFoundError("User is not associated with any household.")

    return HouseholdService.list_members(
        session=session,
        household_id=ctx.household_id,
        detail=detail,
    )

@router.post(
    "",
    response_model=MemberOfficialOut,
    status_code=status.HTTP_201_CREATED,
)
def create_unlinked_member(
    payload: MemberCreate,
    ctx: Context = Depends(require_role("owner", "admin")),
    session: Session = Depends(get_db),
):
    """
    Creates a new household roommate without an account (unlinked member).
    Restricted to household owner and admin.
    """
    return HouseholdService.create_unlinked_member(
        session=session,
        ctx=ctx,
        name=payload.name,
    )

