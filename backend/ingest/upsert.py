# backend/ingest/upsert.py
"""Write parsed session data to the Neon sessions table."""
import json
import sys
import os
from datetime import datetime, timezone
from typing import Optional

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.database import get_db_connection, IS_POSTGRES

try:
    from psycopg2.extras import Json as PgJson
    HAS_PG_JSON = True
except ImportError:
    HAS_PG_JSON = False


def _jsonb(value) -> object:
    """Wrap value for JSONB insert: psycopg2.extras.Json for Postgres, json string for SQLite."""
    if value is None:
        return None
    if IS_POSTGRES and HAS_PG_JSON:
        return PgJson(value)
    return json.dumps(value)


def upsert_session(
    year: int,
    event: str,
    session_type: str,
    source_hash: str,
    meta: dict,
    parsed: dict,
    jolpica_results: Optional[list],
    status: str = "ready",
    error: Optional[str] = None,
) -> str:
    """
    Upsert a session row. Returns the session id.
    Safe to call twice — second call is a no-op if hash unchanged.
    """
    with get_db_connection() as conn:
        existing = conn.execute(
            "SELECT id, source_hash, status FROM sessions WHERE year=? AND event=? AND session_type=?",
            (year, event, session_type),
        ).fetchone()

        now = datetime.now(timezone.utc).isoformat()
        laps_data = parsed.get("laps")
        events_data = parsed.get("rcm_events")
        weather_data = parsed.get("weather")
        radio_data = parsed.get("radio")

        if existing:
            if existing["source_hash"] == source_hash and existing["status"] == "ready":
                return existing["id"]  # No-op
            conn.execute(
                """UPDATE sessions SET
                   status=?, error=?, source_hash=?, ingested_at=?,
                   meta=?, laps=?, events=?, weather=?, results=?, radio=?
                   WHERE year=? AND event=? AND session_type=?""",
                (
                    status, error, source_hash, now,
                    _jsonb(meta), _jsonb(laps_data), _jsonb(events_data),
                    _jsonb(weather_data), _jsonb(jolpica_results), _jsonb(radio_data),
                    year, event, session_type,
                ),
            )
            conn.commit()
            return existing["id"]
        else:
            if IS_POSTGRES:
                result = conn.execute(
                    """INSERT INTO sessions
                       (year, event, session_type, status, error, source_hash, ingested_at,
                        meta, laps, events, weather, results, radio)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                       RETURNING id""",
                    (
                        year, event, session_type, status, error, source_hash, now,
                        _jsonb(meta), _jsonb(laps_data), _jsonb(events_data),
                        _jsonb(weather_data), _jsonb(jolpica_results), _jsonb(radio_data),
                    ),
                ).fetchone()
                conn.commit()
                return result["id"]
            else:
                conn.execute(
                    """INSERT INTO sessions
                       (year, event, session_type, status, error, source_hash, ingested_at,
                        meta, laps, events, weather, results, radio)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (
                        year, event, session_type, status, error, source_hash, now,
                        _jsonb(meta), _jsonb(laps_data), _jsonb(events_data),
                        _jsonb(weather_data), _jsonb(jolpica_results), _jsonb(radio_data),
                    ),
                )
                conn.commit()
                return conn.execute(
                    "SELECT id FROM sessions WHERE year=? AND event=? AND session_type=?",
                    (year, event, session_type),
                ).fetchone()["id"]


def mark_failed(year: int, event: str, session_type: str, error: str):
    """Mark a session as failed without overwriting existing ready data."""
    with get_db_connection() as conn:
        existing = conn.execute(
            "SELECT status FROM sessions WHERE year=? AND event=? AND session_type=?",
            (year, event, session_type),
        ).fetchone()
        if existing and existing["status"] == "ready":
            return  # Keep existing good data
        now = datetime.now(timezone.utc).isoformat()
        if IS_POSTGRES:
            conn.execute(
                """INSERT INTO sessions (year, event, session_type, status, error, ingested_at)
                   VALUES (?, ?, ?, 'failed', ?, ?)
                   ON CONFLICT (year, event, session_type)
                   DO UPDATE SET status='failed', error=EXCLUDED.error, ingested_at=EXCLUDED.ingested_at
                   WHERE sessions.status != 'ready'""",
                (year, event, session_type, error, now),
            )
        else:
            if existing:
                conn.execute(
                    "UPDATE sessions SET status='failed', error=?, ingested_at=? WHERE year=? AND event=? AND session_type=?",
                    (error, now, year, event, session_type),
                )
            else:
                conn.execute(
                    "INSERT INTO sessions (year, event, session_type, status, error, ingested_at) VALUES (?,?,?,'failed',?,?)",
                    (year, event, session_type, error, now),
                )
        conn.commit()
