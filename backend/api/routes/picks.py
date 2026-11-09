from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone
from core.auth import get_current_user
from core.database import get_db_connection, DBIntegrityError

router = APIRouter()


class RacePicksRequest(BaseModel):
    race_name: str
    race_date: str
    podium_p1: str
    podium_p2: str
    podium_p3: str
    pole_sitter: str
    fastest_lap: str
    safety_cars: int = 0
    first_team_to_pit: str = ""
    confidence: int = 50


class RacePicksResponse(BaseModel):
    race_name: str
    race_date: str
    podium_p1: str
    podium_p2: str
    podium_p3: str
    pole_sitter: str
    fastest_lap: str
    safety_cars: int
    first_team_to_pit: str
    confidence: int
    is_locked: bool
    submitted_at: Optional[str] = None


def _is_race_locked(race_date: str) -> bool:
    try:
        rd = datetime.fromisoformat(race_date)
        if not rd.tzinfo:
            rd = rd.replace(tzinfo=timezone.utc)
        return datetime.now(timezone.utc) >= rd
    except Exception:
        return False


@router.post("/picks", response_model=RacePicksResponse)
async def save_picks(req: RacePicksRequest, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]

    if _is_race_locked(req.race_date):
        raise HTTPException(status_code=400, detail="Predictions are locked — race has already started.")

    with get_db_connection() as conn:
        existing = conn.execute(
            "SELECT is_locked FROM user_race_picks WHERE user_id = ? AND race_name = ?",
            (user_id, req.race_name),
        ).fetchone()

        if existing and existing["is_locked"]:
            raise HTTPException(status_code=400, detail="Prediction is already locked.")

        conn.execute(
            """INSERT INTO user_race_picks
               (user_id, race_name, race_date, podium_p1, podium_p2, podium_p3,
                pole_sitter, fastest_lap, safety_cars, first_team_to_pit, confidence, is_locked)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
               ON CONFLICT(user_id, race_name) DO UPDATE SET
                 podium_p1=excluded.podium_p1, podium_p2=excluded.podium_p2,
                 podium_p3=excluded.podium_p3, pole_sitter=excluded.pole_sitter,
                 fastest_lap=excluded.fastest_lap, safety_cars=excluded.safety_cars,
                 first_team_to_pit=excluded.first_team_to_pit, confidence=excluded.confidence,
                 submitted_at=CURRENT_TIMESTAMP""",
            (user_id, req.race_name, req.race_date, req.podium_p1, req.podium_p2,
             req.podium_p3, req.pole_sitter, req.fastest_lap, req.safety_cars,
             req.first_team_to_pit, req.confidence),
        )
        conn.commit()

        row = conn.execute(
            "SELECT * FROM user_race_picks WHERE user_id = ? AND race_name = ?",
            (user_id, req.race_name),
        ).fetchone()

    return RacePicksResponse(
        race_name=row["race_name"],
        race_date=row["race_date"] or req.race_date,
        podium_p1=row["podium_p1"] or "",
        podium_p2=row["podium_p2"] or "",
        podium_p3=row["podium_p3"] or "",
        pole_sitter=row["pole_sitter"] or "",
        fastest_lap=row["fastest_lap"] or "",
        safety_cars=row["safety_cars"] or 0,
        first_team_to_pit=row["first_team_to_pit"] or "",
        confidence=row["confidence"] or 50,
        is_locked=bool(row["is_locked"]),
        submitted_at=str(row["submitted_at"]) if row["submitted_at"] else None,
    )


@router.post("/picks/lock", response_model=RacePicksResponse)
async def lock_picks(race_name: str, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]

    with get_db_connection() as conn:
        row = conn.execute(
            "SELECT * FROM user_race_picks WHERE user_id = ? AND race_name = ?",
            (user_id, race_name),
        ).fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="No prediction found for this race.")

        conn.execute(
            "UPDATE user_race_picks SET is_locked = 1 WHERE user_id = ? AND race_name = ?",
            (user_id, race_name),
        )
        conn.commit()

        row = conn.execute(
            "SELECT * FROM user_race_picks WHERE user_id = ? AND race_name = ?",
            (user_id, race_name),
        ).fetchone()

    return RacePicksResponse(
        race_name=row["race_name"],
        race_date=row["race_date"] or "",
        podium_p1=row["podium_p1"] or "",
        podium_p2=row["podium_p2"] or "",
        podium_p3=row["podium_p3"] or "",
        pole_sitter=row["pole_sitter"] or "",
        fastest_lap=row["fastest_lap"] or "",
        safety_cars=row["safety_cars"] or 0,
        first_team_to_pit=row["first_team_to_pit"] or "",
        confidence=row["confidence"] or 50,
        is_locked=True,
        submitted_at=str(row["submitted_at"]) if row["submitted_at"] else None,
    )


@router.get("/picks/{race_name}", response_model=RacePicksResponse)
async def get_picks(race_name: str, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]

    with get_db_connection() as conn:
        row = conn.execute(
            "SELECT * FROM user_race_picks WHERE user_id = ? AND race_name = ?",
            (user_id, race_name),
        ).fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="No prediction found.")

    return RacePicksResponse(
        race_name=row["race_name"],
        race_date=row["race_date"] or "",
        podium_p1=row["podium_p1"] or "",
        podium_p2=row["podium_p2"] or "",
        podium_p3=row["podium_p3"] or "",
        pole_sitter=row["pole_sitter"] or "",
        fastest_lap=row["fastest_lap"] or "",
        safety_cars=row["safety_cars"] or 0,
        first_team_to_pit=row["first_team_to_pit"] or "",
        confidence=row["confidence"] or 50,
        is_locked=bool(row["is_locked"]),
        submitted_at=str(row["submitted_at"]) if row["submitted_at"] else None,
    )
