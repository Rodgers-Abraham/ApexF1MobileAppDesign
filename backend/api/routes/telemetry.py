from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import List
from services.f1_api_client import f1_api_client

router = APIRouter()

class LiveDriverStanding(BaseModel):
    pos: str
    name: str
    team: str
    pts: str
    wins: str

class LiveConstructorStanding(BaseModel):
    pos: str
    name: str
    pts: str
    wins: str

class LiveDriverTelemetry(BaseModel):
    pos: str
    name: str
    driver_number: int = 0
    team: str = "F1 Team"
    gap: str
    interval: str = "-"
    positions_gained: int = 0
    status: str = "ON TRACK"
    dnf_reason: str = ""
    tyre: str
    tyreLife: str
    last_lap: str = ""
    best_lap: str = ""
    pit_stops: int = 0
    drs: bool = False
    speed: str
    gear: str
    color: str
    x: float
    y: float

class RaceFlagStatus(BaseModel):
    flag: str = "GREEN"
    title: str = "TRACK CLEAR"
    message: str = "All sectors clear for racing"
    safety_car_active: bool = False
    vsc_active: bool = False
    red_flag_active: bool = False
    yellow_flag_active: bool = False
    active_sector: int = 0

class TeamRadioItem(BaseModel):
    id: str
    driver_number: int
    driver_name: str
    team: str
    color: str
    timestamp: str
    audio_url: str
    transcript: str

class RaceEventItem(BaseModel):
    id: str
    event_type: str
    category: str
    message: str
    driver_name: str
    team: str
    timestamp: str
    lap_number: int
    lap_time: str

class LiveNewsItem(BaseModel):
    title: str
    summary: str
    url: str
    source: str
    published_at: str
    image_url: str

class SessionStatusResponse(BaseModel):
    is_live: bool
    is_race_weekend: bool
    session_name: str
    meeting_name: str
    circuit_name: str
    location: str
    status_message: str
    date_start: str
    date_end: str
    next_session_name: str
    next_session_meeting: str
    next_session_date: str
    next_session_circuit: str
    seconds_until_next: int

@router.get("/session-status", response_model=SessionStatusResponse)
async def get_session_status_endpoint():
    status = f1_api_client.get_session_status()
    return SessionStatusResponse(**status)

@router.get("/live-standings/drivers", response_model=List[LiveDriverStanding])
async def get_live_driver_standings_endpoint():
    standings = f1_api_client.get_driver_standings()
    return [LiveDriverStanding(**s) for s in standings]

@router.get("/live-standings/constructors", response_model=List[LiveConstructorStanding])
async def get_live_constructor_standings_endpoint():
    standings = f1_api_client.get_constructor_standings()
    return [LiveConstructorStanding(**s) for s in standings]

@router.get("/telemetry/live", response_model=List[LiveDriverTelemetry])
async def get_live_telemetry_endpoint():
    telemetry = f1_api_client.get_live_telemetry()
    return [LiveDriverTelemetry(**t) for t in telemetry]

@router.get("/race-control/status", response_model=RaceFlagStatus)
@router.get("/race-flags", response_model=RaceFlagStatus)
async def get_race_flag_status_endpoint():
    status = f1_api_client.get_race_flag_status()
    return RaceFlagStatus(**status)

@router.get("/team-radio", response_model=List[TeamRadioItem])
async def get_team_radio_endpoint():
    radios = f1_api_client.get_team_radio()
    return [TeamRadioItem(**r) for r in radios]

@router.get("/race-events", response_model=List[RaceEventItem])
async def get_race_events_endpoint():
    events = f1_api_client.get_race_events()
    return [RaceEventItem(**e) for e in events]

@router.get("/news/live", response_model=List[LiveNewsItem])
async def get_live_news_endpoint():
    news = f1_api_client.get_live_news()
    return [LiveNewsItem(**n) for n in news]

class TrackConditionsResponse(BaseModel):
    track_temperature: str
    air_temperature: str
    humidity: str
    wind_speed: str
    wind_direction: str
    rainfall: bool
    pressure: str
    track_status: str
    session_name: str
    circuit_name: str
    summary: str

class CompoundStrategyItem(BaseModel):
    compound: str
    laps: int
    avg_laps: int
    stints_count: int
    color: str

class TireStrategyResponse(BaseModel):
    session_key: int
    total_stints: int
    strategies: List[CompoundStrategyItem]

@router.get("/track-conditions", response_model=TrackConditionsResponse)
@router.get("/telemetry/track-conditions", response_model=TrackConditionsResponse)
async def get_track_conditions_endpoint():
    data = f1_api_client.get_track_conditions()
    return TrackConditionsResponse(**data)

@router.get("/tire-strategy", response_model=TireStrategyResponse)
@router.get("/telemetry/tire-strategy", response_model=TireStrategyResponse)
async def get_tire_strategy_endpoint():
    data = f1_api_client.get_tire_strategy()
    return TireStrategyResponse(**data)



