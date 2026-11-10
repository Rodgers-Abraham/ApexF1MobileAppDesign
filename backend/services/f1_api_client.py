import time
import re
import xml.etree.ElementTree as ET
import urllib.request
from email.utils import parsedate_to_datetime
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


FALLBACK_2026_CALENDAR = [
    {"name": "Bahrain Grand Prix", "circuit": "Bahrain International Circuit", "country_code": "BHR", "date": "2026-03-01", "round": "1", "length_km": 5.412, "turns": 15, "drs_zones": 3},
    {"name": "Saudi Arabian Grand Prix", "circuit": "Jeddah Corniche Circuit", "country_code": "SAU", "date": "2026-03-08", "round": "2", "length_km": 6.174, "turns": 27, "drs_zones": 3},
    {"name": "Australian Grand Prix", "circuit": "Albert Park Circuit", "country_code": "AUS", "date": "2026-03-22", "round": "3", "length_km": 5.278, "turns": 16, "drs_zones": 3},
    {"name": "Japanese Grand Prix", "circuit": "Suzuka Circuit", "country_code": "JPN", "date": "2026-04-05", "round": "4", "length_km": 5.807, "turns": 18, "drs_zones": 2},
    {"name": "Chinese Grand Prix", "circuit": "Shanghai International Circuit", "country_code": "CHN", "date": "2026-04-19", "round": "5", "length_km": 5.451, "turns": 16, "drs_zones": 2},
    {"name": "Miami Grand Prix", "circuit": "Miami International Autodrome", "country_code": "USA", "date": "2026-05-03", "round": "6", "length_km": 5.412, "turns": 19, "drs_zones": 3},
    {"name": "Emilia Romagna Grand Prix", "circuit": "Autodromo Enzo e Dino Ferrari", "country_code": "ITA", "date": "2026-05-17", "round": "7", "length_km": 4.909, "turns": 19, "drs_zones": 1},
    {"name": "Monaco Grand Prix", "circuit": "Circuit de Monaco", "country_code": "MCO", "date": "2026-05-24", "round": "8", "length_km": 3.337, "turns": 19, "drs_zones": 1},
    {"name": "Spanish Grand Prix", "circuit": "Circuit de Barcelona-Catalunya", "country_code": "ESP", "date": "2026-06-07", "round": "9", "length_km": 4.675, "turns": 16, "drs_zones": 2},
    {"name": "Canadian Grand Prix", "circuit": "Circuit Gilles Villeneuve", "country_code": "CAN", "date": "2026-06-14", "round": "10", "length_km": 4.361, "turns": 14, "drs_zones": 2},
    {"name": "Austrian Grand Prix", "circuit": "Red Bull Ring", "country_code": "AUT", "date": "2026-06-28", "round": "11", "length_km": 4.318, "turns": 10, "drs_zones": 3},
    {"name": "British Grand Prix", "circuit": "Silverstone Circuit", "country_code": "GBR", "date": "2026-07-05", "round": "12", "length_km": 5.891, "turns": 18, "drs_zones": 2},
    {"name": "Belgian Grand Prix", "circuit": "Circuit de Spa-Francorchamps", "country_code": "BEL", "date": "2026-07-26", "round": "13", "length_km": 7.004, "turns": 19, "drs_zones": 2},
    {"name": "Hungarian Grand Prix", "circuit": "Hungaroring", "country_code": "HUN", "date": "2026-08-02", "round": "14", "length_km": 4.381, "turns": 14, "drs_zones": 2},
    {"name": "Dutch Grand Prix", "circuit": "Circuit Zandvoort", "country_code": "NLD", "date": "2026-08-30", "round": "15", "length_km": 4.259, "turns": 14, "drs_zones": 2},
    {"name": "Italian Grand Prix", "circuit": "Autodromo Nazionale di Monza", "country_code": "ITA", "date": "2026-09-06", "round": "16", "length_km": 5.793, "turns": 11, "drs_zones": 2},
    {"name": "Azerbaijan Grand Prix", "circuit": "Baku City Circuit", "country_code": "AZE", "date": "2026-09-20", "round": "17", "length_km": 6.003, "turns": 20, "drs_zones": 2},
    {"name": "Singapore Grand Prix", "circuit": "Marina Bay Street Circuit", "country_code": "SGP", "date": "2026-10-04", "round": "18", "length_km": 4.940, "turns": 23, "drs_zones": 3},
    {"name": "United States Grand Prix", "circuit": "Circuit of The Americas", "country_code": "USA", "date": "2026-10-18", "round": "19", "length_km": 5.513, "turns": 20, "drs_zones": 2},
    {"name": "Mexico City Grand Prix", "circuit": "Autodromo Hermanos Rodriguez", "country_code": "MEX", "date": "2026-10-25", "round": "20", "length_km": 4.304, "turns": 17, "drs_zones": 3},
    {"name": "São Paulo Grand Prix", "circuit": "Autodromo Jose Carlos Pace", "country_code": "BRA", "date": "2026-11-08", "round": "21", "length_km": 4.309, "turns": 15, "drs_zones": 2},
    {"name": "Las Vegas Grand Prix", "circuit": "Las Vegas Strip Circuit", "country_code": "USA", "date": "2026-11-21", "round": "22", "length_km": 6.201, "turns": 17, "drs_zones": 2},
    {"name": "Qatar Grand Prix", "circuit": "Lusail International Circuit", "country_code": "QAT", "date": "2026-11-29", "round": "23", "length_km": 5.380, "turns": 16, "drs_zones": 2},
    {"name": "Abu Dhabi Grand Prix", "circuit": "Yas Marina Circuit", "country_code": "UAE", "date": "2026-12-06", "round": "24", "length_km": 5.281, "turns": 16, "drs_zones": 2},
]


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

        def _fallback():
            if year == 2026:
                fb = [
                    {**r, "sessions": self._approx_sessions(r["date"])}
                    for r in FALLBACK_2026_CALENDAR
                ]
                self._set_cache(cache_key, fb, 21600)
                return fb
            return []

        season_id = self._resolve_season_id(year)
        if not season_id:
            return _fallback()

        summary = self._get_season_summary(season_id)
        if not summary or "stages" not in summary:
            return _fallback()

        races = []
        for idx, stage in enumerate(summary["stages"]):
            if stage.get("status") == "Cancelled":
                continue
            venue = stage.get("venue", {})
            desc = stage.get("description", "")
            gp_name = desc.replace(f" {year}", "").strip()
            length_m = venue.get("length", 0)
            turns = (venue.get("curves_right", 0) or 0) + (venue.get("curves_left", 0) or 0)

            race_date_str = stage.get("scheduled", "")[:10]
            races.append({
                "name": gp_name,
                "circuit": venue.get("name", ""),
                "country_code": venue.get("country_code", ""),
                "date": race_date_str,
                "round": str(idx + 1),
                "length_km": round(length_m / 1000, 3) if length_m else 0.0,
                "turns": turns,
                "drs_zones": self._estimate_drs_zones(turns),
                "sessions": self._approx_sessions(race_date_str),
            })

        if year == 2026:
            now_date = datetime.now(timezone.utc).date().isoformat()
            has_future = any(r["date"] >= now_date for r in races)
            if not races or not has_future:
                races = [
                    {**r, "sessions": self._approx_sessions(r["date"])}
                    for r in FALLBACK_2026_CALENDAR
                ]
        self._set_cache(cache_key, races, 21600)
        return races

    @staticmethod
    def _approx_sessions(race_date_str: str) -> list:
        """
        Compute approximate UTC session times from race date.
        Assumes race at 14:00 UTC; FP1/FP2 on Friday, FP3/Qualifying on Saturday.
        These are approximations — exact times vary by circuit and timezone.
        """
        try:
            from datetime import timedelta
            rd = datetime.strptime(race_date_str, "%Y-%m-%d").replace(
                hour=14, minute=0, second=0, microsecond=0, tzinfo=timezone.utc
            )
            return [
                {"name": "FP1",        "datetime": (rd - timedelta(days=2, hours=4)).isoformat()},
                {"name": "FP2",        "datetime": (rd - timedelta(days=2)).isoformat()},
                {"name": "FP3",        "datetime": (rd - timedelta(days=1, hours=4)).isoformat()},
                {"name": "Qualifying", "datetime": (rd - timedelta(days=1)).isoformat()},
                {"name": "Race",       "datetime": rd.isoformat()},
            ]
        except Exception:
            return []

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
        cache_key = "live_news"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        feeds = [
            ("https://www.autosport.com/rss/f1/news/", "AUTOSPORT"),
            ("https://www.motorsport.com/rss/f1/news/", "MOTORSPORT"),
        ]

        for feed_url, source in feeds:
            try:
                req = urllib.request.Request(feed_url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=6) as resp:
                    xml_content = resp.read()

                root = ET.fromstring(xml_content)
                channel = root.find("channel")
                items = channel.findall("item") if channel is not None else []

                news = []
                for item in items[:8]:
                    title = (item.findtext("title") or "").strip()
                    desc = re.sub(r"<[^>]+>", "", item.findtext("description") or "").strip()[:200]
                    link = (item.findtext("link") or "").strip()
                    pub_date = item.findtext("pubDate") or ""

                    image_url = ""
                    media_ns = "{http://search.yahoo.com/mrss/}"
                    thumb = item.find(f"{media_ns}thumbnail")
                    if thumb is not None:
                        image_url = thumb.get("url", "")
                    if not image_url:
                        enc = item.find("enclosure")
                        if enc is not None:
                            u = enc.get("url", "")
                            if any(ext in u.lower() for ext in ("jpg", "png", "jpeg", "webp")):
                                image_url = u

                    time_ago = ""
                    try:
                        dt = parsedate_to_datetime(pub_date)
                        diff = datetime.now(timezone.utc) - dt
                        if diff.days > 0:
                            time_ago = f"{diff.days}d ago"
                        elif diff.seconds // 3600 > 0:
                            time_ago = f"{diff.seconds // 3600}h ago"
                        else:
                            time_ago = f"{diff.seconds // 60}m ago"
                    except Exception:
                        pass

                    if title and link:
                        news.append({
                            "title": title,
                            "summary": desc,
                            "url": link,
                            "source": source,
                            "published_at": pub_date,
                            "image_url": image_url,
                            "time_ago": time_ago,
                            "category": "F1",
                        })

                if news:
                    self._set_cache(cache_key, news, 300)
                    return news
            except Exception as e:
                print(f"News RSS {feed_url} error: {e}")
                continue

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

    # ------------------------------------------------------------------
    # SESSION REPLAY — historical data via Jolpica/Ergast
    # ------------------------------------------------------------------

    JOLPICA_BASE = "https://api.jolpi.ca/ergast/f1"

    def _jolpica_get(self, path: str, retries: int = 1):
        url = f"{self.JOLPICA_BASE}/{path}"
        for attempt in range(retries + 1):
            try:
                resp = requests.get(url, timeout=15, headers={"Accept": "application/json"})
                if resp.status_code == 200:
                    return resp.json()
                if resp.status_code == 429:
                    wait = min(int(resp.headers.get("Retry-After", "3")), 5)
                    if attempt < retries:
                        time.sleep(wait)
                        continue
                    print(f"Jolpica {path}: rate limited (429) — skipping")
                    return None
                print(f"Jolpica {path}: HTTP {resp.status_code}")
            except Exception as e:
                print(f"Jolpica {path} error: {e}")
            break
        return None

    @staticmethod
    def _lap_ms(t: str) -> int:
        try:
            if ":" in t:
                m, s = t.split(":", 1)
                return int(int(m) * 60_000 + float(s) * 1000)
            return int(float(t) * 1000)
        except Exception:
            return 0

    @staticmethod
    def _q_secs(t: str) -> float:
        try:
            if ":" in t:
                m, s = t.split(":", 1)
                return int(m) * 60 + float(s)
            return float(t)
        except Exception:
            return float("inf")

    def _resolve_jolpica_round(self, year: int, race_name_hint: str) -> int | None:
        """Find the correct Jolpica round number for a race by matching its name."""
        cache_key = f"jolpica_rounds_{year}"
        cached = self._get_cached(cache_key)
        if cached is None:
            data = self._jolpica_get(f"{year}/races.json?limit=30")
            if not data:
                return None
            races = data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
            cached = races
            self._set_cache(cache_key, cached, 86400)

        for race in cached:
            race_name_full = race.get("raceName", "")
            circuit = race.get("Circuit", {}).get("circuitName", "")
            locality = race.get("Circuit", {}).get("Location", {}).get("locality", "")
            country = race.get("Circuit", {}).get("Location", {}).get("country", "")
            # Try each field with _name_matches
            for candidate in [race_name_full, circuit, locality, country]:
                if candidate and self._name_matches(candidate, race_name_hint):
                    return int(race.get("round", 0))
        return None

    _GP_PREFIXES = [
        "grand prix", "gran premio de la", "gran premio de los",
        "gran premio del", "gran premio de", "gran premio",
        "grosser preis von", "großer preis von",
        "prix de la", "prix du", "prix de",
    ]

    @classmethod
    def _name_matches(cls, actual: str, hint: str) -> bool:
        """True if the actual race name matches the hint (multilingual, tolerant)."""
        if not actual or not hint:
            return True  # no hint → don't reject

        def _strip(s: str) -> str:
            s = s.lower().strip()
            for prefix in cls._GP_PREFIXES:
                s = s.replace(prefix, "").strip()
            return s

        a = _strip(actual)
        h = _strip(hint)

        # Direct substring
        if h in a or a in h:
            return True

        # Word-level: any significant word (len>3) exactly in common
        h_words = {w for w in h.split() if len(w) > 3}
        a_words = {w for w in a.split() if len(w) > 3}
        if h_words & a_words:
            return True

        # Stem matching (5-char prefix): handles "mexican"↔"mexico", "brazilian"↔"brazil"
        for hw in h_words:
            for aw in a_words:
                min_len = min(len(hw), len(aw), 5)
                if min_len >= 5 and hw[:min_len] == aw[:min_len]:
                    return True
        return False

    def get_session_replay(self, year: int, round_num: int, session_type: str = "race", race_name: str = ""):
        # 1. Try Jolpica race list to get the authoritative round number.
        #    If the race list confirms the round, trust it and skip post-fetch check.
        round_verified_by_list = False
        if race_name:
            jolpica_round = self._resolve_jolpica_round(year, race_name)
            if jolpica_round:
                if jolpica_round != round_num:
                    print(f"Round correction for '{race_name}': {round_num} → {jolpica_round}")
                    round_num = jolpica_round
                round_verified_by_list = True

        cache_key = f"session_replay_{year}_{round_num}_{session_type}"
        cached = self._get_cached(cache_key)
        if cached is not None:
            # Accept cached data if round was verified, or names match
            if round_verified_by_list or not race_name or self._name_matches(cached.get("race_name", ""), race_name):
                return cached

        def _do(rnd):
            if session_type == "qualifying":
                return self._qualifying_replay(year, rnd)
            elif session_type == "sprint":
                return self._sprint_replay(year, rnd)
            return self._race_replay(year, rnd)

        result = _do(round_num)

        # 2. Post-fetch name verification — only needed when race list lookup failed
        if not round_verified_by_list and result and race_name and not self._name_matches(result.get("race_name", ""), race_name):
            print(f"Name mismatch: got '{result.get('race_name')}', wanted '{race_name}'. Trying ±1 round.")
            found = False
            for adj in [round_num + 1, round_num - 1]:
                if adj < 1 or adj > 30:
                    continue
                adj_result = _do(adj)
                if adj_result is None:
                    continue  # 429 or error — stop, don't burn more quota
                if self._name_matches(adj_result.get("race_name", ""), race_name):
                    print(f"Correct race found at round {adj}")
                    result = adj_result
                    # Cache under the corrected round key
                    self._set_cache(f"session_replay_{year}_{adj}_{session_type}", result, 86400 * 7)
                    # Also cache the round mapping so next time we hit the right round directly
                    self._set_cache(f"jolpica_round_{year}_{race_name.lower()[:20]}", adj, 86400 * 30)
                    return result
                # Got a different wrong race — stop immediately to conserve quota
                break
            if not found:
                # Return None so frontend shows "not available" rather than wrong race
                print(f"Could not confirm correct race for '{race_name}' — returning None to avoid wrong data")
                return None

        if result:
            self._set_cache(cache_key, result, 86400 * 7)
        return result

    def _fetch_all_laps_paginated(self, year: int, round_num: int) -> tuple:
        """
        Fetch all lap timing data. Returns (race_meta, all_laps_list).

        Jolpica counts individual timing entries (driver×lap), not laps.
        A 70-lap race with 20 drivers = 1400 entries. Using limit=2000 gets
        everything in a SINGLE request, avoiding rate-limit cascades.
        """
        all_laps = []
        race_meta = {}
        offset = 0
        per_page = 2000  # One shot: covers 100 laps × 20 drivers comfortably

        while True:
            data = self._jolpica_get(
                f"{year}/{round_num}/laps.json?limit={per_page}&offset={offset}"
            )
            if not data:
                break
            mr = data.get("MRData", {})
            total = int(mr.get("total", 0))
            races = mr.get("RaceTable", {}).get("Races", [])
            if not races:
                break
            if not race_meta:
                race_meta = races[0]
            laps = races[0].get("Laps", [])
            all_laps.extend(laps)
            offset += per_page
            if offset >= total or not laps:
                break

        return race_meta, all_laps

    def _race_replay(self, year: int, round_num: int):
        results_raw = self._jolpica_get(f"{year}/{round_num}/results.json")
        race_meta, all_lap_data = self._fetch_all_laps_paginated(year, round_num)

        if not all_lap_data or not results_raw:
            return None

        try:
            # Build driver map from results (also contains grid position)
            driver_info = {}
            grid_entries = []
            for r in results_raw["MRData"]["RaceTable"]["Races"][0].get("Results", []):
                d, c = r.get("Driver", {}), r.get("Constructor", {})
                did = d.get("driverId", "")
                grid_pos = int(r.get("grid", 99))
                info = {
                    "name": f"{d.get('givenName','')} {d.get('familyName','')}".strip(),
                    "code": d.get("code", did[:3].upper()),
                    "team": _normalize_team(c.get("name", "")),
                    "grid": grid_pos,
                }
                driver_info[did] = info
                grid_entries.append({
                    "pos": grid_pos,
                    "driver_id": did,
                    "name": info["name"],
                    "code": info["code"],
                    "team": info["team"],
                    "lap_time": "Grid",
                    "gap": "",
                    "interval": "",
                })

            # Sort grid by starting position
            grid_entries.sort(key=lambda x: x["pos"])

            cumulative = {}
            all_laps = []

            for lap in all_lap_data:
                lap_num = int(lap["number"])
                entries = {}
                for t in lap.get("Timings", []):
                    did = t["driverId"]
                    ms = self._lap_ms(t.get("time", ""))
                    cumulative[did] = cumulative.get(did, 0) + ms
                    entries[did] = {
                        "pos": int(t.get("position", 99)),
                        "driver_id": did,
                        "lap_time": t.get("time", ""),
                        "cum_ms": cumulative[did],
                    }

                sorted_e = sorted(entries.values(), key=lambda x: x["pos"])
                leader_ms = sorted_e[0]["cum_ms"] if sorted_e else 0

                positions = []
                for i, e in enumerate(sorted_e):
                    info = driver_info.get(e["driver_id"], {
                        "name": e["driver_id"].capitalize(),
                        "code": e["driver_id"][:3].upper(),
                        "team": "",
                    })
                    gap_ms = e["cum_ms"] - leader_ms
                    gap = "LEADER" if gap_ms == 0 else f"+{gap_ms/1000:.3f}s"
                    interval = "LEADER" if i == 0 else f"+{(e['cum_ms'] - sorted_e[i-1]['cum_ms'])/1000:.3f}s"

                    positions.append({
                        "pos": e["pos"],
                        "driver_id": e["driver_id"],
                        "name": info["name"],
                        "code": info["code"],
                        "team": info["team"],
                        "lap_time": e["lap_time"],
                        "gap": gap,
                        "interval": interval,
                    })

                all_laps.append({"lap": lap_num, "phase": "", "positions": positions})

            total_laps = max(l["lap"] for l in all_laps) if all_laps else 0

            # Prepend grid as lap 0
            result_laps = [{"lap": 0, "phase": "GRID", "positions": grid_entries}] + all_laps

            # Final classification from race results — always correct regardless of
            # how many laps we managed to fetch from the timing data.
            final_classification = []
            for r in results_raw["MRData"]["RaceTable"]["Races"][0].get("Results", []):
                d, c = r.get("Driver", {}), r.get("Constructor", {})
                did = d.get("driverId", "")
                info = driver_info.get(did, {
                    "name": f"{d.get('givenName','')} {d.get('familyName','')}".strip(),
                    "code": d.get("code", did[:3].upper()),
                    "team": _normalize_team(c.get("name", "")),
                })
                fl = r.get("FastestLap", {})
                final_classification.append({
                    "pos": r.get("position", ""),
                    "driver_id": did,
                    "name": info["name"],
                    "code": info["code"],
                    "team": info["team"],
                    "gap": r.get("Time", {}).get("time", r.get("status", "")),
                    "interval": "",
                    "lap_time": fl.get("Time", {}).get("time", ""),
                    "is_fastest_lap": fl.get("rank") == "1",
                    "status": r.get("status", "Finished"),
                    "total_laps_completed": r.get("laps", ""),
                })

            race_name = race_meta.get("raceName", "")
            circuit = race_meta.get("Circuit", {}).get("circuitName", "")

            return {
                "session_type": "race",
                "race_name": race_name,
                "circuit": circuit,
                "year": year,
                "round": round_num,
                "total_laps": total_laps,
                "laps": result_laps,
                "final_classification": final_classification,
            }
        except (KeyError, IndexError, ValueError) as e:
            print(f"Race replay parse error: {e}")
            return None

    def _qualifying_replay(self, year: int, round_num: int):
        data = self._jolpica_get(f"{year}/{round_num}/qualifying.json")
        if not data:
            return None

        try:
            races = data["MRData"]["RaceTable"].get("Races", [])
            if not races:
                return None
            race = races[0]
            raw = race.get("QualifyingResults", [])

            results = []
            for r in raw:
                d, c = r.get("Driver", {}), r.get("Constructor", {})
                results.append({
                    "pos": int(r.get("position", 99)),
                    "driver_id": d.get("driverId", ""),
                    "name": f"{d.get('givenName','')} {d.get('familyName','')}".strip(),
                    "code": d.get("code", ""),
                    "team": _normalize_team(c.get("name", "")),
                    "q1": r.get("Q1", ""), "q2": r.get("Q2", ""), "q3": r.get("Q3", ""),
                })

            all_laps = []
            for idx, (phase, key) in enumerate([("Q1", "q1"), ("Q2", "q2"), ("Q3", "q3")], start=1):
                phase_r = sorted(
                    [r for r in results if r[key]],
                    key=lambda x: self._q_secs(x[key]),
                )
                if not phase_r:
                    continue
                leader_secs = self._q_secs(phase_r[0][key])
                positions = []
                for i, r in enumerate(phase_r):
                    secs = self._q_secs(r[key])
                    gap = "POLE" if i == 0 else f"+{secs - leader_secs:.3f}s"
                    if i == 0:
                        interval = "POLE"
                    else:
                        prev_secs = self._q_secs(phase_r[i - 1][key])
                        interval = f"+{secs - prev_secs:.3f}s"
                    positions.append({
                        "pos": i + 1,
                        "driver_id": r["driver_id"],
                        "name": r["name"],
                        "code": r["code"],
                        "team": r["team"],
                        "lap_time": r[key],
                        "gap": gap,
                        "interval": interval,
                    })
                all_laps.append({"lap": idx, "phase": phase, "positions": positions})

            return {
                "session_type": "qualifying",
                "race_name": race.get("raceName", ""),
                "circuit": race.get("Circuit", {}).get("circuitName", ""),
                "year": year,
                "round": round_num,
                "total_laps": len(all_laps),
                "laps": all_laps,
            }
        except (KeyError, IndexError, ValueError) as e:
            print(f"Qualifying replay parse error: {e}")
            return None

    def _sprint_replay(self, year: int, round_num: int):
        # Sprint results from Jolpica (available from 2021 onwards for sprint weekends)
        data = self._jolpica_get(f"{year}/{round_num}/sprint.json")
        if not data:
            return None
        try:
            races = data["MRData"]["RaceTable"].get("Races", [])
            if not races:
                return None
            race = races[0]
            sprint_results = race.get("SprintResults", [])
            if not sprint_results:
                return None

            positions = []
            for r in sprint_results:
                d, c = r.get("Driver", {}), r.get("Constructor", {})
                positions.append({
                    "pos": int(r.get("position", 99)),
                    "driver_id": d.get("driverId", ""),
                    "name": f"{d.get('givenName','')} {d.get('familyName','')}".strip(),
                    "code": d.get("code", ""),
                    "team": _normalize_team(c.get("name", "")),
                    "lap_time": r.get("FastestLap", {}).get("Time", {}).get("time", ""),
                    "gap": r.get("Time", {}).get("time", r.get("status", "")),
                    "interval": "",
                })
            positions.sort(key=lambda x: x["pos"])
            return {
                "session_type": "sprint",
                "race_name": race.get("raceName", ""),
                "circuit": race.get("Circuit", {}).get("circuitName", ""),
                "year": year,
                "round": round_num,
                "total_laps": 1,
                "laps": [{"lap": 1, "phase": "FINAL", "positions": positions}],
            }
        except (KeyError, IndexError, ValueError) as e:
            print(f"Sprint replay parse error: {e}")
            return None

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
                "message": "Use /api/f1/replay/{year}/{round}/{session} for session replay",
                "safety_car_active": False,
                "vsc_active": False,
                "red_flag_active": False,
                "yellow_flag_active": False,
                "active_sector": 0,
            },
        }


f1_api_client = F1ApiClient()
