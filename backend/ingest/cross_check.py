# backend/ingest/cross_check.py
"""
Cross-check parsed session data against Jolpica official results.
Only called for Race and Sprint sessions.
"""
import requests
from typing import Optional

JOLPICA_BASE = "https://api.jolpi.ca/ergast/f1"


def _jolpica_get(path: str, timeout: int = 15):
    url = f"{JOLPICA_BASE}/{path}"
    try:
        resp = requests.get(url, timeout=timeout, headers={"Accept": "application/json"})
        if resp.status_code == 200:
            return resp.json()
    except Exception:
        pass
    return None


def find_jolpica_round(year: int, event: str) -> Optional[int]:
    """Find the Jolpica round number for a given year and event name."""
    data = _jolpica_get(f"{year}.json")
    if not data:
        return None
    races = data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
    event_clean = event.replace("_", " ").lower()
    for race in races:
        name = race.get("raceName", "").lower()
        circuit = race.get("Circuit", {}).get("circuitName", "").lower()
        if any(part in name or part in circuit for part in event_clean.split() if len(part) > 4):
            return int(race.get("round", 0))
    return None


def get_jolpica_final_classification(year: int, round_num: int, session_type: str) -> Optional[list]:
    """Fetch official final classification from Jolpica."""
    if session_type == "Race":
        data = _jolpica_get(f"{year}/{round_num}/results.json")
        if not data:
            return None
        races = data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
        if not races:
            return None
        results = races[0].get("Results", [])
        return [
            {
                "pos": int(r.get("position", 99)),
                "code": r.get("Driver", {}).get("code", "???"),
                "status": r.get("status", "Finished"),
                "laps": int(r.get("laps", 0)),
            }
            for r in results
        ]
    elif session_type == "Sprint":
        data = _jolpica_get(f"{year}/{round_num}/sprint.json")
        if not data:
            return None
        races = data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
        if not races:
            return None
        results = races[0].get("SprintResults", [])
        return [
            {
                "pos": int(r.get("position", 99)),
                "code": r.get("Driver", {}).get("code", "???"),
                "status": r.get("status", "Finished"),
                "laps": int(r.get("laps", 0)),
            }
            for r in results
        ]
    return None


def cross_check(
    parsed: dict,
    year: int,
    event: str,
    session_type: str,
) -> tuple:
    """
    Compare parsed results against Jolpica official classification.

    Returns:
        (passed: bool, jolpica_results: list|None, error_message: str|None)
    """
    if session_type not in ("Race", "Sprint"):
        return True, None, None

    round_num = find_jolpica_round(year, event)
    if round_num is None:
        return True, None, None

    jolpica = get_jolpica_final_classification(year, round_num, session_type)
    if not jolpica:
        return True, None, None

    parsed_positions = parsed.get("laps", {}).get("laps", [])
    if not parsed_positions:
        return True, jolpica, None

    last_lap = parsed_positions[-1]
    parsed_order = [
        p["code"] for p in sorted(
            [p for p in last_lap.get("positions", []) if p.get("status") == "RACING"],
            key=lambda p: p.get("pos", 99),
        )
    ]
    jolpica_order = [r["code"] for r in sorted(jolpica, key=lambda r: r["pos"])]

    n = min(10, len(parsed_order), len(jolpica_order))
    mismatches = sum(1 for i in range(n) if parsed_order[i] != jolpica_order[i])

    if mismatches > 1:
        diff_str = (
            f"Parsed: {parsed_order[:n]} | Jolpica: {jolpica_order[:n]} "
            f"| {mismatches} mismatches in top {n}"
        )
        return False, jolpica, f"Cross-check failed: {diff_str}"

    return True, jolpica, None
