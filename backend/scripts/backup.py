#!/usr/bin/env python3
"""
scripts/backup.py

Production-grade SQLite WAL backup, verification, and restoration utility.
Features:
- Forces PRAGMA wal_checkpoint(TRUNCATE) before backup.
- Utilizes SQLite online backup API (sqlite3.backup) for zero-lock, live consistency.
- Generates SHA-256 checksum for immutable artifact verification.
- Validates structural and row integrity on restore.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import sqlite3
import sys

def compute_file_sha256(file_path: Path) -> str:
    """Computes SHA-256 hash of a file in 64 KB streaming chunks."""
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def create_backup(
    db_path: str = "./data/app.db",
    backup_dir: str = "./backups",
) -> tuple[Path, Path]:
    """
    Creates an online, timestamped backup of the SQLite database.
    Returns (backup_file_path, checksum_file_path).
    """
    source_db = Path(db_path).resolve()
    if not source_db.exists():
        raise FileNotFoundError(f"Source database file not found: {source_db}")

    out_dir = Path(backup_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    backup_file = out_dir / f"app_backup_{timestamp}.sqlite"
    checksum_file = out_dir / f"app_backup_{timestamp}.sha256"

    # 1. Connect to source database and checkpoint WAL
    source_conn = sqlite3.connect(str(source_db))
    try:
        source_conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")

        # 2. Use SQLite live backup API into target file
        target_conn = sqlite3.connect(str(backup_file))
        try:
            source_conn.backup(target_conn, pages=100)
        finally:
            target_conn.close()
    finally:
        source_conn.close()

    # 3. Compute and store SHA-256 checksum
    sha256_hash = compute_file_sha256(backup_file)
    checksum_file.write_text(f"{sha256_hash}  {backup_file.name}\n", encoding="utf-8")

    return backup_file, checksum_file

def verify_backup(backup_file_path: Path, expected_sha256: str = None) -> bool:
    """Verifies SHA-256 integrity and internal database readability."""
    p = Path(backup_file_path)
    if not p.exists():
        raise FileNotFoundError(f"Backup file not found: {p}")

    # 1. Verify SHA-256 Checksum
    actual_hash = compute_file_sha256(p)
    if expected_sha256:
        if actual_hash.strip().lower() != expected_sha256.strip().lower():
            raise ValueError(f"Checksum mismatch! Expected {expected_sha256}, got {actual_hash}")

    # 2. Verify SQLite integrity pragma
    conn = sqlite3.connect(str(p))
    try:
        cursor = conn.cursor()
        cursor.execute("PRAGMA integrity_check;")
        result = cursor.fetchone()
        if not result or result[0] != "ok":
            raise ValueError(f"SQLite PRAGMA integrity_check failed: {result}")

        # Verify key tables exist
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = {row[0] for row in cursor.fetchall()}
        required_tables = {"users", "households", "members", "expenses", "settlements"}
        missing = required_tables - tables
        if missing:
            raise ValueError(f"Backup is missing required tables: {missing}")
    finally:
        conn.close()

    return True

def restore_backup(backup_file_path: Path, target_db_path: Path) -> bool:
    """Restores a validated backup file to target destination."""
    src = Path(backup_file_path)
    dst = Path(target_db_path)

    # First verify source integrity
    verify_backup(src)

    dst.parent.mkdir(parents=True, exist_ok=True)

    # Use SQLite backup API for clean restoration
    src_conn = sqlite3.connect(str(src))
    dst_conn = sqlite3.connect(str(dst))
    try:
        src_conn.backup(dst_conn)
    finally:
        src_conn.close()
        dst_conn.close()

    # Verify restored database
    verify_backup(dst)
    return True

def main():
    parser = argparse.ArgumentParser(description="RC3 SQLite Database Backup and Restore Utility")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Backup command
    backup_parser = subparsers.add_parser("create", help="Create a live WAL-checkpointed backup")
    backup_parser.add_argument("--db", default="./data/app.db", help="Path to database")
    backup_parser.add_argument("--out-dir", default="./backups", help="Target backups folder")

    # Verify command
    verify_parser = subparsers.add_parser("verify", help="Verify backup checksum and SQLite integrity")
    verify_parser.add_argument("backup_file", help="Path to .sqlite backup file")
    verify_parser.add_argument("--checksum", help="Optional expected SHA-256 hash")

    # Restore command
    restore_parser = subparsers.add_parser("restore", help="Restore backup to a target database")
    restore_parser.add_argument("backup_file", help="Path to backup file")
    restore_parser.add_argument("--dest", required=True, help="Destination database path")

    args = parser.parse_args()

    if args.command == "create":
        b_file, c_file = create_backup(args.db, args.out_dir)
        print(f"[SUCCESS] Backup created: {b_file}")
        print(f"[SUCCESS] SHA-256 checksum saved: {c_file}")
    elif args.command == "verify":
        verify_backup(Path(args.backup_file), args.checksum)
        print(f"[SUCCESS] Backup verified intact: {args.backup_file}")
    elif args.command == "restore":
        restore_backup(Path(args.backup_file), Path(args.dest))
        print(f"[SUCCESS] Database restored successfully to: {args.dest}")

if __name__ == "__main__":
    main()

