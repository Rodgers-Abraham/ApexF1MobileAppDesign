from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from core.auth import get_current_user
from services.f1_poller import f1_poller

router = APIRouter()

class DriverStandingResponse(BaseModel):
    position: int
    driver_name: str
    team: str
    time_or_gap: str

class LatestSessionResponse(BaseModel):
    session_key: int
    meeting_name: str
    session_name: str
    session_type: str
    status: str
    date_start: str
    results: List[DriverStandingResponse]

class PredictionProbabilityResponse(BaseModel):
    driver_name: str
    probability: float

class SessionPredictionsResponse(BaseModel):
    session_key: int
    predictions: List[PredictionProbabilityResponse]

class RaceDetailsResponse(BaseModel):
    race_name: str
    round: str
    circuit_name: str
    location: str
    country_code: str
    is_completed: bool
    winner_name: Optional[str] = None
    winner_team: Optional[str] = None
    total_laps: Optional[int] = None
    fastest_lap_time: Optional[str] = None
    fastest_lap_driver: Optional[str] = None
    fastest_pitstop_team: Optional[str] = None
    fastest_pitstop_time: Optional[str] = None
    driver_of_the_day: Optional[str] = None
    circuit_length_km: Optional[float] = None
    turns: Optional[int] = None
    drs_zones: Optional[int] = None

@router.get("/latest", response_model=LatestSessionResponse)
async def get_latest_session_endpoint():
    latest = f1_poller.get_latest_session()
    # If missing or simulated session key, sync from authentic live APIs
    if not latest or (latest and 1000 <= latest.get("session_key", 0) <= 1050):
        success = f1_poller.poll_jolpica_api()
        if not success:
            success = f1_poller.poll_openf1_api()
        if success:
            latest = f1_poller.get_latest_session()

    if not latest:
        latest = f1_poller.advance_simulation()

    return LatestSessionResponse(
        session_key=latest["session_key"],
        meeting_name=latest["meeting_name"],
        session_name=latest["session_name"],
        session_type=latest.get("session_type", "practice"),
        status=latest.get("status", "completed"),
        date_start=latest.get("date_start", ""),
        results=[DriverStandingResponse(**r) for r in latest["results"]]
    )


@router.get("/predictions", response_model=SessionPredictionsResponse)
async def get_session_predictions_endpoint(session_key: Optional[int] = None, current_user: dict = Depends(get_current_user)):
    # Verify Pro tier
    if not current_user.get("is_pro", False):
        raise HTTPException(
            status_code=403,
            detail={"error": "F1 predictions are only available for Apex Pro subscribers.", "code": "PRO_SUBSCRIPTION_REQUIRED"}
        )

    latest = f1_poller.get_latest_session()
    if not latest:
        latest = f1_poller.advance_simulation()

    if session_key is None:
        session_key = latest["session_key"]

    pred_data = f1_poller.get_latest_prediction(session_key)
    if not pred_data:
        raw_preds = f1_poller.trigger_auto_predictions(session_key, latest["meeting_name"], latest["session_name"], latest["results"])
        predictions = [{"driver_name": p["driver_name"], "probability": p["probability"]} for p in raw_preds]
    else:
        predictions = pred_data["predictions"]

    return SessionPredictionsResponse(
        session_key=session_key,
        predictions=[PredictionProbabilityResponse(**p) for p in predictions]
    )

@router.post("/simulate", response_model=LatestSessionResponse)
async def simulate_session_endpoint():
    new_state = f1_poller.advance_simulation()
    return LatestSessionResponse(
        session_key=new_state["session_key"],
        meeting_name=new_state["meeting_name"],
        session_name=new_state["session_name"],
        session_type="practice" if "Practice" in new_state["session_name"] else new_state["session_name"].lower(),
        status="completed",
        date_start="",
        results=[DriverStandingResponse(**r) for r in new_state["results"]]
    )

@router.post("/poll")
async def poll_f1_api_endpoint():
    # Try Jolpica first (as the default API for results)
    success = f1_poller.poll_jolpica_api()
    if not success:
        # Fallback to OpenF1 if Jolpica fails
        success = f1_poller.poll_openf1_api()

    if not success:
        raise HTTPException(status_code=500, detail="Failed to retrieve live data from F1 APIs (Jolpica and OpenF1).")
    return {"message": "Successfully synchronized latest session results and triggered automated predictions."}

@router.get("/race-details/{race_name}", response_model=RaceDetailsResponse)
async def get_race_details_endpoint(race_name: str):
    from services.f1_api_client import f1_api_client
    details = f1_api_client.get_race_details(race_name)
    return RaceDetailsResponse(**details)
