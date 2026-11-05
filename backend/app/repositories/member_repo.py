import re
from typing import Any, List, Optional, Tuple
from sqlalchemy.orm import Session
from app.db.models import Member

class MemberRepository:
    @staticmethod
    def resolve_member(
        session: Session,
        household_id: str,
        identifier: Any,
    ) -> Optional[Member]:
        """
        Resolves a member in the household by numeric ID (e.g. 1) or member code (e.g. 'M01').
        Strictly scoped to household_id. Returns None if not found in this household.
        """
        if identifier is None:
            return None

        # 1. Try by code first if it looks like M01 / M1 / etc.
        id_str = str(identifier).strip()
        member = (
            session.query(Member)
            .filter_by(household_id=household_id, code=id_str.upper())
            .first()
        )
        if member:
            return member

        # 2. Try by integer ID if numeric
        if isinstance(identifier, int) or id_str.isdigit():
            member = (
                session.query(Member)
                .filter_by(household_id=household_id, id=int(id_str))
                .first()
            )
            if member:
                return member

        return None

    @staticmethod
    def get_by_id(session: Session, household_id: str, member_id: int) -> Optional[Member]:
        return (
            session.query(Member)
            .filter_by(household_id=household_id, id=member_id)
            .first()
        )

    @staticmethod
    def get_by_code(session: Session, household_id: str, code: str) -> Optional[Member]:
        return (
            session.query(Member)
            .filter_by(household_id=household_id, code=code.strip().upper())
            .first()
        )

    @staticmethod
    def get_by_user_id(session: Session, user_id: str) -> Optional[Member]:
        return session.query(Member).filter_by(user_id=user_id).first()

    @staticmethod
    def list_by_household(session: Session, household_id: str) -> List[Member]:
        return (
            session.query(Member)
            .filter_by(household_id=household_id)
            .order_by(Member.sort_order.asc(), Member.code.asc())
            .all()
        )

    @staticmethod
    def get_next_member_code(session: Session, household_id: str) -> Tuple[str, int]:
        """
        Determines the next free 'M%02d' code in the household.
        Sort order equals the numeric part. Codes are never reused.
        """
        members = session.query(Member).filter_by(household_id=household_id).all()
        max_num = 0
        for m in members:
            match = re.search(r"\d+", m.code)
            if match:
                num = int(match.group())
                if num > max_num:
                    max_num = num

        next_num = max_num + 1
        return f"M{next_num:02d}", next_num

    @staticmethod
    def create_member(
        session: Session,
        household_id: str,
        name: str,
        code: str,
        sort_order: int,
        role: str = "member",
        user_id: Optional[str] = None,
    ) -> Member:
        member = Member(
            household_id=household_id,
            user_id=user_id,
            code=code,
            name=name.strip(),
            role=role,
            sort_order=sort_order,
        )
        session.add(member)
        session.flush()
        return member

