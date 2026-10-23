import pytest
from fastapi.testclient import TestClient
import os
import sys
import json

# Add backend directory to system path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from services.f1_poller import f1_poller
from core.database import get_db_connection

client = TestClient(app)

@pytest.fixture(autouse=True)
def clean_sessions_db(monkeypatch):
    # Mock poll_openf1_api and poll_jolpica_api on the class and instance to keep tests hermetic
    from services.f1_poller import F1PollerService, f1_poller
    monkeypatch.setattr(F1PollerService, "poll_openf1_api", lambda *args, **kwargs: False)
    monkeypatch.setattr(F1PollerService, "poll_jolpica_api", lambda *args, **kwargs: False)
    monkeypatch.setattr(f1_poller, "poll_openf1_api", lambda *args, **kwargs: False)
    monkeypatch.setattr(f1_poller, "poll_jolpica_api", lambda *args, **kwargs: False)
    from services.f1_api_client import f1_api_client
    monkeypatch.setattr(f1_api_client, "get_session_status", lambda: {"is_live": False, "is_race_weekend": False})
    try:
        import api.routes.sessions as routes_sessions
        monkeypatch.setattr(routes_sessions.f1_api_client, "get_session_status", lambda: {"is_live": False, "is_race_weekend": False})
        monkeypatch.setattr(routes_sessions.f1_poller, "poll_openf1_api", lambda *args, **kwargs: False)
        monkeypatch.setattr(routes_sessions.f1_poller, "poll_jolpica_api", lambda *args, **kwargs: False)
    except Exception:
        pass
    
    # Setup: Clean tables before test runs
    with get_db_connection() as conn:
        conn.execute("DELETE FROM session_states")
        conn.execute("DELETE FROM auto_predictions")
        conn.commit()
    yield

def test_simulation_workflow():
    # 1. Verify initially database is empty, but calling /latest auto-populates Practice 1
    res = client.get("/api/sessions/latest")
    assert res.status_code == 200
    data = res.json()
    assert data["session_name"] == "Practice 1"
    assert data["meeting_name"] == "Monaco Grand Prix"
    assert len(data["results"]) == 21
    
    # 2. Advance simulation -> Practice 2
    res_sim = client.post("/api/sessions/simulate")
    assert res_sim.status_code == 200
    data_sim = res_sim.json()
    assert data_sim["session_name"] == "Practice 2"
    assert data_sim["meeting_name"] == "Monaco Grand Prix"
    
    # 3. Advance simulation -> Qualifying
    res_sim2 = client.post("/api/sessions/simulate")
    assert res_sim2.status_code == 200
    assert res_sim2.json()["session_name"] == "Qualifying"

def test_predictions_endpoint():
    # Generate a user session
    import random
    rand_id = random.randint(1000, 9999)
    email = f"session_tester_{rand_id}@f1apex.com"
    password = "testpassword"
    
    # Register and get token
    reg_res = client.post("/api/auth/register", json={"email": email, "password": password})
    token = reg_res.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 1. Fetch latest session to ensure DB is populated
    client.get("/api/sessions/latest")
    
    # 2. Query /predictions without Pro tier -> 403
    res_free = client.get("/api/sessions/predictions", headers=headers)
    assert res_free.status_code == 403
    
    # 3. Upgrade user to Pro
    client.put("/api/auth/pro", json={"is_pro": True}, headers=headers)
    
    # 4. Query /predictions with Pro tier -> 200
    res_pro = client.get("/api/sessions/predictions", headers=headers)
    assert res_pro.status_code == 200
    pred_data = res_pro.json()
    assert "predictions" in pred_data
    assert len(pred_data["predictions"]) == 21
    assert pred_data["predictions"][0]["probability"] > 0.0

def test_race_details_endpoint():
    res_monaco = client.get("/api/sessions/race-details/Monaco GP")
    assert res_monaco.status_code == 200
    data_monaco = res_monaco.json()
    assert data_monaco["winner_name"] == "Charles Leclerc"
    assert data_monaco["driver_of_the_day"] == "Charles Leclerc"

    res_singapore = client.get("/api/sessions/race-details/Singapore GP")
    assert res_singapore.status_code == 200
    data_singapore = res_singapore.json()
    assert "Max Verstappen" in data_singapore["winner_name"]
    assert "Max Verstappen" in data_singapore["driver_of_the_day"]

