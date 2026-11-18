# backend/ingest/cross_check.py
"""
Cross-check parsed session data against Jolpica official results.
Only called for Race and Sprint sessions.
"""

import requests
from typing import Optional

JOLPICA_BASE = "https://api.jolpi.ca/ergast/f1"

# Words that appear in almost every race name and must not drive round matching.
STOP_WORDS = {"grand", "prix"}


def _jolpica_get(path: str, timeout: int = 15):
    url = f"{JOLPICA_BASE}/{path}"
    try:
        resp = requests.get(
            url, timeout=timeout, headers={"Accept": "application/json"}
        )
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
        if any(
            part in name or part in circuit
            for part in event_clean.split()
            if len(part) > 4 and part not in STOP_WORDS
        ):
            return int(race.get("round", 0))
    return None


def _enrich_result(r: dict, include_fastest_lap: bool = True) -> dict:
    """Build a rich result entry from a Jolpica result object."""
    drv = r.get("Driver", {})
    con = r.get("Constructor", {})
    pos = int(r.get("position", 99))
    # Leader gets race time; finishers behind get a gap string like "+5.123s"
    t = r.get("Time", {}) or {}
    time_val = t.get("time") if t else None
    # Fastest lap (race only)
    fl = r.get("FastestLap", {}) or {}
    fl_rank = fl.get("rank")
    fl_time_obj = fl.get("Time", {}) or {}
    fl_time = fl_time_obj.get("time")
    fl_lap_raw = fl.get("lap")
    return {
        "pos": pos,
        "code": drv.get("code", "???"),
        "name": f"{drv.get('givenName', '')} {drv.get('familyName', '')}".strip(),
        "team": con.get("name", ""),
        "grid": int(r.get("grid", 0)),
        "laps": int(r.get("laps", 0)),
        "time": time_val,
        "status": r.get("status", "Finished"),
        "points": float(r.get("points", 0)),
        "fastest_lap": fl_rank == "1" if include_fastest_lap else False,
        "fastest_lap_time": fl_time if include_fastest_lap else None,
        "fastest_lap_num": (
            int(fl_lap_raw) if fl_lap_raw and include_fastest_lap else None
        ),
    }


def get_jolpica_final_classification(
    year: int, round_num: int, session_type: str
) -> Optional[list]:
    """Fetch official final classification from Jolpica (enriched)."""
    if session_type == "Race":
        data = _jolpica_get(f"{year}/{round_num}/results.json")
        if not data:
            return None
        races = data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
        if not races:
            return None
        results = races[0].get("Results", [])
        output = [_enrich_result(r, include_fastest_lap=True) for r in results]
        return output if output else None
    elif session_type == "Sprint":
        data = _jolpica_get(f"{year}/{round_num}/sprint.json")
        if not data:
            return None
        races = data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
        if not races:
            return None
        results = races[0].get("SprintResults", [])
        output = [_enrich_result(r, include_fastest_lap=False) for r in results]
        return output if output else None
    return None


def get_jolpica_qualifying_classification(year: int, round_num: int) -> Optional[list]:
    """Fetch official qualifying classification from Jolpica (enriched with Q1/Q2/Q3 times)."""
    data = _jolpica_get(f"{year}/{round_num}/qualifying.json")
    if not data:
        return None
    races = data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
    if not races:
        return None
    results = races[0].get("QualifyingResults", [])
    return [
        {
            "pos": int(r.get("position", 99)),
            "code": r.get("Driver", {}).get("code", "???"),
            "name": (
                f"{r.get('Driver', {}).get('givenName', '')} "
                f"{r.get('Driver', {}).get('familyName', '')}".strip()
            ),
            "team": r.get("Constructor", {}).get("name", ""),
            "q1": r.get("Q1"),
            "q2": r.get("Q2"),
            "q3": r.get("Q3"),
        }
        for r in results
    ]


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
    if session_type not in ("Race", "Sprint", "Q", "SQ"):
        return True, None, None

    round_num = find_jolpica_round(year, event)
    if round_num is None:
        return True, None, None

    if session_type in ("Race", "Sprint"):
        jolpica = get_jolpica_final_classification(year, round_num, session_type)
        if not jolpica:
            return True, None, None

        parsed_positions = parsed.get("laps", {}).get("laps", [])
        if not parsed_positions:
            return True, jolpica, None

        last_lap = parsed_positions[-1]
        parsed_order = [
            p["code"]
            for p in sorted(
                [
                    p
                    for p in last_lap.get("positions", [])
                    if p.get("status") == "RACING"
                ],
                key=lambda p: p.get("pos", 99),
            )
        ]
        jolpica_order = [r["code"] for r in sorted(jolpica, key=lambda r: r["pos"])]

        n = min(10, len(parsed_order), len(jolpica_order))
        mismatches = sum(1 for i in range(n) if parsed_order[i] != jolpica_order[i])

        # Allow up to 4 mismatches: post-race penalties and DSQs routinely shift
        # positions without changing the on-track TracingInsights order.
        if mismatches > 4:
            diff_str = (
                f"Parsed: {parsed_order[:n]} | Jolpica: {jolpica_order[:n]} "
                f"| {mismatches} mismatches in top {n}"
            )
            return False, jolpica, f"Cross-check failed: {diff_str}"

        return True, jolpica, None

    elif session_type == "Q":
        jolpica = get_jolpica_qualifying_classification(year, round_num)
        if not jolpica:
            return True, None, None

        final_grid = parsed.get("laps", {}).get("final_grid", [])
        parsed_order = [d["code"] for d in final_grid]
        jolpica_order = [r["code"] for r in sorted(jolpica, key=lambda r: r["pos"])]

        n = min(10, len(parsed_order), len(jolpica_order))
        if n == 0:
            return True, jolpica, None

        mismatches = sum(1 for i in range(n) if parsed_order[i] != jolpica_order[i])
        # Allow up to 3 mismatches: minor timing differences in Q2/Q3 ordering.
        if mismatches > 3:
            diff_str = (
                f"Parsed: {parsed_order[:n]} | Jolpica: {jolpica_order[:n]} "
                f"| {mismatches} mismatches in top {n}"
            )
            return False, jolpica, f"Qualifying cross-check failed: {diff_str}"

        return True, jolpica, None

    elif session_type == "SQ":
        # TracingInsights stores SQ laps in lap-time order; Jolpica returns the
        # official sprint grid which is set by a different rule. The two orderings
        # are structurally different so we skip the cross-check and store as READY.
        return True, None, None

    return True, None, None
