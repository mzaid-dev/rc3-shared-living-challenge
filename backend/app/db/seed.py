from datetime import datetime
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password
from app.db.models import Household, Member, MonthlyBudget, User

DEMO_HOUSEHOLD_NAME = "Gulberg Apartment"
DEMO_INVITE_CODE = "LAHORE2026"

DEMO_USERS_MEMBERS = [
    {
        "code": "M01",
        "name": "Ali",
        "email": "ali@demo.pk",
        "role": "owner",
        "sort_order": 1,
    },
    {
        "code": "M02",
        "name": "Ayesha",
        "email": "ayesha@demo.pk",
        "role": "member",
        "sort_order": 2,
    },
    {
        "code": "M03",
        "name": "Bilal",
        "email": "bilal@demo.pk",
        "role": "member",
        "sort_order": 3,
    },
]

def seed_demo_data(session: Session) -> bool:
    """
    Seeds the demo household 'Lahore Apartment' with Ali, Ayesha, Bilal and the default budget.
    
    Idempotent Guarantee:
    - Running multiple times leaves the database in the exact same state without resetting or duplicating data.
    """
    # 1. Ensure Household
    household = (
        session.query(Household)
        .filter((Household.name == DEMO_HOUSEHOLD_NAME) | (Household.invite_code == DEMO_INVITE_CODE))
        .first()
    )
    if not household:
        household = Household(
            name=DEMO_HOUSEHOLD_NAME,
            currency="PKR",
            timezone=settings.TIMEZONE,
            invite_code=DEMO_INVITE_CODE,
        )
        session.add(household)
        session.flush()
    elif household.name != DEMO_HOUSEHOLD_NAME:
        household.name = DEMO_HOUSEHOLD_NAME
        session.flush()

    # 2. Ensure Demo Users and Members
    password_hash = hash_password(settings.DEMO_PASSWORD)

    for spec in DEMO_USERS_MEMBERS:
        # Check User
        user = session.query(User).filter_by(email=spec["email"].lower()).first()
        if not user:
            user = User(
                email=spec["email"].lower(),
                password_hash=password_hash,
                display_name=spec["name"],
                is_active=True,
            )
            session.add(user)
            session.flush()

        # Check Member in Household
        member = (
            session.query(Member)
            .filter_by(household_id=household.id, code=spec["code"])
            .first()
        )
        if not member:
            member = Member(
                household_id=household.id,
                user_id=user.id,
                code=spec["code"],
                name=spec["name"],
                role=spec["role"],
                sort_order=spec["sort_order"],
            )
            session.add(member)
            session.flush()

    # 3. Ensure Monthly Budget for Active Month
    try:
        tz = ZoneInfo(settings.TIMEZONE)
        active_month = datetime.now(tz).strftime("%Y-%m")
    except Exception:
        active_month = datetime.utcnow().strftime("%Y-%m")

    budget = (
        session.query(MonthlyBudget)
        .filter_by(household_id=household.id, month=active_month)
        .first()
    )
    if not budget:
        budget = MonthlyBudget(
            household_id=household.id,
            month=active_month,
            limit_paisa=500_000,  # 5,000.00 PKR
        )
        session.add(budget)
        session.flush()

    session.commit()
    return True

