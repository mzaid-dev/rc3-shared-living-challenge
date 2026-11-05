from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.orm import Session

from app.core.ratelimit import limiter
from app.deps import get_current_user, get_db
from app.db.models import User
from app.schemas.auth import (
    AuthMeResponse,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserOut,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

@router.post(
    "/register",
    response_model=UserOut,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("10/minute")
def register_user(
    request: Request,
    payload: RegisterRequest,
    session: Session = Depends(get_db),
):
    """Registers a new user account. Does not create a household."""
    return AuthService.register(
        session=session,
        email=payload.email,
        password=payload.password,
        display_name=payload.display_name,
    )

@router.post(
    "/login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
@limiter.limit("10/minute")
def login_user(
    request: Request,
    payload: LoginRequest,
    session: Session = Depends(get_db),
):
    """Authenticates credentials and returns access and refresh token pair."""
    user_agent = request.headers.get("user-agent")
    return AuthService.login(
        session=session,
        email=payload.email,
        password=payload.password,
        user_agent=user_agent,
    )

@router.post(
    "/refresh",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
def refresh_token(
    request: Request,
    payload: RefreshRequest,
    session: Session = Depends(get_db),
):
    """Rotates refresh token and generates fresh access token."""
    user_agent = request.headers.get("user-agent")
    return AuthService.refresh(
        session=session,
        refresh_token_raw=payload.refresh_token,
        user_agent=user_agent,
    )

@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
)
def logout_user(
    payload: LogoutRequest,
    session: Session = Depends(get_db),
):
    """Revokes the presented refresh token's family."""
    AuthService.logout(session=session, refresh_token_raw=payload.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.post(
    "/logout-all",
    status_code=status.HTTP_204_NO_CONTENT,
)
def logout_all_sessions(
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_db),
):
    """Revokes all active refresh sessions for the authenticated user."""
    AuthService.logout_all(session=session, user_id=current_user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.get(
    "/me",
    response_model=AuthMeResponse,
    status_code=status.HTTP_200_OK,
)
def get_me(
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_db),
):
    """Returns profile, active household, and member details for authenticated user."""
    return AuthService.get_me(session=session, user=current_user)

