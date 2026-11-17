import os
import sys

import firebase_admin.auth as fb_auth
import pytest
from fastapi.testclient import TestClient

# Add backend directory to system path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.database import get_db_connection
from main import app
from services.gemini_pool import gemini_pool

client = TestClient(app)


@pytest.fixture(autouse=True)
def run_around_tests():
    yield


# ─── Helpers ──────────────────────────────────────────────────────────────────


def _insert_test_user(firebase_uid: str, email: str = "test@f1apex.com") -> int:
    """Insert a test user and return their id."""
    with get_db_connection() as conn:
        conn.execute(
            "INSERT INTO users (firebase_uid, email, name, favourite_team) VALUES (?, ?, ?, ?)",
            (firebase_uid, email, "Test Driver", "Ferrari"),
        )
        conn.commit()
        row = conn.execute(
            "SELECT id FROM users WHERE firebase_uid = ?", (firebase_uid,)
        ).fetchone()
    return row["id"]


def _delete_test_user(firebase_uid: str) -> None:
    with get_db_connection() as conn:
        conn.execute("DELETE FROM users WHERE firebase_uid = ?", (firebase_uid,))
        conn.commit()


# ─── Health ───────────────────────────────────────────────────────────────────


def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


# ─── Firebase auth tests ──────────────────────────────────────────────────────


def test_get_me_valid_token(monkeypatch):
    uid = "test-uid-me-valid"
    _insert_test_user(uid)
    try:
        monkeypatch.setattr(
            fb_auth, "verify_id_token", lambda token, **kw: {"uid": uid}
        )
        res = client.get("/api/auth/me", headers={"Authorization": "Bearer fake-token"})
        assert res.status_code == 200
        assert res.json()["email"] == "test@f1apex.com"
    finally:
        _delete_test_user(uid)


def test_get_me_expired_token(monkeypatch):
    def _raise(_token, **kw):
        raise fb_auth.ExpiredIdTokenError("expired", cause=None)

    monkeypatch.setattr(fb_auth, "verify_id_token", _raise)
    res = client.get("/api/auth/me", headers={"Authorization": "Bearer expired-token"})
    assert res.status_code == 401
    assert res.json()["detail"]["code"] == "TOKEN_EXPIRED"


def test_get_me_missing_token():
    res = client.get("/api/auth/me")
    assert res.status_code == 401
    assert res.json()["detail"]["code"] == "AUTH_HEADER_MISSING"


def test_get_me_wrong_project(monkeypatch):
    def _raise(_token, **kw):
        raise fb_auth.InvalidIdTokenError("wrong project")

    monkeypatch.setattr(fb_auth, "verify_id_token", _raise)
    res = client.get("/api/auth/me", headers={"Authorization": "Bearer bad-token"})
    assert res.status_code == 401
    assert res.json()["detail"]["code"] == "INVALID_TOKEN"


def test_delete_account_cascades(monkeypatch):
    uid = "test-uid-delete"
    user_id = _insert_test_user(uid)
    with get_db_connection() as conn:
        conn.execute(
            "INSERT INTO user_race_picks "
            "(user_id, race_name, race_date, podium_p1, podium_p2, podium_p3, pole_sitter, fastest_lap) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (user_id, "Test GP", "2026-01-01", "VER", "NOR", "LEC", "VER", "NOR"),
        )
        conn.commit()

    monkeypatch.setattr(fb_auth, "verify_id_token", lambda token, **kw: {"uid": uid})
    res = client.delete(
        "/api/auth/delete", headers={"Authorization": "Bearer fake-token"}
    )
    assert res.status_code == 200

    with get_db_connection() as conn:
        picks = conn.execute(
            "SELECT * FROM user_race_picks WHERE user_id = ?", (user_id,)
        ).fetchall()
    assert len(picks) == 0


# ─── Chatbot ──────────────────────────────────────────────────────────────────


def test_chatbot_endpoint(monkeypatch):
    def mock_generate_content(contents, system_instruction, temperature):
        user_message = contents[-1]["parts"][0]["text"].lower()
        if "recipe" in user_message or "cake" in user_message:
            return "I'm sorry, I am programmed strictly as a Formula 1 assistant. I cannot provide cooking recipes."
        return "Lewis Hamilton has won 7 World Championships. [Ergast API]"

    monkeypatch.setattr(gemini_pool, "generate_content", mock_generate_content)

    f1_res = client.post(
        "/api/chat", json={"message": "How many championships has Lewis Hamilton won?"}
    )
    assert f1_res.status_code == 200
    assert "7 World Championships" in f1_res.json()["response"]
    assert "[Ergast API]" in f1_res.json()["response"]

    bad_res = client.post(
        "/api/chat", json={"message": "Give me a recipe for a chocolate cake."}
    )
    assert bad_res.status_code == 200
    assert "strictly as a Formula 1 assistant" in bad_res.json()["response"]


# ─── Predictor ────────────────────────────────────────────────────────────────


def test_predictor_endpoint(monkeypatch):
    from ml.predictor import ml_predictor

    def mock_predict_probabilities(features):
        return [
            {"driver_name": f["driver_name"], "probability": 25.0} for f in features
        ]

    monkeypatch.setattr(
        ml_predictor, "predict_probabilities", mock_predict_probabilities
    )

    uid = "test-uid-predictor"
    _insert_test_user(uid)
    monkeypatch.setattr(fb_auth, "verify_id_token", lambda token, **kw: {"uid": uid})
    headers = {"Authorization": "Bearer fake-token"}

    # 1. Test predictor without auth -> 401
    res_no_auth = client.post(
        "/api/predictor/predict", json={"race_name": "Monaco GP", "condition": "Dry"}
    )
    assert res_no_auth.status_code == 401

    # 2. Test predictor with valid auth -> 200
    res_pro = client.post(
        "/api/predictor/predict",
        json={"race_name": "Monaco GP", "condition": "Dry"},
        headers=headers,
    )
    assert res_pro.status_code == 200
    data = res_pro.json()
    assert data["race_name"] == "Monaco GP"
    assert len(data["predictions"]) > 0
    assert data["predictions"][0]["probability"] == 25.0

    _delete_test_user(uid)
