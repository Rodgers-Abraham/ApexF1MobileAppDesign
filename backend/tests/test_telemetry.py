import pytest
from fastapi.testclient import TestClient
import os
import sys

# Add backend directory to system path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from services.f1_api_client import f1_api_client

client = TestClient(app)

def test_live_driver_standings_endpoint(monkeypatch):
    # Mock f1_api_client.get_driver_standings
    def mock_get_driver_standings():
        return [
            {"pos": "1", "name": "Kimi Antonelli", "team": "Mercedes", "pts": "156", "wins": "4"},
            {"pos": "2", "name": "Lewis Hamilton", "team": "Ferrari", "pts": "115", "wins": "2"}
        ]
    monkeypatch.setattr(f1_api_client, "get_driver_standings", mock_get_driver_standings)

    res = client.get("/api/f1/live-standings/drivers")
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 2
    assert data[0]["name"] == "Kimi Antonelli"
    assert data[0]["pts"] == "156"

def test_live_constructor_standings_endpoint(monkeypatch):
    # Mock f1_api_client.get_constructor_standings
    def mock_get_constructor_standings():
        return [
            {"pos": "1", "name": "Mercedes", "pts": "262", "wins": "5"},
            {"pos": "2", "name": "Ferrari", "pts": "190", "wins": "2"}
        ]
    monkeypatch.setattr(f1_api_client, "get_constructor_standings", mock_get_constructor_standings)

    res = client.get("/api/f1/live-standings/constructors")
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 2
    assert data[0]["name"] == "Mercedes"
    assert data[0]["pts"] == "262"

def test_live_telemetry_endpoint():
    # Execute actual endpoint call (uses OpenF1 live session data or resilient fallback)
    res = client.get("/api/f1/telemetry/live")
    assert res.status_code == 200
    data = res.json()
    assert len(data) >= 5
    assert "name" in data[0]
    assert "speed" in data[0]
    assert "x" in data[0]
    assert "y" in data[0]

def test_live_news_endpoint():
    res = client.get("/api/f1/news/live")
    assert res.status_code == 200
    data = res.json()
    assert len(data) > 0
    assert "title" in data[0]
    assert "url" in data[0]
    assert "source" in data[0]

def test_session_status_endpoint():
    res = client.get("/api/f1/session-status")
    assert res.status_code == 200
    data = res.json()
    assert "is_live" in data
    assert "is_race_weekend" in data
    assert "status_message" in data
    assert "next_session_name" in data

def test_track_conditions_endpoint():
    res = client.get("/api/f1/telemetry/track-conditions")
    assert res.status_code == 200
    data = res.json()
    assert "track_temperature" in data
    assert "air_temperature" in data
    assert "humidity" in data
    assert "wind_speed" in data
    assert "track_status" in data

def test_tire_strategy_endpoint():
    res = client.get("/api/f1/telemetry/tire-strategy")
    assert res.status_code == 200
    data = res.json()
    assert "strategies" in data
    assert len(data["strategies"]) > 0
    assert "compound" in data["strategies"][0]
    assert "laps" in data["strategies"][0]


