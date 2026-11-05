# RC3 Shared Living App - Backend Foundation

Production-grade, financial backend built with FastAPI, SQLAlchemy 2.0 (sync), and SQLite (WAL).

## Architecture Highlights
- **Integer Paisa Standard:** Zero float representation; money stored as integer minor units.
- **Layered Monolith:** Routers -> Services -> Domain -> Repositories.
- **ACID Transactions:** SQLite `BEGIN IMMEDIATE` transaction safety with `unit_of_work`.
- **Relational Integrity:** Foreign keys enforced on every SQLite connection with WAL journal mode.

## Quick Start
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

