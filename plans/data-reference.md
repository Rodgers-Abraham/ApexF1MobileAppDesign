# Data Reference — TracingInsights Session Files

Source: https://github.com/TracingInsights/{year}/
Authoritative reference: `DATA_REFERENCE.md` in each season repo.

## Season-to-repo mapping

Owner: `TracingInsights` (GitHub **user**, NOT an org) for all years 2018–2026.
Archive mirror: `TracingInsights-Archive` for 2018–2025 (fallback only).
Config: `SEASON_REPOS` and `ARCHIVE_REPOS` dicts in `backend/services/tracing_insights.py`.

## Folder layout

```
{year}/{Event Name}/{Session Type}/
  {DRV}/laptimes.json    ← per-driver lap data (3-letter code)
  session_laptimes.json  ← all drivers combined (same schema as per-driver)
  drivers.json           ← driver/team metadata
  rcm.json               ← race control messages
  session_info.json      ← track status stream, session status stream
  weather.json           ← weather samples (~1/min)
  team_radio.json        ← optional; clip metadata only (no audio)
```

Session Type folder names → DB `session_type` enum:
- `"Practice 1"` → `P1`, `"Practice 2"` → `P2`, `"Practice 3"` → `P3`
- `"Qualifying"` → `Q`, `"Sprint Qualifying"` → `SQ`
- `"Sprint"` → `Sprint`, `"Race"` → `Race`

## Pydantic models (input validation)

See `backend/ingest/models.py` for the runtime versions. Reproduced here for reference.

```python
from pydantic import BaseModel, Field
from typing import Optional

class DriverInfo(BaseModel):
    driver: str          # 3-letter code, e.g. "VER"
    team: str
    dn: int              # car number
    fn: str              # first name
    ln: str              # last name
    tc: str              # team colour hex, e.g. "4781D7"
    url: Optional[str] = None  # headshot URL

class LapEntry(BaseModel):
    drv: str             # 3-letter driver code
    lap: int
    time: Optional[float] = None   # lap time seconds (None if no time / pit lap)
    sesT: Optional[float] = None   # session time at lap end
    lST: Optional[float] = None    # lap start time (seconds since session start)
    s1: Optional[float] = None
    s2: Optional[float] = None
    s3: Optional[float] = None
    compound: Optional[str] = None  # "SOFT","MEDIUM","HARD","INTERMEDIATE","WET","UNKNOWN"
    life: Optional[int] = None
    fresh: Optional[bool] = None
    stint: Optional[int] = None
    pin: Optional[float] = None    # pit-in session time
    pout: Optional[float] = None   # pit-out session time
    pos: Optional[int] = None      # None for practice/qualifying crash laps
    status: Optional[str] = None   # track-status codes active during lap, e.g. "1", "24"
    pb: Optional[bool] = None      # personal best
    deleted: Optional[bool] = Field(None, alias="del")  # deleted lap
    delR: Optional[str] = None     # deletion reason
    qs: Optional[str] = None       # qualifying segment: "Q1","Q2","Q3","SQ1","SQ2","SQ3"
    iacc: Optional[bool] = None    # timing accurate
    ff1G: Optional[bool] = None    # FastF1-generated lap

class RcmEntry(BaseModel):
    time: Optional[float] = None
    cat: Optional[str] = None      # "Flag","Drs","CarEvent","Other"
    msg: Optional[str] = None
    status: Optional[str] = None
    flag: Optional[str] = None     # "GREEN","RED","YELLOW","CLEAR","CHEQUERED"
    scope: Optional[str] = None    # "Track","Sector","Driver"
    sector: Optional[int] = None
    dNum: Optional[str] = None
    lap: Optional[int] = None

class WeatherEntry(BaseModel):
    wT: Optional[float] = None     # session time of sample (seconds)
    wAT: Optional[float] = None    # air temp °C
    wH: Optional[float] = None     # humidity %
    wP: Optional[float] = None     # pressure mbar
    wR: Optional[bool] = None      # rainfall
    wTT: Optional[float] = None    # track temp °C
    wWD: Optional[float] = None    # wind direction degrees (0–359)
    wWS: Optional[float] = None    # wind speed m/s
```

## Track status codes (`session_info.json` → `track_status.Status`)

| Code | Meaning |
|---|---|
| `"1"` | Track clear |
| `"2"` | Yellow flag |
| `"4"` | Safety Car |
| `"5"` | Red flag |
| `"6"` | VSC deployed |
| `"7"` | VSC ending |

## Notes for ingest

- **`lST` (lap start time)** is present on every lap entry. Store it in the per-lap payload to support "Real time" replay speed (actual lap duration = `laps[N+1].lST - laps[N].lST`).
- **`del`** is a Python reserved word; use Pydantic alias `"del"` on a field named `deleted`.
- **Track-status changes** for flag banners come from `session_info.json` → `track_status`, not only from `rcm.json`. `rcm.json` messages carry human-readable text; `track_status` has the structured code transitions.
- **`qs` field** on each lap identifies the qualifying segment (`Q1`/`Q2`/`Q3` or `SQ1`/`SQ2`/`SQ3`).
- **`session_laps.json`** combines all drivers; individual driver `laptimes.json` files inside `{DRV}/` have the same schema. The ingest uses `session_laptimes.json` for efficiency.
