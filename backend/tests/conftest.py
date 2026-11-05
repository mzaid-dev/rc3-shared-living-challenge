import pytest
from app.db.base import Base
from app.db.seed import seed_demo_data
from app.db.session import SessionLocal, engine

@pytest.fixture(scope="session", autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as session:
        seed_demo_data(session)
    yield

