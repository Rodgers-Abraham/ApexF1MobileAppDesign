import os
import re
import requests
from datetime import datetime, timezone, timedelta
from typing import Optional
from dataclasses import dataclass

RAW_BASE = "https://raw.githubusercontent.com/TracingInsights/{year}/main/{path}"
API_BASE = "https://api.github.com"
REQUIRED_FILES = {"drivers.json", "session_laptimes.json", "rcm.json", "session_info.json"}


@dataclass
class SessionRef:
    year: int
    event: str
    session_type: str
    last_commit_sha: str
    last_commit_at: datetime  # UTC


def normalize_session_type(raw: str) -> Optional[str]:
    """Map TracingInsights folder name to our DB session_type enum."""
    mapping = {
        "Practice 1": "P1", "Practice 2": "P2", "Practice 3": "P3",
        "Qualifying": "Q", "Sprint Qualifying": "SQ",
        "Sprint": "Sprint", "Race": "Race",
    }
    return mapping.get(raw)


class TracingInsightsFetcher:
    def __init__(self, github_token: Optional[str] = None):
        self.token = github_token or os.getenv("GITHUB_TOKEN", "")
        self._headers = {"Accept": "application/vnd.github.v3+json"}
        if self.token:
            self._headers["Authorization"] = f"token {self.token}"
        self._session = requests.Session()
        self._session.headers.update(self._headers)

    def list_available_years(self) -> list:
        """Return sorted list of years with TracingInsights repos."""
        url = f"{API_BASE}/orgs/TracingInsights/repos?per_page=100&type=public"
        resp = self._session.get(url, timeout=15)
        resp.raise_for_status()
        repos = resp.json()
        years = []
        for r in repos:
            m = re.match(r'^(\d{4})$', r.get("name", ""))
            if m:
                years.append(int(m.group(1)))
        return sorted(years)

    def list_sessions(self, year: int) -> list:
        """List all session folders available for a year with their last commit info."""
        url = f"{API_BASE}/repos/TracingInsights/{year}/contents/"
        resp = self._session.get(url, timeout=15)
        if resp.status_code == 404:
            return []
        resp.raise_for_status()
        items = resp.json()

        sessions = []
        for event_item in items:
            if event_item["type"] != "dir":
                continue
            event = event_item["name"]
            url2 = f"{API_BASE}/repos/TracingInsights/{year}/contents/{event}"
            r2 = self._session.get(url2, timeout=15)
            if r2.status_code != 200:
                continue
            for sess_item in r2.json():
                if sess_item["type"] != "dir":
                    continue
                raw_type = sess_item["name"]
                normalized = normalize_session_type(raw_type)
                if not normalized:
                    continue
                commit_url = (
                    f"{API_BASE}/repos/TracingInsights/{year}/commits"
                    f"?path={event}/{raw_type}&per_page=1"
                )
                cr = self._session.get(commit_url, timeout=15)
                if cr.status_code != 200 or not cr.json():
                    continue
                commit = cr.json()[0]
                sha = commit["sha"]
                committed_at = datetime.fromisoformat(
                    commit["commit"]["committer"]["date"].replace("Z", "+00:00")
                )
                sessions.append(SessionRef(
                    year=year,
                    event=event,
                    session_type=normalized,
                    last_commit_sha=sha,
                    last_commit_at=committed_at,
                ))
        return sessions

    def is_stable(self, ref: SessionRef, min_age_minutes: int = 10) -> bool:
        """Return True if the session folder hasn't been updated in min_age_minutes."""
        age = datetime.now(timezone.utc) - ref.last_commit_at
        return age >= timedelta(minutes=min_age_minutes)

    def has_required_files(self, year: int, event: str, raw_session_type: str) -> bool:
        """Check all required files exist in the session folder."""
        url = f"{API_BASE}/repos/TracingInsights/{year}/contents/{event}/{raw_session_type}"
        resp = self._session.get(url, timeout=15)
        if resp.status_code != 200:
            return False
        filenames = {item["name"] for item in resp.json() if item["type"] == "file"}
        return REQUIRED_FILES.issubset(filenames)

    def _raw_session_type(self, normalized: str) -> str:
        """Reverse mapping from our DB enum to TracingInsights folder name."""
        reverse = {
            "P1": "Practice 1", "P2": "Practice 2", "P3": "Practice 3",
            "Q": "Qualifying", "SQ": "Sprint Qualifying",
            "Sprint": "Sprint", "Race": "Race",
        }
        return reverse[normalized]

    def fetch_session_files(self, year: int, event: str, session_type: str) -> dict:
        """
        Fetch all required files for a session.
        session_type is our DB enum (P1/Q/Race/etc.).
        """
        raw_type = self._raw_session_type(session_type)
        base = f"{year}/{event}/{raw_type}"

        def fetch(filename: str, required: bool = True):
            url = RAW_BASE.format(year=year, path=f"{base}/{filename}")
            resp = self._session.get(url, timeout=20)
            if resp.status_code == 404:
                if required:
                    raise FileNotFoundError(f"Required file missing: {filename}")
                return None
            resp.raise_for_status()
            return resp.json()

        return {
            "drivers": fetch("drivers.json"),
            "session_laptimes": fetch("session_laptimes.json"),
            "rcm": fetch("rcm.json"),
            "session_info": fetch("session_info.json"),
            "weather": fetch("weather.json", required=False),
            "team_radio": fetch("team_radio.json", required=False),
        }
