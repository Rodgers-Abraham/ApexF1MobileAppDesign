import os
import re
import sqlite3
from contextlib import contextmanager
from typing import Optional

try:
    import psycopg2
    from psycopg2.extras import DictCursor
    from psycopg2.pool import ThreadedConnectionPool
    from psycopg2 import IntegrityError as PgIntegrityError
    HAS_POSTGRES = True
except ImportError:
    HAS_POSTGRES = False
    PgIntegrityError = sqlite3.IntegrityError

from core.config import get_settings

settings = get_settings()
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "f1_app.db")

# Unified IntegrityError for routes catching duplicate keys/constraints
DBIntegrityError = (sqlite3.IntegrityError, PgIntegrityError)

# Check if PostgreSQL is configured
DATABASE_URL = os.getenv("DATABASE_URL") or settings.database_url
IS_POSTGRES = bool(
    HAS_POSTGRES
    and DATABASE_URL
    and (DATABASE_URL.startswith("postgresql://") or DATABASE_URL.startswith("postgres://"))
)

# Global pool for PostgreSQL connections
_pg_pool: Optional[object] = None


def _get_pg_pool():
    global _pg_pool
    if _pg_pool is None and IS_POSTGRES:
        # Standardize connection string
        dsn = DATABASE_URL
        if dsn.startswith("postgres://"):
            dsn = "postgresql://" + dsn[len("postgres://"):]
        _pg_pool = ThreadedConnectionPool(minconn=1, maxconn=20, dsn=dsn)
    return _pg_pool


def _adapt_query(query: str) -> str:
    """Translates SQLite '?' positional placeholders to PostgreSQL '%s'."""
    parts = []
    in_quote = False
    quote_char = ""
    i = 0
    while i < len(query):
        ch = query[i]
        if ch in ("'", '"'):
            if not in_quote:
                in_quote = True
                quote_char = ch
            elif quote_char == ch:
                in_quote = False
            parts.append(ch)
        elif ch == "?" and not in_quote:
            parts.append("%s")
        else:
            parts.append(ch)
        i += 1
    return "".join(parts)


class PostgresCursorWrapper:
    """Wraps psycopg2 DictCursor to support SQLite-compatible '?' placeholders."""
    def __init__(self, raw_cursor):
        self._cursor = raw_cursor

    def execute(self, query, params=None):
        adapted = _adapt_query(query)
        if params is not None:
            return self._cursor.execute(adapted, params)
        return self._cursor.execute(adapted)

    def executescript(self, script: str):
        # Executes multiple semicoloned statements
        return self._cursor.execute(script)

    def executemany(self, query, seq_of_params):
        adapted = _adapt_query(query)
        return self._cursor.executemany(adapted, seq_of_params)

    def fetchone(self):
        return self._cursor.fetchone()

    def fetchall(self):
        return self._cursor.fetchall()

    def fetchmany(self, size=None):
        return self._cursor.fetchmany(size) if size else self._cursor.fetchmany()

    def __iter__(self):
        return iter(self._cursor)

    @property
    def rowcount(self):
        return self._cursor.rowcount

    @property
    def description(self):
        return self._cursor.description

    def close(self):
        try:
            self._cursor.close()
        except Exception:
            pass


class PostgresConnectionWrapper:
    """Wraps psycopg2 connection to expose SQLite-like convenience methods (conn.execute)."""
    def __init__(self, raw_conn, pool=None):
        self._conn = raw_conn
        self._pool = pool
        self._closed = False

    def cursor(self):
        return PostgresCursorWrapper(self._conn.cursor(cursor_factory=DictCursor))

    def execute(self, query, params=None):
        cur = self.cursor()
        cur.execute(query, params)
        return cur

    def commit(self):
        self._conn.commit()

    def rollback(self):
        self._conn.rollback()

    def close(self):
        if not self._closed:
            self._closed = True
            if self._pool:
                try:
                    self._pool.putconn(self._conn)
                except Exception:
                    pass
            else:
                try:
                    self._conn.close()
                except Exception:
                    pass


POSTGRES_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name TEXT,
    favourite_team TEXT DEFAULT 'Ferrari',
    favourite_driver TEXT,
    is_pro INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    race_name TEXT,
    predicted_winner TEXT,
    prediction_date TEXT
);

CREATE TABLE IF NOT EXISTS session_states (
    id SERIAL PRIMARY KEY,
    session_key INTEGER UNIQUE,
    meeting_name TEXT,
    session_name TEXT,
    session_type TEXT,
    status TEXT,
    date_start TEXT,
    results_json TEXT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auto_predictions (
    id SERIAL PRIMARY KEY,
    session_key INTEGER,
    predictions_json TEXT,
    prediction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pro_subscriptions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    revenuecat_customer_id TEXT,
    is_active INTEGER DEFAULT 0,
    expires_at TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"""

SQLITE_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name TEXT,
    favourite_team TEXT DEFAULT 'Ferrari',
    favourite_driver TEXT,
    is_pro INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS predictions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    race_name TEXT,
    predicted_winner TEXT,
    prediction_date TEXT,
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS session_states (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_key INTEGER UNIQUE,
    meeting_name TEXT,
    session_name TEXT,
    session_type TEXT,
    status TEXT,
    date_start TEXT,
    results_json TEXT,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auto_predictions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_key INTEGER,
    predictions_json TEXT,
    prediction_date DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pro_subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    revenuecat_customer_id TEXT,
    is_active INTEGER DEFAULT 0,
    expires_at TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id)
);
"""


def init_db():
    """Initializes the database schema for either PostgreSQL or SQLite."""
    if IS_POSTGRES:
        pool = _get_pg_pool()
        raw_conn = pool.getconn()
        try:
            with raw_conn.cursor() as cur:
                cur.execute(POSTGRES_SCHEMA_SQL)
                # Purge simulated session rows (keys 1000-1100)
                try:
                    cur.execute("DELETE FROM session_states WHERE session_key >= 1000 AND session_key <= 1100;")
                except Exception:
                    pass
            raw_conn.commit()
        finally:
            pool.putconn(raw_conn)
        print("Connected and initialized Neon PostgreSQL database.")
    else:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.executescript(SQLITE_SCHEMA_SQL)

        # Legacy migrations
        for migration in [
            "ALTER TABLE users ADD COLUMN name TEXT;",
            "ALTER TABLE users ADD COLUMN favourite_driver TEXT;",
        ]:
            try:
                cursor.execute(migration)
            except sqlite3.OperationalError:
                pass

        try:
            cursor.execute("DELETE FROM session_states WHERE session_key >= 1000 AND session_key <= 1100;")
        except Exception:
            pass

        conn.commit()
        conn.close()
        print(f"Connected and initialized SQLite database at {DB_PATH}.")


@contextmanager
def get_db_connection():
    """Context manager for safe database connections across PostgreSQL and SQLite."""
    if IS_POSTGRES:
        pool = _get_pg_pool()
        raw_conn = pool.getconn()
        wrapper = PostgresConnectionWrapper(raw_conn, pool)
        try:
            yield wrapper
        except Exception:
            wrapper.rollback()
            raise
        finally:
            wrapper.close()
    else:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()
