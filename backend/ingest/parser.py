"""Parse raw TracingInsights JSON files into normalized internal schemas."""
from datetime import datetime, timezone
from typing import Optional


def _safe_float(v) -> Optional[float]:
    if v is None or v == "None":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _safe_int(v) -> Optional[int]:
    if v is None or v == "None":
        return None
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def _to_session_seconds(iso_str: str, t0_date: str) -> Optional[float]:
    """Convert ISO 8601 wall-clock string to seconds relative to t0_date."""
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        t0 = datetime.fromisoformat(t0_date.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if t0.tzinfo is None:
            t0 = t0.replace(tzinfo=timezone.utc)
        return (dt - t0).total_seconds()
    except Exception:
        return None


def _parse_drivers(drivers_raw: dict) -> list:
    """Parse drivers.json into a list of driver dicts."""
    return [
        {
            "code": d.get("driver", ""),
            "team": d.get("team", ""),
            "number": d.get("dn", ""),
            "first_name": d.get("fn", ""),
            "last_name": d.get("ln", ""),
            "color": d.get("tc", "FFFFFF"),
            "headshot_url": d.get("url", ""),
        }
        for d in drivers_raw.get("drivers", [])
    ]


def _laptimes_to_rows(session_laptimes: dict) -> list:
    """Convert column-oriented session_laptimes dict to list of row dicts."""
    if not session_laptimes:
        return []
    keys = list(session_laptimes.keys())
    if not keys:
        return []
    n = len(session_laptimes[keys[0]])
    return [{k: session_laptimes[k][i] for k in keys} for i in range(n)]


def _parse_rcm(rcm: dict, t0_date: str) -> list:
    """Parse rcm.json into a list of event dicts with session-relative seconds."""
    rows = _laptimes_to_rows(rcm) if rcm else []
    events = []
    for r in rows:
        iso_time = r.get("time", "")
        sess_secs = _to_session_seconds(iso_time, t0_date) if iso_time else None
        events.append({
            "session_time_s": sess_secs,
            "category": r.get("cat", ""),
            "message": r.get("msg", ""),
            "flag": r.get("flag") if r.get("flag") != "None" else None,
            "scope": r.get("scope") if r.get("scope") != "None" else None,
            "sector": _safe_int(r.get("sector")),
            "driver_number": r.get("dNum") if r.get("dNum") != "None" else None,
            "lap": _safe_int(r.get("lap")),
        })
    return events


def parse_meta(drivers_raw: dict, session_info: dict, event: str, session_type: str) -> dict:
    """Build meta JSONB: driver list, session info, circuit."""
    drivers = _parse_drivers(drivers_raw)
    si = session_info.get("session_info", {})
    meeting = si.get("Meeting", {})
    return {
        "drivers": drivers,
        "event": event,
        "session_type": session_type,
        "total_laps": session_info.get("total_laps"),
        "t0_date": session_info.get("t0_date", ""),
        "session_start_time_s": _safe_float(session_info.get("session_start_time")),
        "circuit": meeting.get("Circuit", {}).get("shortName", ""),
        "country": meeting.get("Country", {}).get("Name", ""),
        "event_name": meeting.get("OfficialName", event.replace("_", " ")),
        "gmt_offset": si.get("GmtOffset", ""),
    }


def parse_race(files: dict) -> dict:
    """Parse a Race session into internal JSONB schema."""
    drivers_raw = files["drivers"]
    sl = files["session_laptimes"]
    rcm_raw = files["rcm"]
    si = files["session_info"]
    t0 = si.get("t0_date", "")
    total_laps = si.get("total_laps") or 0

    drivers = _parse_drivers(drivers_raw)
    all_rows = _laptimes_to_rows(sl)
    rcm_events = _parse_rcm(rcm_raw, t0)

    # Group rows by lap
    laps_dict: dict = {}
    for row in all_rows:
        lap_num = _safe_int(row.get("lap")) or 0
        laps_dict.setdefault(lap_num, []).append(row)

    # Build grid from lap 1 starting positions
    grid = []
    if 1 in laps_dict:
        sorted_rows = sorted(laps_dict[1], key=lambda r: _safe_int(r.get("pos")) or 99)
        for r in sorted_rows:
            d_code = r.get("drv", "")
            d_info = next((d for d in drivers if d["code"] == d_code), {})
            grid.append({
                "pos": _safe_int(r.get("pos")) or 0,
                "code": d_code,
                "team": r.get("team", d_info.get("team", "")),
                "color": d_info.get("color", "FFFFFF"),
                "number": r.get("dNum", d_info.get("number", "")),
            })
    else:
        for i, d in enumerate(drivers):
            grid.append({"pos": i + 1, "code": d["code"], "team": d["team"],
                         "color": d["color"], "number": d["number"]})

    # DNF tracking
    driver_last_lap: dict = {}
    for row in all_rows:
        code = row.get("drv", "")
        lap_num = _safe_int(row.get("lap")) or 0
        if lap_num > driver_last_lap.get(code, 0):
            driver_last_lap[code] = lap_num

    # Track status lookup
    track_status_times = si.get("track_status", {}).get("Time", [])
    track_status_codes = si.get("track_status", {}).get("Status", [])

    def get_track_status_at(session_time_s: float) -> str:
        status = "1"
        for i, t in enumerate(track_status_times):
            if t <= session_time_s:
                status = str(track_status_codes[i]) if i < len(track_status_codes) else "1"
            else:
                break
        return status

    laps_out = []
    for lap_num in sorted(laps_dict.keys()):
        rows = laps_dict[lap_num]
        racing_rows = [r for r in rows if not r.get("ff1G", False) and r.get("pos") != "None"]
        out_rows = [r for r in rows if r.get("ff1G", False) or r.get("pos") == "None"]
        racing_rows.sort(key=lambda r: _safe_int(r.get("pos")) or 99)

        lap_times = [_safe_float(r.get("time")) for r in racing_rows if _safe_float(r.get("time"))]
        fastest_time = min(lap_times) if lap_times else None

        positions = []
        for r in racing_rows:
            d_code = r.get("drv", "")
            d_info = next((d for d in drivers if d["code"] == d_code), {})
            lap_time = _safe_float(r.get("time"))
            positions.append({
                "pos": _safe_int(r.get("pos")) or 0,
                "code": d_code,
                "team": r.get("team", d_info.get("team", "")),
                "color": d_info.get("color", "FFFFFF"),
                "lap_time": lap_time,
                "s1": _safe_float(r.get("s1")),
                "s2": _safe_float(r.get("s2")),
                "s3": _safe_float(r.get("s3")),
                "compound": r.get("compound", "UNKNOWN"),
                "life": _safe_int(r.get("life")),
                "stint": _safe_int(r.get("stint")),
                "is_pit_in": r.get("pin") not in (None, "None"),
                "pin_s": _safe_float(r.get("pin")),
                "pout_s": _safe_float(r.get("pout")),
                "is_fastest_lap_of_race": bool(r.get("pb", False)),
                "is_fastest_this_lap": lap_time is not None and lap_time == fastest_time,
                "status": "RACING",
                "deleted": bool(r.get("del", False)),
            })

        for r in out_rows:
            d_code = r.get("drv", "")
            d_info = next((d for d in drivers if d["code"] == d_code), {})
            positions.append({
                "pos": 99, "code": d_code,
                "team": r.get("team", d_info.get("team", "")),
                "color": d_info.get("color", "FFFFFF"),
                "lap_time": None, "s1": None, "s2": None, "s3": None,
                "compound": r.get("compound", "UNKNOWN"),
                "life": _safe_int(r.get("life")), "stint": _safe_int(r.get("stint")),
                "is_pit_in": False, "pin_s": None, "pout_s": None,
                "is_fastest_lap_of_race": False, "is_fastest_this_lap": False,
                "status": "DNF", "deleted": False,
            })

        lap_start_s = _safe_float(rows[0].get("lST")) if rows else 0
        track_status = get_track_status_at(lap_start_s or 0) if lap_start_s else "1"

        fastest_code = None
        if fastest_time and racing_rows:
            for r in racing_rows:
                if _safe_float(r.get("time")) == fastest_time:
                    fastest_code = r.get("drv")
                    break

        laps_out.append({
            "lap": lap_num,
            "positions": positions,
            "fastest_code": fastest_code,
            "fastest_lap_time": fastest_time,
            "track_status": track_status,
            "sc_active": track_status == "4",
            "vsc_active": track_status in ("6", "7"),
            "red_flag": track_status == "5",
        })

    all_racing_codes = set(driver_last_lap.keys())
    dns_drivers = [d for d in drivers if d["code"] not in all_racing_codes]

    weather_out = None
    if all_rows:
        last = all_rows[-1]
        weather_out = {
            "air_temp": _safe_float(last.get("wAT")),
            "track_temp": _safe_float(last.get("wT")),
            "humidity": _safe_float(last.get("wH")),
            "pressure": _safe_float(last.get("wP")),
            "rainfall": _safe_float(last.get("wR")),
            "wind_direction": _safe_float(last.get("wWD")),
            "wind_speed": _safe_float(last.get("wWS")),
        }

    radio_out = None
    if files.get("team_radio"):
        tr = files["team_radio"]
        radio_out = {"clips": tr} if isinstance(tr, list) else tr

    return {
        "laps": {
            "total_laps": total_laps,
            "grid": grid,
            "laps": laps_out,
            "dns_drivers": dns_drivers,
        },
        "rcm_events": rcm_events,
        "weather": weather_out,
        "radio": radio_out,
    }


def parse_practice(files: dict) -> dict:
    """Parse a Practice session (P1/P2/P3)."""
    drivers_raw = files["drivers"]
    sl = files["session_laptimes"]
    rcm_raw = files["rcm"]
    si = files["session_info"]
    t0 = si.get("t0_date", "")

    drivers = _parse_drivers(drivers_raw)
    all_rows = _laptimes_to_rows(sl)
    rcm_events = _parse_rcm(rcm_raw, t0)

    session_status = si.get("session_status", {})
    ss_times = session_status.get("Time", [])
    ss_statuses = session_status.get("Status", [])

    start_s = None
    end_s = None
    for i, s in enumerate(ss_statuses):
        if s == "Started" and start_s is None:
            start_s = _safe_float(ss_times[i]) if i < len(ss_times) else None
        if s in ("Finished", "Finalised", "Ends"):
            end_s = _safe_float(ss_times[i]) if i < len(ss_times) else None

    session_duration_s = (end_s - start_s) if start_s is not None and end_s is not None else None

    timeline = []
    best_per_driver: dict = {}
    overall_best: Optional[float] = None

    for row in sorted(all_rows, key=lambda r: _safe_float(r.get("sesT")) or 0):
        code = row.get("drv", "")
        lap_time = _safe_float(row.get("time"))
        sess_t = _safe_float(row.get("sesT"))
        if not code or not lap_time or not sess_t:
            continue

        d_info = next((d for d in drivers if d["code"] == code), {})
        is_pb = lap_time < best_per_driver.get(code, float("inf"))
        if is_pb:
            best_per_driver[code] = lap_time
        is_overall = is_pb and lap_time < (overall_best or float("inf"))
        if is_overall:
            overall_best = lap_time

        if is_pb:
            timeline.append({
                "session_time_s": sess_t,
                "code": code,
                "team": row.get("team", d_info.get("team", "")),
                "color": d_info.get("color", "FFFFFF"),
                "lap_time_s": lap_time,
                "s1": _safe_float(row.get("s1")),
                "s2": _safe_float(row.get("s2")),
                "s3": _safe_float(row.get("s3")),
                "compound": row.get("compound", "UNKNOWN"),
                "is_personal_best": True,
                "is_overall_fastest": is_overall,
                "laps_completed": _safe_int(row.get("lap")) or 0,
            })

    leader_best = min(best_per_driver.values()) if best_per_driver else 0.0
    final_order = []
    for code, best in sorted(best_per_driver.items(), key=lambda x: x[1]):
        d_info = next((d for d in drivers if d["code"] == code), {})
        final_order.append({
            "code": code,
            "team": d_info.get("team", ""),
            "color": d_info.get("color", "FFFFFF"),
            "best_s": best,
            "gap_s": best - leader_best,
        })

    weather_out = None
    if all_rows:
        last = all_rows[-1]
        weather_out = {
            "air_temp": _safe_float(last.get("wAT")),
            "track_temp": _safe_float(last.get("wT")),
        }

    return {
        "laps": {
            "session_duration_s": session_duration_s,
            "t0_date": t0,
            "start_session_time_s": start_s,
            "timeline": timeline,
            "final_order": final_order,
        },
        "rcm_events": rcm_events,
        "weather": weather_out,
        "radio": files.get("team_radio"),
    }


def parse_qualifying(files: dict) -> dict:
    """Parse a Qualifying or Sprint Qualifying session."""
    drivers_raw = files["drivers"]
    sl = files["session_laptimes"]
    rcm_raw = files["rcm"]
    si = files["session_info"]
    t0 = si.get("t0_date", "")

    drivers = _parse_drivers(drivers_raw)
    all_rows = _laptimes_to_rows(sl)
    rcm_events = _parse_rcm(rcm_raw, t0)

    # Detect segment names from qs field, preserving order
    segment_names = []
    seen: set = set()
    for row in all_rows:
        qs = row.get("qs")
        if qs and qs not in seen:
            seen.add(qs)
            segment_names.append(qs)
    if not segment_names:
        segment_names = ["Q1", "Q2", "Q3"]

    segments_rows: dict = {s: [] for s in segment_names}
    for row in all_rows:
        qs = row.get("qs")
        if qs and qs in segments_rows:
            segments_rows[qs].append(row)

    segments_out: dict = {}
    for seg in segment_names:
        rows = segments_rows.get(seg, [])
        seg_drivers = set(r.get("drv", "") for r in rows if r.get("drv"))

        best_in_seg: dict = {}
        for row in rows:
            code = row.get("drv", "")
            lt = _safe_float(row.get("time"))
            if not code or not lt:
                continue
            if code not in best_in_seg or lt < best_in_seg[code][0]:
                best_in_seg[code] = (lt, row)

        timeline = []
        per_driver_best_so_far: dict = {}
        overall_best: Optional[float] = None

        for row in sorted(rows, key=lambda r: _safe_float(r.get("sesT")) or 0):
            code = row.get("drv", "")
            lt = _safe_float(row.get("time"))
            sess_t = _safe_float(row.get("sesT"))
            if not code or not lt or not sess_t:
                continue
            d_info = next((d for d in drivers if d["code"] == code), {})
            is_pb = lt < per_driver_best_so_far.get(code, float("inf"))
            if is_pb:
                per_driver_best_so_far[code] = lt
            is_overall = is_pb and lt < (overall_best or float("inf"))
            if is_overall:
                overall_best = lt
            if is_pb:
                timeline.append({
                    "session_time_s": sess_t, "segment": seg, "code": code,
                    "team": row.get("team", d_info.get("team", "")),
                    "color": d_info.get("color", "FFFFFF"),
                    "lap_time_s": lt,
                    "s1": _safe_float(row.get("s1")),
                    "s2": _safe_float(row.get("s2")),
                    "s3": _safe_float(row.get("s3")),
                    "compound": row.get("compound", "UNKNOWN"),
                    "is_personal_best": True, "is_overall_fastest": is_overall,
                })

        final_order = sorted(
            [{"code": c, "best_s": bt[0], "row": bt[1]} for c, bt in best_in_seg.items()],
            key=lambda x: x["best_s"]
        )
        leader_time = final_order[0]["best_s"] if final_order else 0.0

        segments_out[seg] = {
            "timeline": timeline,
            "final_order": [
                {
                    "pos": i + 1, "code": item["code"], "best_s": item["best_s"],
                    "gap_s": item["best_s"] - leader_time,
                    "compound": item["row"].get("compound", "UNKNOWN"),
                    "team": next((d["team"] for d in drivers if d["code"] == item["code"]), ""),
                    "color": next((d["color"] for d in drivers if d["code"] == item["code"]), "FFFFFF"),
                }
                for i, item in enumerate(final_order)
            ],
            "eliminated": [],
            "driver_count": len(seg_drivers),
        }

    # Post-pass: fill eliminated per segment
    seg_list = list(segments_out.keys())
    for i, seg in enumerate(seg_list):
        if i + 1 < len(seg_list):
            current = set(item["code"] for item in segments_out[seg]["final_order"])
            nxt = set(item["code"] for item in segments_out[seg_list[i + 1]]["final_order"])
            segments_out[seg]["eliminated"] = sorted(current - nxt)

    q_final = seg_list[-1] if seg_list else None
    pole = None
    if q_final and segments_out[q_final]["final_order"]:
        p = segments_out[q_final]["final_order"][0]
        pole = {"code": p["code"], "time_s": p["best_s"]}

    final_grid = segments_out.get(q_final, {}).get("final_order", []) if q_final else []
    is_sprint_quali = any("SQ" in s for s in segment_names)

    return {
        "laps": {
            "session_type": "SQ" if is_sprint_quali else "Q",
            "segments": segments_out,
            "segment_order": segment_names,
            "pole": pole,
            "final_grid": final_grid,
        },
        "rcm_events": rcm_events,
        "weather": None,
        "radio": files.get("team_radio"),
    }


def parse_session(session_type: str, files: dict) -> dict:
    """Route to the correct parser based on session_type."""
    if session_type == "Race":
        return parse_race(files)
    elif session_type in ("P1", "P2", "P3"):
        return parse_practice(files)
    elif session_type in ("Q", "SQ"):
        return parse_qualifying(files)
    elif session_type == "Sprint":
        return parse_race(files)
    else:
        raise ValueError(f"Unknown session_type: {session_type}")
