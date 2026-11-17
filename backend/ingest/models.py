"""Pydantic v2 models for TracingInsights session file input validation."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


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
