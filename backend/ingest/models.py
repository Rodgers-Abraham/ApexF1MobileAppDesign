"""Pydantic v2 models for TracingInsights session file input validation."""

from __future__ import annotations

import logging
from typing import Optional

from pydantic import BaseModel, Field

log = logging.getLogger("ingest")


class DriverInfo(BaseModel):
    driver: str
    team: str
    dn: int
    fn: str
    ln: str
    tc: str
    url: Optional[str] = None

    model_config = {"extra": "ignore"}


class LapEntry(BaseModel):
    drv: str
    lap: int
    time: Optional[float] = None
    sesT: Optional[float] = None
    lST: Optional[float] = None
    s1: Optional[float] = None
    s2: Optional[float] = None
    s3: Optional[float] = None
    compound: Optional[str] = None
    life: Optional[int] = None
    fresh: Optional[bool] = None
    stint: Optional[int] = None
    pin: Optional[float] = None
    pout: Optional[float] = None
    pos: Optional[int] = None
    status: Optional[str] = None
    pb: Optional[bool] = None
    deleted: Optional[bool] = Field(None, alias="del")
    delR: Optional[str] = None
    qs: Optional[str] = None
    iacc: Optional[bool] = None
    ff1G: Optional[bool] = None

    model_config = {"extra": "ignore", "populate_by_name": True}


class RcmEntry(BaseModel):
    time: Optional[float] = None
    cat: Optional[str] = None
    msg: Optional[str] = None
    status: Optional[str] = None
    flag: Optional[str] = None
    scope: Optional[str] = None
    sector: Optional[int] = None
    dNum: Optional[str] = None
    lap: Optional[int] = None

    model_config = {"extra": "ignore"}


class WeatherEntry(BaseModel):
    wT: Optional[float] = None
    wAT: Optional[float] = None
    wH: Optional[float] = None
    wP: Optional[float] = None
    wR: Optional[bool] = None
    wTT: Optional[float] = None
    wWD: Optional[float] = None
    wWS: Optional[float] = None

    model_config = {"extra": "ignore"}


class IngestValidationError(Exception):
    """Raised when critical session data is missing or malformed."""

    pass


def validate_critical_laptimes(raw: list, session_type: str = "") -> list:
    """
    Critical validation for session_laptimes.json.

    Critical fields: drv and lap must be present on every row. Rows missing
    either are dropped with a warning.

    Raises IngestValidationError if:
    - No valid rows remain after filtering.
    - session_type is 'Race' or 'Sprint' and no row has a pos value.

    Optional fields (s1/s2/s3, compound, lST, etc.) are not checked here.
    Returns the list of raw dicts that passed the critical check.
    """
    valid_rows = []
    skipped = []
    for i, entry in enumerate(raw):
        drv = entry.get("drv") if isinstance(entry, dict) else None
        lap = entry.get("lap") if isinstance(entry, dict) else None
        if not drv or lap is None:
            skipped.append(i)
        else:
            valid_rows.append(entry)

    if skipped:
        log.warning(
            f"session_laptimes critical check: skipped {len(skipped)} rows missing drv/lap "
            f"(first 3 indices: {skipped[:3]})"
        )

    if not valid_rows:
        raise IngestValidationError(
            f"session_laptimes.json: 0 valid rows out of {len(raw)} — "
            f"all entries are missing drv or lap. Session cannot be ingested."
        )

    if session_type in ("Race", "Sprint"):
        rows_with_pos = [r for r in valid_rows if r.get("pos") not in (None, "None")]
        if not rows_with_pos:
            raise IngestValidationError(
                f"session_laptimes.json: Race/Sprint session has {len(valid_rows)} lap entries "
                f"but none have a pos (position) field. Cannot determine race order."
            )

    return valid_rows


def validate_critical_drivers(raw: list) -> list:
    """
    Critical validation for drivers.json.

    Critical fields: driver (3-letter code), team, tc (team colour hex).
    Rows missing any are dropped with a warning.

    Raises IngestValidationError if no valid driver entries remain.
    Returns the list of raw dicts that passed the critical check.
    """
    valid_rows = []
    skipped = []
    for i, entry in enumerate(raw):
        if not isinstance(entry, dict):
            skipped.append(f"Row {i}: not a dict")
            continue
        if not entry.get("driver") or not entry.get("team"):
            skipped.append(
                f"Row {i}: missing driver/team (got {list(entry.keys())})"
            )
        else:
            valid_rows.append(entry)

    if skipped:
        log.warning(
            f"drivers.json critical check: skipped {len(skipped)} entries: {skipped[:3]}"
        )

    if not valid_rows:
        raise IngestValidationError(
            f"drivers.json: 0 valid driver entries out of {len(raw)} — "
            f"all missing driver or team."
        )

    return valid_rows


def validate_session_laptimes(raw: list) -> tuple[list[LapEntry], list[str]]:
    """Validate session_laptimes entries. Returns (valid, errors)."""
    valid, errors = [], []
    for i, entry in enumerate(raw):
        try:
            valid.append(LapEntry.model_validate(entry))
        except Exception as exc:
            errors.append(f"Row {i}: {exc}")
    return valid, errors


def validate_drivers(raw: list) -> tuple[list[DriverInfo], list[str]]:
    """Validate drivers.json entries. Returns (valid, errors)."""
    valid, errors = [], []
    for i, entry in enumerate(raw):
        try:
            valid.append(DriverInfo.model_validate(entry))
        except Exception as exc:
            errors.append(f"Row {i}: {exc}")
    return valid, errors
