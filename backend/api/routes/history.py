from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from services.f1_api_client import f1_api_client

router = APIRouter()

class SeasonItem(BaseModel):
    season: str
    url: Optional[str] = None

class WinnerInfo(BaseModel):
    driver: Optional[str] = None
    constructor: Optional[str] = None
    laps: Optional[str] = None
    time: Optional[str] = None

class HistoricalRaceItem(BaseModel):
    round: str
    race_name: str
    circuit_name: Optional[str] = None
    locality: Optional[str] = None
    country: Optional[str] = None
    date: Optional[str] = None
    winner: Optional[WinnerInfo] = None

class RecentWinnerItem(BaseModel):
    year: str
    driver: str
    constructor: str

class CircuitHistoryResponse(BaseModel):
    circuit_id: str
    race_name: str
    first_held: str
    total_races_held: int
    most_wins_driver: str
    most_wins_constructor: str
    recent_winners: List[RecentWinnerItem]

@router.get("/seasons", response_model=List[SeasonItem])
async def get_all_seasons_endpoint():
    """Retrieve all 77 Formula 1 World Championship seasons (1950 to 2026)."""
    return f1_api_client.get_all_seasons()

@router.get("/season/{year}/races", response_model=List[HistoricalRaceItem])
async def get_season_races_endpoint(year: int):
    """Retrieve all Grand Prix race results for any historical season (1950 to 2026)."""
    if year < 1950 or year > 2026:
        raise HTTPException(status_code=400, detail="Year must be between 1950 and 2026.")
    return f1_api_client.get_season_results(year)

@router.get("/circuit/{race_name}", response_model=CircuitHistoryResponse)
async def get_circuit_history_endpoint(race_name: str):
    """Retrieve complete all-time historical archive for a specific circuit from 1950 to 2026."""
    return f1_api_client.get_circuit_history(race_name)

@router.get("/search")
async def search_history_endpoint(q: str):
    """Smart multi-category search endpoint for circuits, 3-letter codes, drivers, teams, and years."""
    return f1_api_client.search_history(q)

