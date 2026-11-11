"""
Replay/Recap session API routes.
Mounted at /api/timing — does NOT touch existing /api/sessions (ML/predictions) routes.

GET /api/timing/sessions            → list all ready sessions grouped by year
GET /api/timing/sessions/live       → current live session info
GET /api/timing/sessions/{id}/meta  → session metadata (drivers, circuit, etc.)
GET /api/timing/sessions/{id}/data  → full timing data (laps, events, weather)
GET /api/timing/sessions/{id}/replay → SSE stream of lap-by-lap replay
"""
import json
import asyncio
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse

from core.database import get_db_connection, IS_POSTGRES

router = APIRouter()


def _load_jsonb(raw) -> Optional[dict]:
    """Deserialise JSONB from either Postgres (already dict) or SQLite (JSON string)."""
    if raw is None:
        return None
    if isinstance(raw, (dict, list)):
        return raw
    try:
        return json.loads(raw)
    except Exception:
        return None


# ---------------------------------------------------------------------------
# GET /api/timing/sessions
# ---------------------------------------------------------------------------
@router.get("/sessions")
def list_sessions():
    """List all ready sessions grouped by year → event."""
    with get_db_connection() as conn:
        rows = conn.execute(
            """SELECT id, year, event, session_type, session_date, status,
                      meta
               FROM sessions
               WHERE status = 'ready'
               ORDER BY year DESC, session_date ASC""",
        ).fetchall()

    # Group by year → event
    result: dict[int, dict[str, list]] = {}
    for row in rows:
        year = row["year"]
        event = row["event"]
        meta = _load_jsonb(row["meta"]) or {}
        if year not in result:
            result[year] = {}
        if event not in result[year]:
            result[year][event] = {
                "event": event,
                "event_name": meta.get("event_name", event.replace("_", " ")),
                "country": meta.get("country", ""),
                "sessions": [],
            }
        result[year][event]["sessions"].append({
            "id": row["id"],
            "session_type": row["session_type"],
            "session_date": row["session_date"],
        })

    output = []
    for year in sorted(result.keys(), reverse=True):
        for event_data in result[year].values():
            output.append({"year": year, **event_data})
    return output


# ---------------------------------------------------------------------------
# GET /api/timing/sessions/live
# ---------------------------------------------------------------------------
@router.get("/sessions/live")
def get_live_session():
    """Return current live session info (or {is_live: false})."""
    # Reuse existing session status from f1_api_client
    try:
        from services.f1_api_client import f1_api_client
        status = f1_api_client.get_session_status()
        return {
            "is_live": status.get("is_live", False),
            "session_type": status.get("session_type"),
            "meeting_name": status.get("meeting_name"),
            "lap": status.get("current_lap"),
            "total_laps": status.get("total_laps"),
        }
    except Exception:
        return {"is_live": False}


# ---------------------------------------------------------------------------
# GET /api/timing/sessions/{session_id}/meta
# ---------------------------------------------------------------------------
@router.get("/sessions/{session_id}/meta")
def get_session_meta(session_id: str):
    """Return session metadata: drivers, circuit, session_info."""
    with get_db_connection() as conn:
        row = conn.execute(
            "SELECT id, year, event, session_type, session_date, status, meta FROM sessions WHERE id = ?",
            (session_id,)
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Session not found")
    if row["status"] != "ready":
        raise HTTPException(status_code=404, detail=f"Session not ready (status={row['status']})")
    meta = _load_jsonb(row["meta"]) or {}
    return {
        "id": row["id"],
        "year": row["year"],
        "event": row["event"],
        "session_type": row["session_type"],
        "session_date": row["session_date"],
        **meta,
    }


# ---------------------------------------------------------------------------
# GET /api/timing/sessions/{session_id}/data
# ---------------------------------------------------------------------------
@router.get("/sessions/{session_id}/data")
def get_session_data(session_id: str):
    """Return full timing payload: laps, events, weather, results."""
    with get_db_connection() as conn:
        row = conn.execute(
            """SELECT id, year, event, session_type, session_date, status,
                      meta, laps, events, weather, results
               FROM sessions WHERE id = ?""",
            (session_id,)
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Session not found")
    if row["status"] != "ready":
        raise HTTPException(status_code=404, detail=f"Session not ready (status={row['status']})")

    return {
        "id": row["id"],
        "year": row["year"],
        "event": row["event"],
        "session_type": row["session_type"],
        "session_date": row["session_date"],
        "meta": _load_jsonb(row["meta"]),
        "laps": _load_jsonb(row["laps"]),
        "events": _load_jsonb(row["events"]),
        "weather": _load_jsonb(row["weather"]),
        "results": _load_jsonb(row["results"]),
    }


# ---------------------------------------------------------------------------
# GET /api/timing/sessions/{session_id}/replay  (SSE)
# ---------------------------------------------------------------------------
@router.get("/sessions/{session_id}/replay")
async def stream_replay(
    session_id: str,
    speed: float = Query(default=1.0, ge=0.1, le=100.0),
    start_lap: int = Query(default=0, ge=0),
):
    """
    Server-Sent Events stream of lap-by-lap replay.
    For Race: one SSE event per lap boundary.
    Speed multiplier: 1.0 = 3s/lap, 2.0 = 1.5s/lap, 4.0 = 0.75s/lap
    """
    with get_db_connection() as conn:
        row = conn.execute(
            "SELECT session_type, laps, events FROM sessions WHERE id = ? AND status = 'ready'",
            (session_id,)
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Session not found or not ready")

    session_type = row["session_type"]
    laps_data = _load_jsonb(row["laps"]) or {}
    events_data = _load_jsonb(row["events"]) or []

    # Build per-lap event lookup
    events_by_lap: dict[int, list] = {}
    for ev in (events_data if isinstance(events_data, list) else []):
        lap = ev.get("lap", 0)
        events_by_lap.setdefault(lap, []).append(ev)

    # Base interval per lap (seconds)
    BASE_INTERVAL_S = 3.0 / speed

    async def race_generator():
        laps = laps_data.get("laps", [])
        total = laps_data.get("total_laps", len(laps))

        # Send initial session_status
        yield f"event: session_status\ndata: {json.dumps({'session_type': session_type, 'total_laps': total, 'is_live': False})}\n\n"

        for lap_data in laps:
            lap_num = lap_data.get("lap", 0)
            if lap_num < start_lap:
                continue
            if lap_num == 0:
                # Grid lap — send immediately
                yield f"event: grid\ndata: {json.dumps({'lap': 0, 'grid': laps_data.get('grid', [])})}\n\n"
                continue

            # Delay
            await asyncio.sleep(BASE_INTERVAL_S)

            payload = {
                "lap": lap_num,
                "total_laps": total,
                "positions": lap_data.get("positions", []),
                "fastest_code": lap_data.get("fastest_code"),
                "fastest_lap_time": lap_data.get("fastest_lap_time"),
                "track_status": lap_data.get("track_status", "1"),
                "sc_active": lap_data.get("sc_active", False),
                "vsc_active": lap_data.get("vsc_active", False),
                "red_flag": lap_data.get("red_flag", False),
                "events": events_by_lap.get(lap_num, []),
            }
            yield f"event: lap_update\ndata: {json.dumps(payload)}\n\n"

        # Race complete
        yield f"event: session_complete\ndata: {json.dumps({'lap': total, 'total_laps': total})}\n\n"

    async def practice_generator():
        timeline = laps_data.get("timeline", [])
        duration = laps_data.get("session_duration_s", 3600)

        yield f"event: session_status\ndata: {json.dumps({'session_type': session_type, 'duration_s': duration})}\n\n"

        for entry in timeline:
            # Compress time: each event takes proportional time at speed
            await asyncio.sleep(0.1 / speed)  # simplified; real impl would use sesT delta
            yield f"event: best_lap\ndata: {json.dumps(entry)}\n\n"

        yield f"event: session_complete\ndata: {json.dumps({'final_order': laps_data.get('final_order', [])})}\n\n"

    async def qualifying_generator():
        segments = laps_data.get("segments", {})
        segment_order = laps_data.get("segment_order", list(segments.keys()))

        yield f"event: session_status\ndata: {json.dumps({'session_type': session_type, 'segments': segment_order})}\n\n"

        for seg_name in segment_order:
            seg_data = segments.get(seg_name, {})
            yield f"event: segment_start\ndata: {json.dumps({'segment': seg_name})}\n\n"
            for entry in seg_data.get("timeline", []):
                await asyncio.sleep(0.1 / speed)
                yield f"event: best_lap\ndata: {json.dumps({**entry, 'segment': seg_name})}\n\n"
            yield f"event: segment_end\ndata: {json.dumps({'segment': seg_name, 'eliminated': seg_data.get('eliminated', []), 'final_order': seg_data.get('final_order', [])})}\n\n"

        yield f"event: session_complete\ndata: {json.dumps({'pole': laps_data.get('pole'), 'final_grid': laps_data.get('final_grid', [])})}\n\n"

    if session_type == "Race" or session_type == "Sprint":
        gen = race_generator()
    elif session_type in ("P1", "P2", "P3"):
        gen = practice_generator()
    elif session_type in ("Q", "SQ"):
        gen = qualifying_generator()
    else:
        gen = race_generator()

    return StreamingResponse(
        gen,
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
