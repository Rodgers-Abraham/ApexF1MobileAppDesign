import sqlite3
import os
from contextlib import contextmanager
from core.config import get_settings

settings = get_settings()
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "f1_app.db")

SCHEMA_SQL = """
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

MIGRATIONS = [
    # Add name column if missing (legacy migration)
    "ALTER TABLE users ADD COLUMN name TEXT;",
    # Add favourite_driver column if missing (legacy migration)
    "ALTER TABLE users ADD COLUMN favourite_driver TEXT;",
]

def init_db():
    """Initializes the SQLite database schema."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.executescript(SCHEMA_SQL)

    # Apply legacy migrations safely
    for migration in MIGRATIONS:
        try:
            cursor.execute(migration)
        except sqlite3.OperationalError:
            pass

    # Purge any stale simulated session rows (keys 1000-1100) so real data is always loaded
    try:
        cursor.execute("DELETE FROM session_states WHERE session_key >= 1000 AND session_key <= 1100;")
    except Exception:
        pass

    conn.commit()
    conn.close()



@contextmanager
def get_db_connection():
    """Context manager for safe database connections."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()
