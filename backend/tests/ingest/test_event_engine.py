"""Tests for the race event engine."""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from ingest.event_engine import classify_lap_events, build_race_events


def _make_lap(lap_num, positions_list):
    """Helper: build a lap dict from a simple list of (code, pos, status, is_pit_in)."""
    positions = []
    for item in positions_list:
        if isinstance(item, tuple):
            if len(item) == 4:
                code, pos, status, is_pit = item
            else:
                code, pos, status = item
                is_pit = False
        else:
            code, pos, status, is_pit = item["code"], item["pos"], item.get("status","RACING"), False
        positions.append({
            "code": code, "pos": pos, "status": status,
            "is_pit_in": is_pit, "pin_s": 1.0 if is_pit else None,
        })
    return {"lap": lap_num, "positions": positions, "sc_active": False, "vsc_active": False, "red_flag": False}


def test_simple_overtake():
    lap1 = _make_lap(1, [("VER", 1, "RACING", False), ("NOR", 2, "RACING", False)])
    lap2 = _make_lap(2, [("NOR", 1, "RACING", False), ("VER", 2, "RACING", False)])
    events = classify_lap_events(lap2, lap1)
    overtakes = [e for e in events if e["type"] == "OVERTAKE"]
    assert len(overtakes) == 1
    assert overtakes[0]["drivers"] == ["NOR"]
    assert "NOR" in overtakes[0]["label"]


def test_pit_gain():
    lap1 = _make_lap(5, [("VER", 1, "RACING", False), ("NOR", 2, "RACING", False)])
    # VER pits, NOR moves up
    lap2 = _make_lap(6, [("NOR", 1, "RACING", False), ("VER", 2, "RACING", True)])  # VER has pit_in
    events = classify_lap_events(lap2, lap1)
    pit_gains = [e for e in events if e["type"] == "PIT_GAIN"]
    assert len(pit_gains) == 1
    assert pit_gains[0]["drivers"] == ["NOR"]


def test_retirement_gain():
    lap1 = _make_lap(10, [("VER", 1, "RACING", False), ("NOR", 2, "RACING", False)])
    # VER retires, NOR moves up
    lap2 = _make_lap(11, [("NOR", 1, "RACING", False), ("VER", 2, "DNF", False)])
    events = classify_lap_events(lap2, lap1)
    # DNF event for VER
    dnf_events = [e for e in events if e["type"] == "DNF"]
    assert len(dnf_events) == 1
    assert dnf_events[0]["drivers"] == ["VER"]
    # NOR should get retirement_gain
    ret_gains = [e for e in events if e["type"] == "RETIREMENT_GAIN"]
    assert len(ret_gains) == 1
    assert ret_gains[0]["drivers"] == ["NOR"]


def test_net_change_no_event():
    """Pass and re-pass within same lap = no overtake event."""
    lap1 = _make_lap(1, [("VER", 1, "RACING", False), ("NOR", 2, "RACING", False)])
    # Same order at end of lap 2 = net no change
    lap2 = _make_lap(2, [("VER", 1, "RACING", False), ("NOR", 2, "RACING", False)])
    events = classify_lap_events(lap2, lap1)
    overtakes = [e for e in events if e["type"] == "OVERTAKE"]
    assert len(overtakes) == 0


def test_safety_car_event():
    lap1 = _make_lap(15, [("VER", 1, "RACING", False)])
    lap2 = _make_lap(16, [("VER", 1, "RACING", False)])
    lap2["sc_active"] = True
    events = classify_lap_events(lap2, lap1)
    sc_events = [e for e in events if e["type"] == "SAFETY_CAR"]
    assert len(sc_events) == 1


def test_build_race_events_sequence():
    """Full sequence: grid → lap1 → lap2 with one overtake."""
    parsed = {
        "laps": {
            "total_laps": 2,
            "grid": [{"pos": 1, "code": "VER"}, {"pos": 2, "code": "NOR"}],
            "laps": [
                _make_lap(1, [("VER", 1, "RACING", False), ("NOR", 2, "RACING", False)]),
                _make_lap(2, [("NOR", 1, "RACING", False), ("VER", 2, "RACING", False)]),
            ],
        },
        "rcm_events": [],
    }
    all_events = build_race_events(parsed)
    overtakes = [e for e in all_events if e["type"] == "OVERTAKE"]
    assert len(overtakes) >= 1
