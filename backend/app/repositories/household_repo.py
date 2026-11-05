import secrets
from typing import Optional
from sqlalchemy.orm import Session
from app.db.models import Household

UNAMBIGUOUS_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

def generate_invite_code(length: int = 8) -> str:
    """Generates an 8-character invite code using an unambiguous alphanumeric alphabet."""
    return "".join(secrets.choice(UNAMBIGUOUS_ALPHABET) for _ in range(length))

class HouseholdRepository:
    @staticmethod
    def get_by_id(session: Session, household_id: str) -> Optional[Household]:
        return session.query(Household).filter_by(id=household_id).first()

    @staticmethod
    def get_by_invite_code(session: Session, invite_code: str) -> Optional[Household]:
        return session.query(Household).filter_by(invite_code=invite_code.strip().upper()).first()

    @staticmethod
    def create(
        session: Session,
        name: str,
        invite_code: str,
        currency: str = "PKR",
        timezone: str = "Asia/Karachi",
    ) -> Household:
        hh = Household(
            name=name.strip(),
            currency=currency,
            timezone=timezone,
            invite_code=invite_code.strip().upper(),
        )
        session.add(hh)
        session.flush()
        return hh

    @staticmethod
    def update_invite_code(session: Session, household: Household, new_code: str) -> None:
        household.invite_code = new_code.strip().upper()
        session.flush()

