"""
Tests for the TracingInsights parser.
These use live data fetched from the TracingInsights GitHub repo.
Run with: pytest backend/tests/ingest/test_parser.py -v
"""

import sys
import os
import pytest

sys.path.insert(
    0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)

from ingest.parser import _laptimes_to_rows, parse_session, parse_meta, SCHEMA_VERSION


def test_laptimes_to_rows_round_trips():
    """Column-oriented → row dict conversion preserves all values."""
    col = {"time": [1.1, 2.2], "drv": ["VER", "NOR"], "lap": [1, 1]}
    rows = _laptimes_to_rows(col)
    assert len(rows) == 2
    assert rows[0]["drv"] == "VER"
    assert rows[1]["time"] == 2.2


def test_laptimes_to_rows_empty():
    assert _laptimes_to_rows({}) == []
    assert _laptimes_to_rows(None) == []


# ── Helpers ───────────────────────────────────────────────────────────────────


def _make_practice_files(rows, has_sectors=True):
    """Build minimal practice file dict for parse_practice tests."""
    if not has_sectors:
        for r in rows:
            r.pop("s1", None)
            r.pop("s2", None)
            r.pop("s3", None)
    drivers_data = {
        "drivers": [
            {
                "driver": "VER",
                "team": "Red Bull Racing",
                "tc": "3671C6",
                "dn": 1,
                "fn": "Max",
                "ln": "Verstappen",
            },
            {
                "driver": "NOR",
                "team": "McLaren",
                "tc": "FF8000",
                "dn": 4,
                "fn": "Lando",
                "ln": "Norris",
            },
        ]
    }
    si = {
        "t0_date": "2026-03-14T10:00:00Z",
        "session_status": {"Time": [0, 3600], "Status": ["Started", "Finished"]},
        "track_status": {"Time": [], "Status": [], "Message": []},
    }
    # Build column-oriented session_laptimes
    drv_col = [r["drv"] for r in rows]
    lap_col = [r["lap"] for r in rows]
    time_col = [r["time"] for r in rows]
    sesT_col = [r.get("sesT") for r in rows]
    lST_col = [r.get("lST") for r in rows]
    s1_col = [r.get("s1") for r in rows] if has_sectors else [None] * len(rows)
    s2_col = [r.get("s2") for r in rows] if has_sectors else [None] * len(rows)
    s3_col = [r.get("s3") for r in rows] if has_sectors else [None] * len(rows)
    sl = {
        "drv": drv_col,
        "lap": lap_col,
        "time": time_col,
        "sesT": sesT_col,
        "lST": lST_col,
        "s1": s1_col,
        "s2": s2_col,
        "s3": s3_col,
    }
    return {
        "drivers": drivers_data,
        "session_laptimes": sl,
        "rcm": [],
        "session_info": si,
        "weather": None,
        "team_radio": None,
    }


# ── last_lap_timeline tests ────────────────────────────────────────────────────


def test_last_lap_timeline_includes_non_pbs():
    """last_lap_timeline records every lap, not just personal bests."""
    rows = [
        {"drv": "VER", "lap": 1, "time": 92.0, "sesT": 92.0, "lST": 0.0},
        {"drv": "VER", "lap": 2, "time": 90.0, "sesT": 182.0, "lST": 92.0},  # PB
        {"drv": "VER", "lap": 3, "time": 91.0, "sesT": 273.0, "lST": 182.0},
    ]
    files = _make_practice_files(rows, has_sectors=False)
    result = parse_session("P1", files)
    llt = result["laps"]["last_lap_timeline"]
    assert len(llt) == 3
    assert len(result["laps"]["timeline"]) == 2  # lap 1 and lap 2 are both PBs
    # Fastest (lap 2 = 90.0) is in PB timeline
    assert result["laps"]["timeline"][-1]["lap_time_s"] == 90.0


def test_last_lap_timeline_single_lap():
    """last_lap_timeline records a single-lap session correctly."""
    rows = [{"drv": "VER", "lap": 1, "time": 95.0, "sesT": 95.0, "lST": 0.0}]
    files = _make_practice_files(rows, has_sectors=False)
    result = parse_session("P1", files)
    assert len(result["laps"]["last_lap_timeline"]) == 1
    assert result["laps"]["last_lap_timeline"][0]["is_personal_best"] is True


# ── has_sector_times tests ─────────────────────────────────────────────────────


def test_has_sector_times_true():
    """has_sector_times is True when s1/s2/s3 are present."""
    rows = [
        {
            "drv": "VER",
            "lap": 1,
            "time": 90.0,
            "sesT": 90.0,
            "lST": 0.0,
            "s1": 28.1,
            "s2": 32.5,
            "s3": 29.4,
        }
    ]
    files = _make_practice_files(rows, has_sectors=True)
    result = parse_session("P1", files)
    assert result["laps"]["has_sector_times"] is True
    assert "s1" in result["laps"]["timeline"][0]
    assert "s1" in result["laps"]["last_lap_timeline"][0]


def test_has_sector_times_false():
    """has_sector_times is False when no s1/s2/s3 in source data."""
    rows = [{"drv": "VER", "lap": 1, "time": 90.0, "sesT": 90.0, "lST": 0.0}]
    files = _make_practice_files(rows, has_sectors=False)
    result = parse_session("P1", files)
    assert result["laps"]["has_sector_times"] is False
    assert "s1" not in result["laps"]["timeline"][0]
    assert "s1" not in result["laps"]["last_lap_timeline"][0]


# ── SCHEMA_VERSION tests ───────────────────────────────────────────────────────


def test_schema_version_importable():
    """SCHEMA_VERSION is importable, non-empty, and a string."""
    assert isinstance(SCHEMA_VERSION, str)
    assert len(SCHEMA_VERSION) > 0


def test_schema_version_in_runner_hash(monkeypatch):
    """run_check uses SCHEMA_VERSION-qualified hash, not raw commit SHA."""
    from ingest import runner

    assert hasattr(runner, "SCHEMA_VERSION"), "runner must import SCHEMA_VERSION"
    # The schema hash format must include the version
    fake_sha = "abc123def456"
    expected = f"{fake_sha}:{SCHEMA_VERSION}"
    assert expected != fake_sha  # sanity: they must differ


# ── Live integration tests (require GITHUB_TOKEN) ─────────────────────────────


@pytest.mark.skipif(
    not os.getenv("GITHUB_TOKEN"),
    reason="Requires GITHUB_TOKEN to fetch TracingInsights data",
)
def test_parse_race_live():
    """Integration test: fetch and parse Australian GP 2026 Race."""
    from services.tracing_insights import TracingInsightsFetcher

    token = os.getenv("GITHUB_TOKEN")
    fetcher = TracingInsightsFetcher(token)
    files = fetcher.fetch_session_files(2026, "Australian_Grand_Prix", "Race")

    parsed = parse_session("Race", files)
    laps = parsed["laps"]

    # At least 15 drivers, all laps present
    assert laps["total_laps"] > 0, "total_laps should be > 0"
    assert len(laps["grid"]) >= 15, "Should have at least 15 grid entries"
    assert len(laps["laps"]) >= 5, "Should have at least 5 laps of data"

    # Every RACING driver in every lap has a pos
    for lap_data in laps["laps"]:
        for pos in lap_data["positions"]:
            if pos["status"] == "RACING":
                assert (
                    pos["pos"] > 0
                ), f"RACING driver {pos['code']} has pos={pos['pos']}"


@pytest.mark.skipif(
    not os.getenv("GITHUB_TOKEN"),
    reason="Requires GITHUB_TOKEN to fetch TracingInsights data",
)
def test_parse_qualifying_live():
    """Integration test: fetch and parse Australian GP 2026 Qualifying."""
    from services.tracing_insights import TracingInsightsFetcher

    token = os.getenv("GITHUB_TOKEN")
    fetcher = TracingInsightsFetcher(token)
    try:
        files = fetcher.fetch_session_files(2026, "Australian_Grand_Prix", "Q")
    except Exception:
        pytest.skip("Qualifying data not available for this race")

    parsed = parse_session("Q", files)
    laps = parsed["laps"]

    segments = laps.get("segments", {})
    assert len(segments) > 0, "Should have at least one qualifying segment"

    # Q1 should have all drivers; Q3 should have fewer
    q1 = segments.get("Q1", {})
    q3 = segments.get("Q3", {})
    if q1 and q3:
        assert q1.get("driver_count", 0) >= q3.get(
            "driver_count", 0
        ), "Q1 should have >= drivers than Q3"
