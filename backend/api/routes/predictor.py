from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List
from core.auth import get_current_user
from ml.predictor import ml_predictor

router = APIRouter()

class PredictionRequest(BaseModel):
  race_name: str
  condition: str # Dry, Wet, Damp

class DriverProbability(BaseModel):
  driver_name: str
  probability: float

class PredictionResponse(BaseModel):
  race_name: str
  condition: str
  predictions: List[DriverProbability]

# Current active driver baseline statistics for 2026 season simulation
ACTIVE_DRIVERS = [
  {"driver_name": "Max Verstappen", "constructor_rank": 1, "average_finish": 2.1, "championship_points": 219, "home_country": "Netherlands"},
  {"driver_name": "Lando Norris", "constructor_rank": 3, "average_finish": 3.2, "championship_points": 150, "home_country": "United Kingdom"},
  {"driver_name": "Charles Leclerc", "constructor_rank": 2, "average_finish": 3.5, "championship_points": 148, "home_country": "Monaco"},
  {"driver_name": "Carlos Sainz", "constructor_rank": 2, "average_finish": 4.1, "championship_points": 116, "home_country": "Spain"},
  {"driver_name": "Oscar Piastri", "constructor_rank": 3, "average_finish": 5.9, "championship_points": 87, "home_country": "Australia"},
  {"driver_name": "George Russell", "constructor_rank": 4, "average_finish": 6.1, "championship_points": 81, "home_country": "United Kingdom"},
  {"driver_name": "Lewis Hamilton", "constructor_rank": 4, "average_finish": 6.8, "championship_points": 70, "home_country": "United Kingdom"},
  {"driver_name": "Fernando Alonso", "constructor_rank": 5, "average_finish": 8.9, "championship_points": 41, "home_country": "Spain"},
]

@router.post("/predict", response_model=PredictionResponse)
async def predict_endpoint(request: PredictionRequest, current_user: dict = Depends(get_current_user)):
  # Check if user is Pro
  if not current_user.get("is_pro", False):
    raise HTTPException(
      status_code=403, 
      detail={"error": "F1 predictions are only available for Apex Pro subscribers.", "code": "PRO_SUBSCRIPTION_REQUIRED"}
    )

  features = []
  for idx, driver in enumerate(ACTIVE_DRIVERS):
    # Determine grid starting position simulation:
    # Normally closely matches qualifying average finish, but let's add some race-specific logic
    grid_pos = idx + 1 # 1 to 8 starting grid order based on standings
    
    # Determine home race flag
    is_home = 0
    if request.race_name.lower().startswith("monaco") and driver["home_country"] == "Monaco":
      is_home = 1
      grid_pos = 1 # Leclerc pole position at Monaco
    elif request.race_name.lower().startswith("british") and driver["home_country"] == "United Kingdom":
      is_home = 1
      
    avg_finish = driver["average_finish"]
    
    # Condition impact:
    # Wet track increases variance/chaos. Drivers further back might have higher simulation chances.
    if request.condition.lower() == "wet":
      # Wet track chaos: slightly worsen front-runners avg_finish and improve wet-weather experts
      if driver["driver_name"] in ["Lewis Hamilton", "Max Verstappen", "Lando Norris"]:
        avg_finish -= 0.5 # Better handling
      else:
        avg_finish += 1.0 # Worsened handling
    elif request.condition.lower() == "damp":
      avg_finish += 0.2

    features.append({
      "driver_name": driver["driver_name"],
      "grid_position": grid_pos,
      "constructor_rank": driver["constructor_rank"],
      "average_finish": avg_finish,
      "championship_points": driver["championship_points"],
      "home_race": is_home
    })

  try:
    predictions = ml_predictor.predict_probabilities(features)
    # Map to response format
    res_preds = [
      DriverProbability(driver_name=p["driver_name"], probability=p["probability"])
      for p in predictions
    ]
    return PredictionResponse(
      race_name=request.race_name,
      condition=request.condition,
      predictions=res_preds
    )
  except Exception as e:
    raise HTTPException(
      status_code=500,
      detail={"error": f"ML Prediction engine failed: {str(e)}", "code": "PREDICTOR_FAILED"}
    )
