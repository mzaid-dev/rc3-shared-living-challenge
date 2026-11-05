import os
from contextlib import contextmanager
from pathlib import Path
from typing import Generator, Optional
import sqlite3

from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

def _ensure_sqlite_dir(url: str) -> None:
    if url.startswith("sqlite:///"):
        raw_path = url.replace("sqlite:///", "")
        if raw_path and raw_path != ":memory:":
            Path(raw_path).parent.mkdir(parents=True, exist_ok=True)

_ensure_sqlite_dir(settings.DATABASE_URL)

engine = create_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    future=True,
)

if engine.dialect.name == "sqlite":
    @event.listens_for(engine, "connect")
    def configure_sqlite_connection(dbapi_connection, connection_record):
        # 1. Disable pysqlite implicit transactions to control BEGIN statements manually
        dbapi_connection.isolation_level = None

        # 2. Configure high-concurrency and integrity PRAGMAs
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON;")
        cursor.execute("PRAGMA journal_mode=WAL;")
        cursor.execute("PRAGMA busy_timeout=5000;")
        cursor.execute("PRAGMA synchronous=NORMAL;")
        cursor.close()

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)

def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency yielding a database session."""
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()

@contextmanager
def unit_of_work(session: Optional[Session] = None, write: bool = True):
    """
    Context manager for atomic transactional use-cases.
    For SQLite write operations, issues BEGIN IMMEDIATE to acquire an exclusive lock early.
    Guarantees atomic commit or rollback.
    """
    own_session = False
    if session is None:
        session = SessionLocal()
        own_session = True

    try:
        if session.bind.dialect.name == "sqlite" and write:
            session.execute(text("BEGIN IMMEDIATE"))
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        if own_session:
            session.close()

def lock_household(session: Session, household_id: str) -> None:
    """
    Concurrency control helper:
    - No-op on SQLite (database-level concurrency is governed by WAL and BEGIN IMMEDIATE).
    - Issues `SELECT ... FOR UPDATE` on Postgres to serialize operations per household.
    """
    if session.bind.dialect.name == "postgresql":
        session.execute(
            text("SELECT id FROM households WHERE id = :hid FOR UPDATE"),
            {"hid": household_id},
        )

