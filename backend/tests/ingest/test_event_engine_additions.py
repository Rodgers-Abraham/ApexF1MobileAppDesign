"""Tests for event engine additions and cross-check fixes."""

import pytest

from ingest.cross_check import STOP_WORDS
from ingest.event_engine import (
    build_practice_events,
    build_qualifying_events,
    build_race_events,
    classify_lap_events,
)

# ── Yellow flag ───────────────────────────────────────────────────────────────


def test_yellow_flag_emitted():
    lap = {
        "lap": 5,
        "track_status": "2",
        "sc_active": False,
        "vsc_active": False,
        "red_flag": False,
        "positions": [],
    }
    prev = {"lap": 4, "track_status": "1", "positions": []}
    events = classify_lap_events(lap, prev)
    assert any(e["type"] == "YELLOW_FLAG" for e in events)


def test_yellow_flag_not_emitted_on_clear():
    lap = {
        "lap": 5,
        "track_status": "1",
        "sc_active": False,
        "vsc_active": False,
        "red_flag": False,
        "positions": [],
    }
    prev = {"lap": 4, "track_status": "1", "positions": []}
    events = classify_lap_events(lap, prev)
    assert not any(e["type"] == "YELLOW_FLAG" for e in events)


# ── DNS events ────────────────────────────────────────────────────────────────


def test_dns_events_emitted():
    parsed = {
        "laps": {
            "total_laps": 1,
            "grid": [],
            "laps": [],
            "dns_drivers": [{"code": "ZHO"}, {"code": "SAR"}],
        },
        "rcm_events": [],
    }
    events = build_race_events(parsed)
    dns_events = [e for e in events if e["type"] == "DNS"]
    assert len(dns_events) == 2
    codes = {e["drivers"][0] for e in dns_events}
    assert {"ZHO", "SAR"} == codes


def test_dns_lap_is_zero():
    parsed = {
        "laps": {
            "total_laps": 1,
            "grid": [],
            "laps": [],
            "dns_drivers": [{"code": "ZHO"}],
        },
        "rcm_events": [],
    }
    events = build_race_events(parsed)
    dns = next(e for e in events if e["type"] == "DNS")
    assert dns["lap"] == 0


# ── Practice events ───────────────────────────────────────────────────────────


def test_practice_red_flag_event():
    parsed = {
        "laps": {},
        "rcm_events": [
            {
                "flag": "RED",
                "session_time_s": 300.0,
                "message": "Red flag",
                "category": "Flag",
            }
        ],
    }
    events = build_practice_events(parsed)
    assert any(e["type"] == "RED_FLAG" for e in events)


def test_practice_yellow_flag_with_scope():
    parsed = {
        "laps": {},
        "rcm_events": [
            {
                "flag": "YELLOW",
                "session_time_s": 150.0,
                "message": "Yellow",
                "scope": "Sector",
                "sector": 2,
                "category": "Flag",
            }
        ],
    }
    events = build_practice_events(parsed)
    yf = next(e for e in events if e["type"] == "YELLOW_FLAG")
    assert yf["sector"] == 2


# ── Qualifying events ─────────────────────────────────────────────────────────


def test_qualifying_segment_events():
    parsed = {
        "laps": {
            "segment_order": ["Q1", "Q2"],
            "segments": {
                "Q1": {"eliminated": ["SAR", "LAW"], "timeline": [], "final_order": []},
                "Q2": {"eliminated": ["STR"], "timeline": [], "final_order": []},
            },
        },
        "rcm_events": [],
    }
    events = build_qualifying_events(parsed)
    types = [e["type"] for e in events]
    assert types.count("SEGMENT_START") == 2
    assert types.count("SEGMENT_END") == 2
    elim_events = [e for e in events if e["type"] == "ELIMINATED"]
    assert len(elim_events) == 3
    assert "SAR" in {e["drivers"][0] for e in elim_events}


# ── Cross-check stop-words ────────────────────────────────────────────────────


def test_stop_words_set():
    assert "grand" in STOP_WORDS
    assert "prix" in STOP_WORDS
