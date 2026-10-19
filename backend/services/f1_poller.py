import json
import random
import requests
from datetime import datetime
from core.database import get_db_connection
from ml.predictor import ml_predictor

# Baseline 2026 season drivers and constructor/performance data for ML features
DRIVERS_2026 = [
    {"driver_name": "Kimi Antonelli", "constructor_rank": 1, "average_finish": 1.8, "championship_points": 156, "home_country": "Italy", "team": "Mercedes"},
    {"driver_name": "Lewis Hamilton", "constructor_rank": 2, "average_finish": 2.5, "championship_points": 115, "home_country": "United Kingdom", "team": "Ferrari"},
    {"driver_name": "George Russell", "constructor_rank": 1, "average_finish": 3.1, "championship_points": 106, "home_country": "United Kingdom", "team": "Mercedes"},
    {"driver_name": "Max Verstappen", "constructor_rank": 4, "average_finish": 4.2, "championship_points": 85, "home_country": "Netherlands", "team": "Red Bull"},
    {"driver_name": "Lando Norris", "constructor_rank": 3, "average_finish": 4.5, "championship_points": 81, "home_country": "United Kingdom", "team": "McLaren"},
    {"driver_name": "Charles Leclerc", "constructor_rank": 2, "average_finish": 4.8, "championship_points": 75, "home_country": "Monaco", "team": "Ferrari"},
    {"driver_name": "Oscar Piastri", "constructor_rank": 3, "average_finish": 5.5, "championship_points": 60, "home_country": "Australia", "team": "McLaren"},
    {"driver_name": "Pierre Gasly", "constructor_rank": 5, "average_finish": 8.2, "championship_points": 37, "home_country": "France", "team": "Alpine"},
    {"driver_name": "Liam Lawson", "constructor_rank": 6, "average_finish": 8.9, "championship_points": 31, "home_country": "New Zealand", "team": "RB"},
    {"driver_name": "Franco Colapinto", "constructor_rank": 5, "average_finish": 9.5, "championship_points": 20, "home_country": "Argentina", "team": "Alpine"},
    {"driver_name": "Oliver Bearman", "constructor_rank": 7, "average_finish": 11.2, "championship_points": 12, "home_country": "United Kingdom", "team": "Haas"},
    {"driver_name": "Arvid Lindblad", "constructor_rank": 6, "average_finish": 11.8, "championship_points": 10, "home_country": "United Kingdom", "team": "RB"},
    {"driver_name": "Esteban Ocon", "constructor_rank": 7, "average_finish": 12.1, "championship_points": 9, "home_country": "France", "team": "Haas"},
    {"driver_name": "Carlos Sainz", "constructor_rank": 8, "average_finish": 12.5, "championship_points": 8, "home_country": "Spain", "team": "Williams"},
    {"driver_name": "Alex Albon", "constructor_rank": 8, "average_finish": 13.2, "championship_points": 3, "home_country": "Thailand", "team": "Williams"},
    {"driver_name": "Gabriel Bortoleto", "constructor_rank": 9, "average_finish": 14.5, "championship_points": 2, "home_country": "Brazil", "team": "Audi"},
    {"driver_name": "Fernando Alonso", "constructor_rank": 10, "average_finish": 14.9, "championship_points": 1, "home_country": "Spain", "team": "Aston Martin"},
    {"driver_name": "Nico Hülkenberg", "constructor_rank": 9, "average_finish": 15.5, "championship_points": 0, "home_country": "Germany", "team": "Audi"},
    {"driver_name": "Lance Stroll", "constructor_rank": 10, "average_finish": 16.1, "championship_points": 0, "home_country": "Canada", "team": "Aston Martin"},
    {"driver_name": "Sergio Perez", "constructor_rank": 11, "average_finish": 16.8, "championship_points": 0, "home_country": "Mexico", "team": "Cadillac"},
    {"driver_name": "Valtteri Bottas", "constructor_rank": 11, "average_finish": 17.2, "championship_points": 0, "home_country": "Finland", "team": "Cadillac"},
]

WEEKENDS = ["Monaco Grand Prix", "Austrian Grand Prix", "British Grand Prix", "Italian Grand Prix"]

class F1PollerService:
    def __init__(self):
        pass

    def get_latest_session(self):
        """Returns the latest loaded session and results from the database."""
        with get_db_connection() as conn:
            row = conn.execute(
                "SELECT * FROM session_states ORDER BY id DESC LIMIT 1"
            ).fetchone()

        if not row:
            return None

        data = dict(row)
        data['results'] = json.loads(data['results_json'])
        return data

    def get_latest_prediction(self, session_key: int):
        """Returns the latest auto-calculated predictions matching a session key."""
        with get_db_connection() as conn:
            row = conn.execute(
                "SELECT * FROM auto_predictions WHERE session_key = ? ORDER BY id DESC LIMIT 1",
                (session_key,)
            ).fetchone()

        if not row:
            return None

        data = dict(row)
        data['predictions'] = json.loads(data['predictions_json'])
        return data

    def trigger_auto_predictions(self, session_key: int, meeting_name: str, session_name: str, results: list):
        """
        Runs ML prediction engine dynamically based on the newly completed session results.
        Updates model inputs:
        - Practice: updates 'average_finish' based on results.
        - Qualifying: updates starting 'grid_position' based on results.
        - Sprint: updates 'championship_points' based on points won.
        """
        # Create map of current driver results
        driver_pos_map = {res['driver_name']: res['position'] for res in results}
        
        features = []
        for idx, base_driver in enumerate(DRIVERS_2026):
            name = base_driver["driver_name"]
            
            # 1. Start from base stats
            grid_pos = idx + 1 # Default grid based on standings
            avg_finish = base_driver["average_finish"]
            points = base_driver["championship_points"]
            is_home = 1 if meeting_name.lower().startswith(base_driver["home_country"].lower()) else 0
            
            # 2. Refine based on the session results
            if "Qualifying" in session_name:
                grid_pos = driver_pos_map.get(name, grid_pos)
            elif "Practice" in session_name:
                # Better practice position improves predicted average finish
                if name in driver_pos_map:
                    avg_finish = (avg_finish * 0.7) + (driver_pos_map[name] * 0.3)
            elif "Sprint" in session_name:
                # Add sprint points (8 to 1 pts for P1 to P8)
                pos = driver_pos_map.get(name, 20)
                if pos <= 8:
                    points += (9 - pos)

            features.append({
                "driver_name": name,
                "grid_position": grid_pos,
                "constructor_rank": base_driver["constructor_rank"],
                "average_finish": avg_finish,
                "championship_points": points,
                "home_race": is_home
            })

        # Run ML Ensemble Classifier
        raw_preds = ml_predictor.predict_probabilities(features)

        # Save to database using context manager
        with get_db_connection() as conn:
            conn.execute(
                "INSERT INTO auto_predictions (session_key, predictions_json) VALUES (?, ?)",
                (session_key, json.dumps(raw_preds))
            )
            conn.commit()

        return raw_preds

    def advance_simulation(self):
        """Stateless F1 race weekend simulator state machine."""
        latest = self.get_latest_session()
        
        if not latest:
            # First session: Practice 1 in Monaco GP
            next_meeting = WEEKENDS[0]
            next_session = "Practice 1"
            next_key = 1001
            date_str = datetime.now().isoformat()
        else:
            current_meeting = latest['meeting_name']
            current_session = latest['session_name']
            current_key = latest['session_key']
            
            if current_session == "Practice 1":
                next_meeting = current_meeting
                next_session = "Practice 2"
                next_key = current_key + 1
            elif current_session == "Practice 2":
                next_meeting = current_meeting
                next_session = "Qualifying"
                next_key = current_key + 1
            elif current_session == "Qualifying":
                next_meeting = current_meeting
                next_session = "Sprint"
                next_key = current_key + 1
            elif current_session == "Sprint":
                next_meeting = current_meeting
                next_session = "Race"
                next_key = current_key + 1
            else: # "Race" completes weekend, advance to next GP
                curr_idx = WEEKENDS.index(current_meeting)
                next_idx = (curr_idx + 1) % len(WEEKENDS)
                next_meeting = WEEKENDS[next_idx]
                next_session = "Practice 1"
                next_key = current_key + 10 # Shift keys per GP
            
            date_str = datetime.now().isoformat()

        # Generate simulated standings results for this session
        results = self._generate_simulated_results(next_session)
        
        # Save session results to SQLite using context manager
        with get_db_connection() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO session_states
                (session_key, meeting_name, session_name, session_type, status, date_start, results_json)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    next_key,
                    next_meeting,
                    next_session,
                    "practice" if "Practice" in next_session else next_session.lower(),
                    "completed",
                    date_str,
                    json.dumps(results)
                )
            )
            conn.commit()

        # Automatically run ML Predictions for the main race using this data!
        self.trigger_auto_predictions(next_key, next_meeting, next_session, results)
        
        return {
            "session_key": next_key,
            "meeting_name": next_meeting,
            "session_name": next_session,
            "results": results
        }

    def _generate_simulated_results(self, session_name: str) -> list:
        """Helper to generate realistic randomized F1 standings based on driver speed baselines."""
        driver_speeds = []
        for d in DRIVERS_2026:
            # Baseline speed is lower (better) avg finish + slight random noise
            noise = random.uniform(-1.2, 1.2)
            # Wet condition simulation logic could go here if needed
            speed = d["average_finish"] + noise
            driver_speeds.append((d, speed))
            
        # Sort by speed score (lower is faster)
        driver_speeds.sort(key=lambda x: x[1])
        
        results = []
        for pos_idx, (d, _) in enumerate(driver_speeds):
            pos = pos_idx + 1
            
            # Format time gap
            if pos == 1:
                time_gap = "1:14.350" if "Qualifying" in session_name or "Practice" in session_name else "1:28:44.201"
            else:
                gap_sec = (pos_idx * 0.15) + random.uniform(0.01, 0.05)
                time_gap = f"+{gap_sec:.3f}s"
                
            results.append({
                "position": pos,
                "driver_name": d["driver_name"],
                "team": d["team"],
                "time_or_gap": time_gap
            })
            
        return results

    def poll_openf1_api(self, year: int = 2026):
        """
        Polls the OpenF1 live API. 
        Filters by past sessions chronologically and checks the last 3 past sessions for results.
        If no results are available for the year, falls back to the previous year recursively.
        """
        if year < 2023:
            return False
            
        try:
            sessions_url = f"https://api.openf1.org/v1/sessions?year={year}"
            resp = requests.get(sessions_url, timeout=5)
            sessions = resp.json()
            
            # If the response is not a list, or it's empty, try previous year
            if not isinstance(sessions, list) or len(sessions) == 0:
                print(f"No sessions found for year {year}, falling back to {year - 1}")
                return self.poll_openf1_api(year - 1)
                
            # Filter sessions that start in the past relative to current system time
            now_iso = datetime.now().isoformat()
            past_sessions = [s for s in sessions if s.get("date_start", "") < now_iso]
            
            if not past_sessions:
                print(f"No past sessions found for year {year}, falling back to {year - 1}")
                return self.poll_openf1_api(year - 1)
                
            latest_session = None
            res_data = None
            
            # Check the last 3 past sessions backwards (checking too many will hit rate limits)
            check_count = 0
            for s in reversed(past_sessions):
                if check_count >= 3:
                    break
                check_count += 1
                
                session_key = s.get("session_key")
                res_url = f"https://api.openf1.org/v1/session_result?session_key={session_key}"
                res_resp = requests.get(res_url, timeout=5)
                
                if res_resp.status_code == 200:
                    data = res_resp.json()
                    if isinstance(data, list) and len(data) > 0:
                        latest_session = s
                        res_data = data
                        break
            
            if not latest_session or not res_data:
                print(f"No completed session results found in the last few past sessions of year {year}, falling back to {year - 1}")
                return self.poll_openf1_api(year - 1)
                
            session_key = latest_session.get("session_key")
            
            # Map country name to GP meeting name if meeting_name is missing/unknown
            meeting_name = latest_session.get("meeting_name")
            if not meeting_name or meeting_name == "Unknown GP":
                country = latest_session.get("country_name", "Unknown")
                if country == "Austria":
                    meeting_name = "Austrian Grand Prix"
                elif country in ["Great Britain", "United Kingdom", "UK"]:
                    meeting_name = "British Grand Prix"
                elif country == "Italy":
                    meeting_name = "Italian Grand Prix"
                elif country == "Monaco":
                    meeting_name = "Monaco Grand Prix"
                else:
                    meeting_name = f"{country} Grand Prix" if country != "Unknown" else "Unknown Grand Prix"
                    
            session_name = latest_session.get("session_name", "Race")
            
            # Format results list
            results = []
            # Sort by position
            res_data.sort(key=lambda x: x.get("position", 99))
            
            for res in res_data[:20]: # Limit to top 20
                pos = res.get("position")
                num = res.get("driver_number")
                
                # Fetch driver details for team name mapping
                driver_name = res.get("broadcast_name", f"Driver #{num}")
                # Clean name (broadcast name is usually like 'M VERSTAPPEN')
                # Try to map to 2026 drivers if possible
                matched_name = driver_name
                team_name = "Unknown Team"
                
                for d in DRIVERS_2026:
                    # check match (e.g. 'HAM' in 'Lewis Hamilton' or initials)
                    last_name = d["driver_name"].split(" ")[-1].upper()
                    if last_name in driver_name.upper():
                        matched_name = d["driver_name"]
                        team_name = d["team"]
                        break
                
                # Simple time formatting
                gap = "+0.000s" if pos == 1 else f"+{pos * 0.2:.3f}s"
                
                results.append({
                    "position": pos,
                    "driver_name": matched_name,
                    "team": team_name,
                    "time_or_gap": gap
                })
                
            # Save session to SQLite using context manager
            with get_db_connection() as conn:
                conn.execute(
                    """
                    INSERT OR REPLACE INTO session_states
                    (session_key, meeting_name, session_name, session_type, status, date_start, results_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        session_key,
                        meeting_name,
                        session_name,
                        latest_session.get("session_type", "race"),
                        "completed",
                        latest_session.get("date_start", datetime.now().isoformat()),
                        json.dumps(results)
                    )
                )
                conn.commit()

            # Automatically run ML Predictions
            self.trigger_auto_predictions(session_key, meeting_name, session_name, results)
            return True

        except Exception as e:
            print(f"Failed polling OpenF1 API: {e}")
            return False

    def poll_jolpica_api(self):
        """
        Polls the Jolpica F1 API for the latest completed session results (Qualifying or Race).
        Uses this as the default API for results.
        """
        try:
            # 1. Fetch latest Qualifying results
            q_url = "https://api.jolpi.ca/ergast/f1/current/last/qualifying.json"
            q_resp = requests.get(q_url, timeout=5)
            q_data = q_resp.json() if q_resp.status_code == 200 else {}
            
            # 2. Fetch latest Race results
            r_url = "https://api.jolpi.ca/ergast/f1/current/last/results.json"
            r_resp = requests.get(r_url, timeout=5)
            r_data = r_resp.json() if r_resp.status_code == 200 else {}
            
            q_races = q_data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
            r_races = r_data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
            
            if not q_races and not r_races:
                return False
                
            q_race = q_races[0] if q_races else None
            r_race = r_races[0] if r_races else None
            
            q_round = int(q_race.get("round", 0)) if q_race else 0
            r_round = int(r_race.get("round", 0)) if r_race else 0
            
            # Determine which session is latest
            if q_race and (q_round > r_round):
                # Qualifying is latest
                target_race = q_race
                session_name = "Qualifying"
                session_type = "qualifying"
                raw_results = target_race.get("QualifyingResults", [])
                date_start = target_race.get("date", "") + "T14:00:00Z"
            else:
                # Race is latest
                target_race = r_race
                session_name = "Race"
                session_type = "race"
                raw_results = target_race.get("Results", [])
                date_start = target_race.get("date", "") + "T13:00:00Z"
                
            if not target_race or not raw_results:
                return False
                
            meeting_name = target_race.get("raceName", "Unknown Grand Prix")
            round_num = target_race.get("round", "1")
            
            # Format session key
            # Qualifying gets round_num * 100, Race gets round_num * 100 + 1
            session_key = int(round_num) * 100
            if session_name == "Race":
                session_key += 1
                
            # Format results
            results = []
            for pos_idx, item in enumerate(raw_results[:20]):
                pos = pos_idx + 1
                driver = item.get("Driver", {})
                constructor = item.get("Constructor", {})
                
                driver_name = f"{driver.get('givenName', '')} {driver.get('familyName', '')}".strip()
                team_name = constructor.get("name", "Unknown Team")
                
                # Check mapping for DRIVERS_2026
                for d in DRIVERS_2026:
                    if driver.get("familyName", "").upper() in d["driver_name"].upper():
                        driver_name = d["driver_name"]
                        team_name = d["team"]
                        break
                        
                if session_name == "Qualifying":
                    # Qualifying results use Q3/Q2/Q1 times
                    q3 = item.get("Q3")
                    q2 = item.get("Q2")
                    q1 = item.get("Q1")
                    time_str = q3 or q2 or q1 or f"+{pos * 0.15:.3f}s"
                else:
                    # Race results
                    time_str = item.get("Time", {}).get("time", f"+{pos * 0.5:.3f}s") if pos > 1 else "1:28:44.201"
                    
                results.append({
                    "position": pos,
                    "driver_name": driver_name,
                    "team": team_name,
                    "time_or_gap": time_str
                })
                
            # Save session to SQLite using context manager
            with get_db_connection() as conn:
                conn.execute(
                    """
                    INSERT OR REPLACE INTO session_states
                    (session_key, meeting_name, session_name, session_type, status, date_start, results_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        session_key,
                        meeting_name,
                        session_name,
                        session_type,
                        "completed",
                        date_start,
                        json.dumps(results)
                    )
                )
                conn.commit()

            # Automatically run ML Predictions for this session
            self.trigger_auto_predictions(session_key, meeting_name, session_name, results)
            print(f"Successfully polled Jolpica API (default) and populated {meeting_name} {session_name}")
            return True

        except Exception as e:
            print(f"Failed polling Jolpica API: {e}")
            return False

f1_poller = F1PollerService()
