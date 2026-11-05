from typing import Optional
from sqlalchemy.orm import Session
from app.db.models import User

class UserRepository:
    @staticmethod
    def get_by_id(session: Session, user_id: str) -> Optional[User]:
        return session.query(User).filter_by(id=user_id).first()

    @staticmethod
    def get_by_email(session: Session, email: str) -> Optional[User]:
        return session.query(User).filter_by(email=email.strip().lower()).first()

    @staticmethod
    def create(
        session: Session,
        email: str,
        password_hash: str,
        display_name: str,
    ) -> User:
        user = User(
            email=email.strip().lower(),
            password_hash=password_hash,
            display_name=display_name.strip(),
            is_active=True,
        )
        session.add(user)
        session.flush()
        return user

