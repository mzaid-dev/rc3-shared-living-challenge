from typing import List
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.deps import Context, get_db, require_role
from app.repositories.audit_repo import AuditRepository
from app.schemas.audit import AuditLogItem

router = APIRouter(prefix="/api/audit", tags=["Audit"])

@router.get(
    "",
    response_model=List[AuditLogItem],
    status_code=status.HTTP_200_OK,
)
def get_audit_logs(
    limit: int = Query(50, ge=1, le=100, description="Max audit entries to fetch"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    ctx: Context = Depends(require_role("owner", "admin")),
    session: Session = Depends(get_db),
):
    """
    Lists household audit trail history, newest first.
    Restricted to household owner and admin.
    """
    return AuditRepository.list_audit_logs(
        session=session,
        household_id=ctx.household_id,
        limit=limit,
        offset=offset,
    )

