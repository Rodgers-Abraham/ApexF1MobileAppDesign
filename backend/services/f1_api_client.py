import time
import requests
from datetime import datetime, timezone

SPORTRADAR_BASE = "https://api.sportradar.com/formula1/trial/v2/en"
SEASON_2026_ID = "sr:stage:1285547"

TEAM_NAME_MAP = {
    "Mercedes AMG Motorsport": "Mercedes",
    "Oracle Red Bull Racing": "Red Bull Racing",
    "Red Bull Racing": "Red Bull Racing",
    "McLaren Racing": "McLaren",
    "McLaren F1 Team": "McLaren",
    "Scuderia Ferrari HP": "Ferrari",
    "Scuderia Ferrari": "Ferrari",
    "BWT Alpine F1 Team": "Alpine",
    "Alpine F1 Team": "Alpine",
    "Aston Martin Aramco F1 Team": "Aston Martin",
    "Aston Martin F1 Team": "Aston Martin",
    "MoneyGram Haas F1 Team": "Haas",
    "Haas F1 Team": "Haas",
    "Visa Cash App RB F1 Team": "Racing Bulls",
    "Racing Bulls": "Racing Bulls",
    "Williams Racing": "Williams",
    "Stake F1 Team Kick Sauber": "Audi",
    "Audi F1 Team": "Audi",
    "Cadillac F1 Team": "Cadillac",
}


def _normalize_team(name: str) -> str:
    return TEAM_NAME_MAP.get(name, name)


def _reverse_name(name: str) -> str:
    """Convert 'LastName, FirstName' to 'FirstName LastName'."""
    if "," in name:
        parts = name.split(",", 1)
        return f"{parts[1].strip()} {parts[0].strip()}"
    return name


class F1ApiClient:
    def __init__(self):
        self._cache = {}
        self._api_key = None

    @property
    def cache(self):
        return self._cache

    def _get_api_key(self) -> str:
        if self._api_key is None:
            try:
                from core.config import get_settings
                self._api_key = get_settings().sportradar_api_key or ""
            except Exception:
                self._api_key = ""
        return self._api_key

    def _get_cached(self, key: str):
        if key in self._cache:
            expiry, data = self._cache[key]
            if time.time() < expiry:
                return data
        return None

    def _set_cache(self, key: str, data, duration_sec: int):
        self._cache[key] = (time.time() + duration_sec, data)

    def _sportradar_get(self, path: str):
        api_key = self._get_api_key()
        if not api_key:
            print("Sportradar API key not configured")
            return None
        sep = "&" if "?" in path else "?"
        url = f"{SPORTRADAR_BASE}/{path}{sep}api_key={api_key}"
        try:
            resp = requests.get(url, timeout=10)
            if resp.status_code == 200:
                return resp.json()
            print(f"Sportradar {path}: HTTP {resp.status_code}")
        except Exception as e:
            print(f"Sportradar {path} error: {e}")
        return None

    def _get_season_summary(self, season_id: str = SEASON_2026_ID):
        cache_key = f"season_summary_{season_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        data = self._sportradar_get(f"sport_events/{season_id}/summary.json")
        if data and "stage" in data:
            self._set_cache(cache_key, data["stage"], 1800)
            return data["stage"]
        return None

    # ------------------------------------------------------------------
    # STANDINGS
    # ------------------------------------------------------------------

    def get_driver_standings(self):
        cache_key = "driver_standings"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        summary = self._get_season_summary()
        if not summary or "competitors" not in summary:
            return []

        formatted = []
        for c in summary["competitors"]:
            result = c.get("result", {})
            pos = result.get("position")
            if pos is None:
                continue
            team = c.get("team", {})
            formatted.append({
                "pos": str(pos),
                "name": _reverse_name(c.get("name", "")),
                "team": _normalize_team(team.get("name", "")),
                "pts": str(result.get("points", 0)),
                "wins": str(result.get("victories", 0)),
            })

        formatted.sort(key=lambda x: int(x["pos"]))
        self._set_cache(cache_key, formatted, 3600)
        return formatted

    def get_constructor_standings(self):
        cache_key = "constructor_standings"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        summary = self._get_season_summary()
        if not summary or "teams" not in summary:
            return []

        formatted = []
        for t in summary["teams"]:
            result = t.get("result", {})
            pos = result.get("position")
            if pos is None:
                continue
            formatted.append({
                "pos": str(pos),
                "name": _normalize_team(t.get("name", "")),
                "pts": str(result.get("points", 0)),
                "wins": str(result.get("victories", 0)),
            })

        formatted.sort(key=lambda x: int(x["pos"]))
        self._set_cache(cache_key, formatted, 3600)
        return formatted

    # ------------------------------------------------------------------
    # CALENDAR
    # ------------------------------------------------------------------

    def get_calendar(self, year: int = 2026):
        cache_key = f"calendar_{year}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        season_id = self._resolve_season_id(year)
        if not season_id:
            return []

        summary = self._get_season_summary(season_id)
        if not summary or "stages" not in summary:
            return []

        races = []
        for idx, stage in enumerate(summary["stages"]):
            if stage.get("status") == "Cancelled":
                continue
            venue = stage.get("venue", {})
            desc = stage.get("description", "")
            gp_name = desc.replace(f" {year}", "").strip()
            length_m = venue.get("length", 0)
            turns = (venue.get("curves_right", 0) or 0) + (venue.get("curves_left", 0) or 0)

            races.append({
                "name": gp_name,
                "circuit": venue.get("name", ""),
                "country_code": venue.get("country_code", ""),
                "date": stage.get("scheduled", "")[:10],
                "round": str(idx + 1),
                "length_km": round(length_m / 1000, 3) if length_m else 0.0,
                "turns": turns,
                "drs_zones": self._estimate_drs_zones(turns),
            })

        self._set_cache(cache_key, races, 21600)
        return races

    def _estimate_drs_zones(self, turns: int) -> int:
        if turns >= 16:
            return 3
        if turns >= 10:
            return 2
        return 1

    # ------------------------------------------------------------------
    # SEASONS & HISTORY
    # ------------------------------------------------------------------

    def _resolve_season_id(self, year: int) -> str | None:
        seasons = self.get_all_seasons()
        for s in seasons:
            if s.get("season") == str(year):
                return s.get("_stage_id")
        return SEASON_2026_ID if year == 2026 else None

    def get_all_seasons(self):
        cache_key = "all_seasons"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        data = self._sportradar_get("seasons.json")
        if not data or "stages" not in data:
            return []

        seasons = []
        for s in data["stages"]:
            desc = s.get("description", "")
            year_str = desc.replace("Formula 1 ", "").strip()
            seasons.append({
                "season": year_str,
                "url": f"https://sportradar.com/formula1/{year_str}",
                "_stage_id": s.get("id", ""),
            })

        seasons.sort(key=lambda x: x["season"], reverse=True)
        self._set_cache(cache_key, seasons, 86400)
        return seasons

    def get_season_results(self, year: int):
        cache_key = f"season_results_{year}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        season_id = self._resolve_season_id(year)
        if not season_id:
            return []

        summary = self._get_season_summary(season_id)
        if not summary or "stages" not in summary:
            return []

        results = []
        for idx, stage in enumerate(summary["stages"]):
            if stage.get("status") != "Closed":
                continue
            desc = stage.get("description", "")
            gp_name = desc.replace(f" {year}", "").strip()
            venue = stage.get("venue", {})

            event_data = self._sportradar_get(f"sport_events/{stage['id']}/summary.json")
            winner = None
            if event_data and "stage" in event_data:
                competitors = event_data["stage"].get("competitors", [])
                for c in competitors:
                    r = c.get("result", {})
                    if r.get("position") == 1:
                        team = c.get("team", {})
                        winner = {
                            "driver": _reverse_name(c.get("name", "")),
                            "constructor": _normalize_team(team.get("name", "")),
                            "laps": str(venue.get("laps", "")),
                            "time": None,
                        }
                        break

            results.append({
                "round": str(idx + 1),
                "race_name": gp_name,
                "circuit_name": venue.get("name"),
                "locality": venue.get("city"),
                "country": venue.get("country"),
                "date": stage.get("scheduled", "")[:10],
                "winner": winner,
            })

        self._set_cache(cache_key, results, 3600)
        return results

    def get_race_details(self, race_name: str):
        cache_key = f"race_details_{race_name}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        summary = self._get_season_summary()
        if not summary or "stages" not in summary:
            return self._empty_race_details(race_name)

        target = None
        for idx, stage in enumerate(summary["stages"]):
            desc = stage.get("description", "").lower()
            if race_name.lower() in desc or desc.replace(" 2026", "") in race_name.lower():
                target = (idx, stage)
                break

        if not target:
            for idx, stage in enumerate(summary["stages"]):
                venue = stage.get("venue", {})
                if race_name.lower() in venue.get("name", "").lower():
                    target = (idx, stage)
                    break

        if not target:
            return self._empty_race_details(race_name)

        idx, stage = target
        venue = stage.get("venue", {})
        is_completed = stage.get("status") == "Closed"
        desc = stage.get("description", "")
        gp_name = desc.replace(" 2026", "").strip()

        winner_name = None
        winner_team = None
        if is_completed:
            event_data = self._sportradar_get(f"sport_events/{stage['id']}/summary.json")
            if event_data and "stage" in event_data:
                for c in event_data["stage"].get("competitors", []):
                    r = c.get("result", {})
                    if r.get("position") == 1:
                        winner_name = _reverse_name(c.get("name", ""))
                        winner_team = _normalize_team(c.get("team", {}).get("name", ""))
                        break

        length_m = venue.get("length", 0)
        turns = (venue.get("curves_right", 0) or 0) + (venue.get("curves_left", 0) or 0)

        details = {
            "race_name": gp_name,
            "round": str(idx + 1),
            "circuit_name": venue.get("name", ""),
            "location": f"{venue.get('city', '')}, {venue.get('country', '')}",
            "country_code": venue.get("country_code", ""),
            "is_completed": is_completed,
            "winner_name": winner_name,
            "winner_team": winner_team,
            "total_laps": venue.get("laps"),
            "fastest_lap_time": None,
            "fastest_lap_driver": None,
            "fastest_pitstop_team": None,
            "fastest_pitstop_time": None,
            "driver_of_the_day": None,
            "circuit_length_km": round(length_m / 1000, 3) if length_m else None,
            "turns": turns if turns else None,
            "drs_zones": self._estimate_drs_zones(turns) if turns else None,
        }

        self._set_cache(cache_key, details, 3600)
        return details

    def _empty_race_details(self, race_name: str):
        return {
            "race_name": race_name,
            "round": "0",
            "circuit_name": "",
            "location": "",
            "country_code": "",
            "is_completed": False,
            "winner_name": None,
            "winner_team": None,
            "total_laps": None,
            "fastest_lap_time": None,
            "fastest_lap_driver": None,
            "fastest_pitstop_team": None,
            "fastest_pitstop_time": None,
            "driver_of_the_day": None,
            "circuit_length_km": None,
            "turns": None,
            "drs_zones": None,
        }

    def get_circuit_history(self, race_or_circuit_name: str):
        cache_key = f"circuit_history_{race_or_circuit_name}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        recent_winners = []
        seasons_to_check = [2026, 2025, 2024, 2023, 2022]
        for year in seasons_to_check:
            season_id = self._resolve_season_id(year)
            if not season_id:
                continue
            summary = self._get_season_summary(season_id)
            if not summary or "stages" not in summary:
                continue
            for stage in summary["stages"]:
                if stage.get("status") != "Closed":
                    continue
                desc = stage.get("description", "").lower()
                venue_name = stage.get("venue", {}).get("name", "").lower()
                if race_or_circuit_name.lower() not in desc and race_or_circuit_name.lower() not in venue_name:
                    continue
                event_data = self._sportradar_get(f"sport_events/{stage['id']}/summary.json")
                if event_data and "stage" in event_data:
                    for c in event_data["stage"].get("competitors", []):
                        r = c.get("result", {})
                        if r.get("position") == 1:
                            recent_winners.append({
                                "year": str(year),
                                "driver": _reverse_name(c.get("name", "")),
                                "constructor": _normalize_team(c.get("team", {}).get("name", "")),
                            })
                            break
                break

        most_wins_driver = ""
        most_wins_constructor = ""
        if recent_winners:
            from collections import Counter
            driver_counts = Counter(w["driver"] for w in recent_winners)
            constructor_counts = Counter(w["constructor"] for w in recent_winners)
            most_wins_driver = driver_counts.most_common(1)[0][0]
            most_wins_constructor = constructor_counts.most_common(1)[0][0]

        result = {
            "circuit_id": race_or_circuit_name.lower().replace(" ", "_"),
            "race_name": race_or_circuit_name,
            "first_held": recent_winners[-1]["year"] if recent_winners else "Unknown",
            "total_races_held": len(recent_winners),
            "most_wins_driver": most_wins_driver,
            "most_wins_constructor": most_wins_constructor,
            "recent_winners": recent_winners,
        }

        self._set_cache(cache_key, result, 3600)
        return result

    def search_history(self, query: str):
        cache_key = f"search_{query}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        q = query.lower().strip()
        results = {"type": "search", "query": query, "matches": []}

        if q.isdigit() and 2007 <= int(q) <= 2027:
            year = int(q)
            races = self.get_season_results(year)
            results["matches"] = [{"type": "season", "year": q, "races": races}]
        else:
            summary = self._get_season_summary()
            if summary and "stages" in summary:
                for stage in summary["stages"]:
                    desc = stage.get("description", "").lower()
                    venue = stage.get("venue", {})
                    venue_name = venue.get("name", "").lower()
                    city = venue.get("city", "").lower()
                    country = venue.get("country", "").lower()
                    if q in desc or q in venue_name or q in city or q in country:
                        results["matches"].append({
                            "type": "race",
                            "name": stage.get("description", ""),
                            "circuit": venue.get("name", ""),
                            "city": venue.get("city", ""),
                            "country": venue.get("country", ""),
                            "date": stage.get("scheduled", "")[:10],
                            "status": stage.get("status", ""),
                        })

            if summary and "competitors" in summary:
                for c in summary["competitors"]:
                    name = _reverse_name(c.get("name", ""))
                    abbr = c.get("abbreviation", "").lower()
                    team_name = _normalize_team(c.get("team", {}).get("name", ""))
                    if q in name.lower() or q == abbr or q in team_name.lower():
                        r = c.get("result", {})
                        results["matches"].append({
                            "type": "driver",
                            "name": name,
                            "team": team_name,
                            "position": r.get("position"),
                            "points": r.get("points", 0),
                        })

        self._set_cache(cache_key, results, 600)
        return results

    # ------------------------------------------------------------------
    # SESSION STATUS
    # ------------------------------------------------------------------

    def get_latest_session_key(self, year: int = 2026):
        return None

    def get_session_status(self):
        cache_key = "session_status"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        summary = self._get_season_summary()
        if not summary or "stages" not in summary:
            return self._default_session_status()

        now = datetime.now(timezone.utc)
        current_race = None
        next_race = None

        for stage in summary["stages"]:
            status = stage.get("status", "")
            if status == "Cancelled":
                continue
            try:
                start = datetime.fromisoformat(stage["scheduled"].replace("+00:00", "+00:00"))
                end = datetime.fromisoformat(stage["scheduled_end"].replace("+00:00", "+00:00"))
                if not start.tzinfo:
                    start = start.replace(tzinfo=timezone.utc)
                if not end.tzinfo:
                    end = end.replace(tzinfo=timezone.utc)
            except (KeyError, ValueError):
                continue

            if start <= now <= end:
                current_race = stage
                break
            if start > now and next_race is None:
                next_race = stage

        if current_race:
            venue = current_race.get("venue", {})
            desc = current_race.get("description", "").replace(" 2026", "")
            result = {
                "is_live": True,
                "is_race_weekend": True,
                "session_name": "Race Weekend",
                "meeting_name": desc,
                "circuit_name": venue.get("name", ""),
                "location": f"{venue.get('city', '')}, {venue.get('country', '')}",
                "status_message": f"{desc} is live",
                "date_start": current_race.get("scheduled", ""),
                "date_end": current_race.get("scheduled_end", ""),
                "next_session_name": "",
                "next_session_meeting": "",
                "next_session_date": "",
                "next_session_circuit": "",
                "seconds_until_next": 0,
            }
            self._set_cache(cache_key, result, 60)
            return result

        if next_race:
            venue = next_race.get("venue", {})
            desc = next_race.get("description", "").replace(" 2026", "")
            try:
                start = datetime.fromisoformat(next_race["scheduled"].replace("+00:00", "+00:00"))
                if not start.tzinfo:
                    start = start.replace(tzinfo=timezone.utc)
                seconds_until = max(0, int((start - now).total_seconds()))
            except (KeyError, ValueError):
                seconds_until = 0

            result = {
                "is_live": False,
                "is_race_weekend": False,
                "session_name": "",
                "meeting_name": "",
                "circuit_name": "",
                "location": "",
                "status_message": f"Next: {desc}",
                "date_start": "",
                "date_end": "",
                "next_session_name": "Race Weekend",
                "next_session_meeting": desc,
                "next_session_date": next_race.get("scheduled", ""),
                "next_session_circuit": venue.get("name", ""),
                "seconds_until_next": seconds_until,
            }
            self._set_cache(cache_key, result, 300)
            return result

        return self._default_session_status()

    def _default_session_status(self):
        return {
            "is_live": False,
            "is_race_weekend": False,
            "session_name": "",
            "meeting_name": "",
            "circuit_name": "",
            "location": "",
            "status_message": "No upcoming sessions",
            "date_start": "",
            "date_end": "",
            "next_session_name": "",
            "next_session_meeting": "",
            "next_session_date": "",
            "next_session_circuit": "",
            "seconds_until_next": 0,
        }

    # ------------------------------------------------------------------
    # LIVE DATA — not available on Sportradar trial tier
    # ------------------------------------------------------------------

    def get_live_telemetry(self):
        return []

    def get_race_flag_status(self, session_key: int = None):
        return {
            "flag": "GREEN",
            "title": "TRACK CLEAR",
            "message": "All sectors clear for racing",
            "safety_car_active": False,
            "vsc_active": False,
            "red_flag_active": False,
            "yellow_flag_active": False,
            "active_sector": 0,
        }

    def get_team_radio(self, session_key: int = None):
        return []

    def get_race_events(self, session_key: int = None):
        return []

    def get_live_news(self):
        return []

    def get_track_conditions(self):
        return {
            "track_temperature": "",
            "air_temperature": "",
            "humidity": "",
            "wind_speed": "",
            "wind_direction": "",
            "rainfall": False,
            "pressure": "",
            "track_status": "",
            "session_name": "",
            "circuit_name": "",
            "summary": "No live track conditions available",
        }

    def get_tire_strategy(self):
        return {
            "session_key": 0,
            "total_stints": 0,
            "strategies": [],
        }

    def get_race_replay(self, meeting_name: str, lap: int = 1):
        return {
            "meeting_name": meeting_name,
            "circuit_name": "",
            "current_lap": lap,
            "total_laps": 0,
            "is_completed": False,
            "telemetry": [],
            "flag_status": {
                "flag": "GREEN",
                "title": "TRACK CLEAR",
                "message": "No replay data available",
                "safety_car_active": False,
                "vsc_active": False,
                "red_flag_active": False,
                "yellow_flag_active": False,
                "active_sector": 0,
            },
        }


f1_api_client = F1ApiClient()
