import pytest
from fastapi.testclient import TestClient
import os
import sys

# Add backend directory to system path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from services.gemini_pool import gemini_pool

client = TestClient(app)

# Cleanup SQLite database before/after tests if it exists
@pytest.fixture(autouse=True)
def run_around_tests():
  # We use the db for testing, but let's make sure users are unique per test run
  yield
  # If we wanted to clean up between tests, we could run SQL deletes here

def test_read_root():
  response = client.get("/")
  assert response.status_code == 200
  assert response.json()["status"] == "healthy"

def test_auth_flow():
  import random
  # Create a random email to prevent unique constraint failures on consecutive test runs
  rand_id = random.randint(1000, 9999)
  email = f"user_{rand_id}@f1apex.com"
  password = "SuperPassword123!"
  
  # 1. Register User
  reg_payload = {
    "email": email,
    "password": password,
    "favourite_team": "Aston Martin"
  }
  reg_res = client.post("/api/auth/register", json=reg_payload)
  assert reg_res.status_code == 200
  reg_data = reg_res.json()
  assert "token" in reg_data
  assert reg_data["email"] == email
  assert reg_data["favourite_team"] == "Aston Martin"
  assert reg_data["is_pro"] is False
  
  # 2. Login User (Success)
  login_payload = {
    "email": email,
    "password": password
  }
  login_res = client.post("/api/auth/login", json=login_payload)
  assert login_res.status_code == 200
  token = login_res.json()["token"]
  
  # 3. Login User (Failure)
  bad_login = {
    "email": email,
    "password": "WrongPassword"
  }
  bad_res = client.post("/api/auth/login", json=bad_login)
  assert bad_res.status_code == 401
  
  # 4. Get Profile (/me)
  headers = {"Authorization": f"Bearer {token}"}
  me_res = client.get("/api/auth/me", headers=headers)
  assert me_res.status_code == 200
  me_data = me_res.json()
  assert me_data["email"] == email
  assert me_data["favourite_team"] == "Aston Martin"
  assert me_data["is_pro"] is False

  # 5. Update Theme Preference
  theme_res = client.put("/api/auth/theme", json={"favourite_team": "McLaren"}, headers=headers)
  assert theme_res.status_code == 200
  assert theme_res.json()["favourite_team"] == "McLaren"

  # 6. Update Pro Status
  pro_res = client.put("/api/auth/pro", json={"is_pro": True}, headers=headers)
  assert pro_res.status_code == 200
  assert pro_res.json()["is_pro"] is True

  # 7. Update Profile (Name & Driver & Password Reset)
  profile_payload = {
    "name": "John Doe",
    "favourite_driver": "Kimi Antonelli",
    "new_password": "NewSuperPassword321!"
  }
  profile_res = client.put("/api/auth/profile", json=profile_payload, headers=headers)
  assert profile_res.status_code == 200
  profile_data = profile_res.json()
  assert profile_data["name"] == "John Doe"
  assert profile_data["favourite_driver"] == "Kimi Antonelli"

  # 8. Verify login with NEW password
  new_login_payload = {
    "email": email,
    "password": "NewSuperPassword321!"
  }
  new_login_res = client.post("/api/auth/login", json=new_login_payload)
  assert new_login_res.status_code == 200


def test_chatbot_endpoint(monkeypatch):
  # Mock generate_content call on the global gemini_pool
  def mock_generate_content(contents, system_instruction, temperature):
    # Check if user message contains F1 keywords or general off-topic questions
    user_message = contents[-1]["parts"][0]["text"].lower()
    if "recipe" in user_message or "cake" in user_message:
      return "I'm sorry, I am programmed strictly as a Formula 1 assistant. I cannot provide cooking recipes."
    return "Lewis Hamilton has won 7 World Championships. [Ergast API]"

  monkeypatch.setattr(gemini_pool, "generate_content", mock_generate_content)

  # Test F1 Query
  f1_payload = {
    "message": "How many championships has Lewis Hamilton won?"
  }
  f1_res = client.post("/api/chat", json=f1_payload)
  assert f1_res.status_code == 200
  assert "7 World Championships" in f1_res.json()["response"]
  assert "[Ergast API]" in f1_res.json()["response"]

  # Test Non-F1 Query
  bad_payload = {
    "message": "Give me a recipe for a chocolate cake."
  }
  bad_res = client.post("/api/chat", json=bad_payload)
  assert bad_res.status_code == 200
  assert "strictly as a Formula 1 assistant" in bad_res.json()["response"]


def test_predictor_endpoint(monkeypatch):
  from ml.predictor import ml_predictor

  # Mock predict_probabilities of ml_predictor
  def mock_predict_probabilities(features):
    return [{"driver_name": f["driver_name"], "probability": 25.0} for f in features]

  monkeypatch.setattr(ml_predictor, "predict_probabilities", mock_predict_probabilities)

  # Create a user session
  import random
  rand_id = random.randint(10000, 99999)
  email = f"tester_{rand_id}@f1apex.com"
  password = "testpassword"

  # Register user
  reg_res = client.post("/api/auth/register", json={"email": email, "password": password})
  token = reg_res.json()["token"]
  headers = {"Authorization": f"Bearer {token}"}

  # 1. Test predictor without auth -> 401
  res_no_auth = client.post("/api/predictor/predict", json={"race_name": "Monaco GP", "condition": "Dry"})
  assert res_no_auth.status_code == 401

  # 2. Test predictor with Free tier -> 403
  res_free = client.post("/api/predictor/predict", json={"race_name": "Monaco GP", "condition": "Dry"}, headers=headers)
  assert res_free.status_code == 403

  # 3. Upgrade user to Pro
  client.put("/api/auth/pro", json={"is_pro": True}, headers=headers)

  # 4. Test predictor with Pro tier -> 200
  res_pro = client.post("/api/predictor/predict", json={"race_name": "Monaco GP", "condition": "Dry"}, headers=headers)
  assert res_pro.status_code == 200
  data = res_pro.json()
  assert data["race_name"] == "Monaco GP"
  assert len(data["predictions"]) > 0
  assert data["predictions"][0]["probability"] == 25.0

def test_delete_account():
  import random
  rand_id = random.randint(100000, 999999)
  email = f"delete_{rand_id}@f1apex.com"
  password = "Password123!"

  # 1. Register User
  reg_payload = {"email": email, "password": password}
  reg_res = client.post("/api/auth/register", json=reg_payload)
  assert reg_res.status_code == 200
  token = reg_res.json()["token"]
  headers = {"Authorization": f"Bearer {token}"}

  # 2. Delete Account
  del_res = client.delete("/api/auth/delete", headers=headers)
  assert del_res.status_code == 200
  assert del_res.json()["status"] == "success"

  # 3. Verify user is no longer authorized (should return 401 since user is deleted)
  me_res = client.get("/api/auth/me", headers=headers)
  assert me_res.status_code == 401


