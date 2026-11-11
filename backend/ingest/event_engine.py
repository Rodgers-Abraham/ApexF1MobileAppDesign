# backend/ingest/event_engine.py
"""
Classify position changes at lap boundaries for race sessions.

Rules:
- RETIREMENT_GAIN: driver moved up because a driver ahead RETIRED this lap
- PIT_GAIN: driver moved up because a driver ahead PITTED (is_pit_in=True) this lap
- OVERTAKE: driver moved up by passing on track
- Priority: RETIREMENT > PIT > OVERTAKE
- Net changes only: a pass and re-pass within one lap = no event
- SC/VSC/DNF events added from track status and positions

Returns per-lap events list to be stored in sessions.events JSONB.
"""


def _get_positions(lap_data: dict) -> dict:
    """Extract {code: pos} from a lap's positions list."""
    return {
        p["code"]: p["pos"]
        for p in lap_data.get("positions", [])
        if p.get("status") == "RACING" and p.get("pos") and p["pos"] != 99
    }


def _get_pit_in_drivers(lap_data: dict) -> set:
    """Return codes of drivers who had a pit entry this lap."""
    return {
        p["code"]
        for p in lap_data.get("positions", [])
        if p.get("is_pit_in") or (p.get("pin_s") is not None)
    }


def _get_dnf_drivers(lap_data: dict) -> set:
    """Return codes of drivers with status=DNF this lap."""
    return {p["code"] for p in lap_data.get("positions", []) if p.get("status") == "DNF"}


def classify_lap_events(lap_n: dict, lap_n1: dict) -> list:
    """
    Diff two consecutive laps and classify each position change.

    Args:
        lap_n: laps[i] (current lap)
        lap_n1: laps[i-1] (previous lap)

    Returns list of event dicts.
    """
    lap_num = lap_n.get("lap", 0)
    pos_n = _get_positions(lap_n)
    pos_n1 = _get_positions(lap_n1)
    pit_drivers = _get_pit_in_drivers(lap_n)
    dnf_drivers = _get_dnf_drivers(lap_n)

    events = []

    # DNF events first
    for code in dnf_drivers:
        events.append({
            "type": "DNF",
            "lap": lap_num,
            "drivers": [code],
            "detail": "Retired",
            "label": f"{code}: Retired (Lap {lap_num})",
        })

    # Position changes
    gainers = []
    for code, curr_pos in pos_n.items():
        prev_pos = pos_n1.get(code)
        if prev_pos is not None and curr_pos < prev_pos:
            gained = prev_pos - curr_pos
            gainers.append((code, prev_pos, curr_pos, gained))

    for code, prev_pos, curr_pos, gained in gainers:
        # Find who was between curr_pos and prev_pos in lap N-1
        drivers_ahead_prev = {
            c for c, p in pos_n1.items()
            if curr_pos <= p < prev_pos and c != code
        }

        retired_ahead = drivers_ahead_prev & dnf_drivers
        pitted_ahead = drivers_ahead_prev & pit_drivers

        if retired_ahead:
            event_type = "RETIREMENT_GAIN"
            cause_driver = next(iter(retired_ahead))
            detail = f"+{gained} (retirement)"
            label = f"{code}: +{gained} ({cause_driver} retirement)"
        elif pitted_ahead:
            event_type = "PIT_GAIN"
            detail = "Gained via pit stop"
            label = f"{code}: gained via pit stop"
        else:
            event_type = "OVERTAKE"
            passed_drivers = [c for c, p in pos_n1.items() if p == curr_pos]
            passed = passed_drivers[0] if passed_drivers else "?"
            detail = f"{code} passes {passed}"
            label = f"{code} passes {passed} for P{curr_pos}"

        events.append({
            "type": event_type,
            "lap": lap_num,
            "drivers": [code],
            "detail": detail,
            "label": label,
        })

    # Track status events
    if lap_n.get("sc_active"):
        events.append({
            "type": "SAFETY_CAR",
            "lap": lap_num,
            "drivers": [],
            "detail": "SAFETY CAR",
            "label": f"Safety Car Lap {lap_num}",
        })
    elif lap_n.get("vsc_active"):
        events.append({
            "type": "VSC",
            "lap": lap_num,
            "drivers": [],
            "detail": "VIRTUAL SAFETY CAR",
            "label": f"Virtual Safety Car Lap {lap_num}",
        })
    elif lap_n.get("red_flag"):
        events.append({
            "type": "RED_FLAG",
            "lap": lap_num,
            "drivers": [],
            "detail": "RED FLAG",
            "label": f"Red Flag Lap {lap_num}",
        })

    return events


def build_race_events(parsed: dict) -> list:
    """
    Run event classifier across all laps of a parsed Race session.
    Returns flat list of all events.
    """
    laps = parsed.get("laps", {}).get("laps", [])
    all_events = []

    for i in range(1, len(laps)):
        lap_events = classify_lap_events(laps[i], laps[i - 1])
        all_events.extend(lap_events)

    # RCM-sourced penalty events
    for rcm_event in parsed.get("rcm_events", []):
        cat = rcm_event.get("category", "")
        msg = rcm_event.get("message", "")
        lap = rcm_event.get("lap")
        if cat == "CarEvent" and lap is not None and "penalty" in msg.lower():
            driver_num = rcm_event.get("driver_number")
            all_events.append({
                "type": "PENALTY",
                "lap": lap,
                "drivers": [f"#{driver_num}"] if driver_num else [],
                "detail": msg,
                "label": f"Penalty: {msg}",
            })

    return all_events
