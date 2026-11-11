"""
Tests for the TracingInsights parser.
These use live data fetched from the TracingInsights GitHub repo.
Run with: pytest backend/tests/ingest/test_parser.py -v
"""
import sys
import os
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from ingest.parser import _laptimes_to_rows, parse_session, parse_meta


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


@pytest.mark.skipif(
    not os.getenv("GITHUB_TOKEN"),
    reason="Requires GITHUB_TOKEN to fetch TracingInsights data"
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
                assert pos["pos"] > 0, f"RACING driver {pos['code']} has pos={pos['pos']}"


@pytest.mark.skipif(
    not os.getenv("GITHUB_TOKEN"),
    reason="Requires GITHUB_TOKEN to fetch TracingInsights data"
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
        assert q1.get("driver_count", 0) >= q3.get("driver_count", 0), \
            "Q1 should have >= drivers than Q3"
