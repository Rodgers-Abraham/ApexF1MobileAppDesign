# backend/ingest/runner.py
"""
Ingest runner: detect new TracingInsights sessions and process them.

Usage:
  python -m ingest.runner --check              # process new/changed sessions
  python -m ingest.runner --backfill           # process all available seasons
  python -m ingest.runner --session "2026/Australian_Grand_Prix/Race"
  python -m ingest.runner --migrate            # run DB migrations
"""
import argparse
import logging
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("ingest")


def _process_session(fetcher, year: int, event: str, session_type: str, source_hash: str) -> bool:
    """Fetch, parse, event-engine, cross-check, upsert one session."""
    from ingest.parser import parse_session, parse_meta
    from ingest.event_engine import build_race_events
    from ingest.cross_check import cross_check
    from ingest.upsert import upsert_session, mark_failed

    log.info(f"Processing {year}/{event}/{session_type} (hash={source_hash[:8] if source_hash else 'n/a'})")

    try:
        files = fetcher.fetch_session_files(year, event, session_type)
    except Exception as e:
        log.error(f"  FETCH FAILED: {e}")
        mark_failed(year, event, session_type, f"Fetch error: {e}")
        return False

    try:
        meta = parse_meta(files["drivers"], files["session_info"], event, session_type)
        parsed = parse_session(session_type, files)
    except Exception as e:
        log.error(f"  PARSE FAILED: {e}")
        mark_failed(year, event, session_type, f"Parse error: {e}")
        return False

    if session_type in ("Race", "Sprint"):
        try:
            race_events = build_race_events(parsed)
            parsed["rcm_events"] = race_events
        except Exception as e:
            log.warning(f"  Event engine warning: {e}")

    try:
        passed, jolpica_results, err_msg = cross_check(parsed, year, event, session_type)
    except Exception as e:
        passed, jolpica_results, err_msg = True, None, None
        log.warning(f"  Cross-check exception (non-fatal): {e}")

    if not passed:
        log.error(f"  CROSS-CHECK FAILED: {err_msg}")
        mark_failed(year, event, session_type, err_msg)
        return False

    try:
        session_id = upsert_session(
            year=year,
            event=event,
            session_type=session_type,
            source_hash=source_hash,
            meta=meta,
            parsed=parsed,
            jolpica_results=jolpica_results,
            status="ready",
        )
        log.info(f"  READY: {session_id}")
        return True
    except Exception as e:
        log.error(f"  UPSERT FAILED: {e}")
        mark_failed(year, event, session_type, f"Upsert error: {e}")
        return False


def _get_existing_hashes(year: int) -> dict:
    """Return {(year, event, session_type): source_hash} for all ready sessions."""
    from core.database import get_db_connection
    with get_db_connection() as conn:
        rows = conn.execute(
            "SELECT event, session_type, source_hash FROM sessions WHERE year=? AND status='ready'",
            (year,),
        ).fetchall()
    return {(year, row["event"], row["session_type"]): row["source_hash"] for row in rows}


def run_check(github_token: str, years=None):
    """Detect and process new or changed sessions."""
    from services.tracing_insights import TracingInsightsFetcher
    fetcher = TracingInsightsFetcher(github_token)

    if years is None:
        years = fetcher.list_available_years()
        log.info(f"Available years: {years}")

    for year in years:
        existing = _get_existing_hashes(year)
        try:
            sessions = fetcher.list_sessions(year)
        except Exception as e:
            log.error(f"Failed to list sessions for {year}: {e}")
            continue

        for ref in sessions:
            key = (ref.year, ref.event, ref.session_type)
            if existing.get(key) == ref.last_commit_sha:
                continue
            if not fetcher.is_stable(ref):
                log.info(f"  Skipping {ref.event}/{ref.session_type} (committed too recently)")
                continue
            raw_type = fetcher._raw_session_type(ref.session_type)
            if not fetcher.has_required_files(year, ref.event, raw_type):
                log.info(f"  Skipping {ref.event}/{ref.session_type} (missing required files)")
                continue
            for attempt in range(3):
                success = _process_session(fetcher, year, ref.event, ref.session_type, ref.last_commit_sha)
                if success:
                    break
                wait = 2 ** attempt
                log.info(f"  Retry in {wait}s...")
                time.sleep(wait)


def run_single(year: int, event: str, session_type: str, github_token: str):
    """Re-ingest a single session by force."""
    from services.tracing_insights import TracingInsightsFetcher
    fetcher = TracingInsightsFetcher(github_token)
    try:
        sessions = fetcher.list_sessions(year)
        ref = next((s for s in sessions if s.event == event and s.session_type == session_type), None)
        source_hash = ref.last_commit_sha if ref else "manual"
    except Exception:
        source_hash = "manual"
    _process_session(fetcher, year, event, session_type, source_hash)


def run_migrate():
    """Run database migrations."""
    from core.database import init_db
    init_db()
    log.info("Migration complete.")


def main():
    parser = argparse.ArgumentParser(description="Apex F1 Ingest Runner")
    parser.add_argument("--check", action="store_true", help="Check and process new sessions")
    parser.add_argument("--backfill", action="store_true", help="Backfill all available seasons")
    parser.add_argument("--session", type=str, help="Ingest single session: 'year/event/session_type'")
    parser.add_argument("--migrate", action="store_true", help="Run DB migrations")
    parser.add_argument("--year", type=int, help="Limit to specific year")
    args = parser.parse_args()

    github_token = os.getenv("GITHUB_TOKEN", "")
    if not args.migrate and not github_token:
        log.warning("GITHUB_TOKEN not set — unauthenticated API calls limited to 60/hour")

    if args.migrate:
        run_migrate()
    elif args.session:
        parts = args.session.split("/")
        if len(parts) != 3:
            log.error("--session must be 'year/event/session_type'")
            sys.exit(1)
        # Accept both "Australian_Grand_Prix" and "Australian Grand Prix"
        event_name = parts[1].replace("_", " ")
        run_single(int(parts[0]), event_name, parts[2], github_token)
    elif args.check or args.backfill:
        years = [args.year] if args.year else None
        run_check(github_token, years)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
