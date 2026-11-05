from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.orm import Session

from app.core.ratelimit import limiter
from app.db.models import User
from app.deps import Context, get_context, get_current_user, get_db, require_role
from app.schemas.household import (
    HouseholdCreate,
    HouseholdCurrentResponse,
    HouseholdJoin,
)
from app.services.household_service import HouseholdService

router = APIRouter(prefix="/api/households", tags=["Households"])

@router.post(
    "",
    response_model=HouseholdCurrentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_household(
    payload: HouseholdCreate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_db),
):
    """Creates a new household and appoints the caller as owner (M01)."""
    return HouseholdService.create_household(
        session=session,
        user=current_user,
        name=payload.name,
    )

@router.post(
    "/join",
    response_model=HouseholdCurrentResponse,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("10/minute")
def join_household(
    request: Request,
    payload: HouseholdJoin,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_db),
):
    """Joins an existing household using an invite code."""
    return HouseholdService.join_household(
        session=session,
        user=current_user,
        invite_code=payload.invite_code,
    )

@router.get(
    "/current",
    response_model=HouseholdCurrentResponse,
    status_code=status.HTTP_200_OK,
)
def get_current_household(
    ctx: Context = Depends(get_context),
    session: Session = Depends(get_db),
):
    """Fetches details of the active household. Invite code is only exposed to owner/admin."""
    return HouseholdService.get_current_household(
        session=session,
        ctx=ctx,
    )

@router.post(
    "/current/invite-code",
    response_model=HouseholdCurrentResponse,
    status_code=status.HTTP_200_OK,
)
def rotate_invite_code(
    ctx: Context = Depends(require_role("owner", "admin")),
    session: Session = Depends(get_db),
):
    """Rotates the household invite code. Restricted to owner and admin."""
    return HouseholdService.rotate_invite_code(
        session=session,
        ctx=ctx,
    )

