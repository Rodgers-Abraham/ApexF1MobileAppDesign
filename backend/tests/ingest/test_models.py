"""Tests for two-tier ingest validation (critical vs optional)."""

import pytest

from ingest.models import (
    DriverInfo,
    IngestValidationError,
    LapEntry,
    validate_critical_drivers,
    validate_critical_laptimes,
    validate_drivers,
    validate_session_laptimes,
)

# ── Critical lap validation ────────────────────────────────────────────────────


def test_critical_laps_valid():
    rows = [
        {"drv": "VER", "lap": 1, "time": 90.1},
        {"drv": "NOR", "lap": 1, "time": 91.0},
    ]
    result = validate_critical_laptimes(rows)
    assert len(result) == 2


def test_critical_laps_all_missing_drv():
    rows = [{"lap": 1, "time": 90.1}, {"lap": 2}]
    with pytest.raises(IngestValidationError, match="0 valid rows"):
        validate_critical_laptimes(rows)


def test_critical_laps_all_missing_lap():
    rows = [{"drv": "VER"}, {"drv": "NOR"}]
    with pytest.raises(IngestValidationError, match="0 valid rows"):
        validate_critical_laptimes(rows)


def test_critical_laps_race_missing_pos():
    # Race rows with drv/lap but no pos — should raise
    rows = [{"drv": "VER", "lap": 1, "pos": None}, {"drv": "NOR", "lap": 1}]
    with pytest.raises(IngestValidationError, match="pos.*position"):
        validate_critical_laptimes(rows, session_type="Race")


def test_critical_laps_race_valid_pos():
    rows = [{"drv": "VER", "lap": 1, "pos": 1}, {"drv": "NOR", "lap": 1, "pos": 2}]
    result = validate_critical_laptimes(rows, session_type="Race")
    assert len(result) == 2


def test_critical_laps_practice_no_pos_ok():
    # Practice rows without pos are fine — pos is optional for practice
    rows = [{"drv": "VER", "lap": 1, "time": 90.1}]
    result = validate_critical_laptimes(rows, session_type="P1")
    assert len(result) == 1


def test_optional_laps_missing_sectors_ok():
    # Rows missing s1/s2/s3 (optional) should not raise
    rows = [{"drv": "VER", "lap": 1}]
    valid, errors = validate_session_laptimes(rows)
    assert len(valid) == 1
    assert len(errors) == 0
    assert valid[0].s1 is None


# ── Critical driver validation ─────────────────────────────────────────────────


def test_critical_drivers_valid():
    rows = [
        {
            "driver": "VER",
            "team": "Red Bull Racing",
            "tc": "3671C6",
            "dn": 1,
            "fn": "Max",
            "ln": "Verstappen",
        }
    ]
    result = validate_critical_drivers(rows)
    assert len(result) == 1


def test_critical_drivers_tc_optional():
    # tc (team colour) is optional — entries with only driver+team are valid.
    # Many 2024 TracingInsights datasets omit tc entirely.
    rows = [
        {"driver": "VER", "team": "Red Bull Racing"},
        {"driver": "NOR", "team": "McLaren"},
    ]
    result = validate_critical_drivers(rows)
    assert len(result) == 2


def test_critical_drivers_empty_list():
    with pytest.raises(IngestValidationError):
        validate_critical_drivers([])


def test_optional_drivers_missing_url_ok():
    # url is optional — should not cause errors
    rows = [
        {
            "driver": "VER",
            "team": "Red Bull Racing",
            "tc": "3671C6",
            "dn": 1,
            "fn": "Max",
            "ln": "Verstappen",
        }
    ]
    valid, errors = validate_drivers(rows)
    assert len(valid) == 1
    assert len(errors) == 0
    assert valid[0].url is None
