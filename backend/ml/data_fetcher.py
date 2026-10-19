"""
Real F1 historical data fetcher using the Ergast / Jolpica API.
Builds a proper dataset of race outcomes with realistic features.
"""
import time
import requests
import pandas as pd
from typing import List, Dict, Optional
from datetime import datetime

JOLPICA_BASE = "https://api.jolpi.ca/ergast/f1"


def fetch_seasons(start_year: int = 1950, end_year: Optional[int] = None):
    """Fetch list of F1 seasons from Ergast API."""
    if end_year is None:
        end_year = datetime.now().year
    return list(range(start_year, end_year + 1))


def fetch_race_results(year: int) -> List[Dict]:
    """Fetch all race results for a given season from the Ergast API."""
    url = f"{JOLPICA_BASE}/{year}/results.json?limit=1000"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        return data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
    except Exception as e:
        print(f"Error fetching race results for {year}: {e}")
        return []


def fetch_driver_standings(year: int) -> Dict[str, Dict]:
    """Fetch driver standings for a season to get championship points at end of year."""
    url = f"{JOLPICA_BASE}/{year}/driverStandings.json?limit=1000"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        standings = data.get("MRData", {}).get("StandingsTable", {}).get("StandingsLists", [])
        if not standings:
            return {}

        driver_map = {}
        for standing in standings[0].get("DriverStandings", []):
            driver_id = standing.get("Driver", {}).get("driverId", "")
            if driver_id:
                driver_map[driver_id] = {
                    "championship_points": float(standing.get("points", 0)),
                    "championship_position": int(standing.get("position", 999)),
                    "wins": int(standing.get("wins", 0)),
                }
        return driver_map
    except Exception as e:
        print(f"Error fetching driver standings for {year}: {e}")
        return {}


def fetch_constructor_standings(year: int) -> Dict[str, int]:
    """Fetch constructor standings for a season."""
    url = f"{JOLPICA_BASE}/{year}/constructorStandings.json?limit=1000"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        standings = data.get("MRData", {}).get("StandingsTable", {}).get("StandingsLists", [])
        if not standings:
            return {}

        constructor_map = {}
        for standing in standings[0].get("ConstructorStandings", []):
            constructor_id = standing.get("Constructor", {}).get("constructorId", "")
            if constructor_id:
                constructor_map[constructor_id] = int(standing.get("position", 999))
        return constructor_map
    except Exception as e:
        print(f"Error fetching constructor standings for {year}: {e}")
        return {}


# Country-to-nationality mapping for home race detection (simplified)
COUNTRY_NATIONALITIES = {
    "United Kingdom": ["British", "UK"],
    "Great Britain": ["British", "UK"],
    "United States": ["American"],
    "Italy": ["Italian"],
    "Monaco": ["Monegasque"],
    "Netherlands": ["Dutch"],
    "France": ["French"],
    "Germany": ["German"],
    "Brazil": ["Brazilian"],
    "Australia": ["Australian"],
    "Spain": ["Spanish"],
    "Mexico": ["Mexican"],
    "Canada": ["Canadian"],
    "Finland": ["Finnish"],
    "Japan": ["Japanese"],
    "China": ["Chinese"],
    "Belgium": ["Belgian"],
    "Austria": ["Austrian"],
    "Argentina": ["Argentine"],
    "New Zealand": ["New Zealander"],
    "Thailand": ["Thai"],
}


def driver_is_home_race(race_country: str, driver_nationality: str) -> int:
    """Check if a race is the driver's home race."""
    if not race_country or not driver_nationality:
        return 0
    race_country = race_country.strip()
    if race_country in COUNTRY_NATIONALITIES:
        if driver_nationality in COUNTRY_NATIONALITIES[race_country]:
            return 1
    return 1 if race_country in driver_nationality else 0


def process_race_data(races: List[Dict], standings: Dict, constructor_standings: Dict) -> pd.DataFrame:
    """Process raw race data into a structured DataFrame for ML training."""
    records = {
        "grid_position": [],
        "constructor_rank": [],
        "average_finish_last_5": [],
        "championship_points": [],
        "home_race": [],
        "wet_condition": [],
        "is_winner": [],
    }

    # Build driver career stats
    driver_recent_results: Dict[str, List[float]] = {}

    for race in races:
        race_country = race.get("Circuit", {}).get("Location", {}).get("country", "")

        for result in race.get("Results", []):
            driver_id = result.get("Driver", {}).get("driverId", "")
            constructor_id = result.get("Constructor", {}).get("constructorId", "")
            grid_pos = int(result.get("grid", 99))
            finish_pos = int(result.get("position", 99))
            driver_nationality = result.get("Driver", {}).get("nationality", "")

            # Constructor rank
            cons_rank = constructor_standings.get(constructor_id, 999)

            # Average finish in last 5 races
            if driver_id not in driver_recent_results:
                driver_recent_results[driver_id] = []

            recent = driver_recent_results[driver_id][-5:]
            if recent:
                recent_avg = sum(recent) / len(recent)
            else:
                recent_avg = finish_pos

            # Home race check
            is_home = driver_is_home_race(race_country, driver_nationality)

            # Championship points (use end-of-year points as proxy for season-long form)
            driver_champ = standings.get(driver_id, {}).get("championship_points", 0)

            # Update driver recent results
            driver_recent_results[driver_id].append(finish_pos)

            records["grid_position"].append(grid_pos)
            records["constructor_rank"].append(cons_rank)
            records["average_finish_last_5"].append(recent_avg)
            records["championship_points"].append(driver_champ)
            records["home_race"].append(is_home)
            records["wet_condition"].append(0)  # No weather data in Ergast API
            records["is_winner"].append(1 if finish_pos == 1 else 0)

    df = pd.DataFrame(records)
    return df.dropna()


def build_dataset(start_year: int = 1950, end_year: Optional[int] = None) -> pd.DataFrame:
    """Build a comprehensive dataset of historical F1 race results for ML training."""
    years = fetch_seasons(start_year, end_year)
    all_data = []

    for year in years:
        print(f"Fetching data for {year}...")
        races = fetch_race_results(year)
        standings = fetch_driver_standings(year)
        constructor_standings = fetch_constructor_standings(year)

        if races:
            df = process_race_data(races, standings, constructor_standings)
            if not df.empty:
                all_data.append(df)

        # Respect rate limits
        time.sleep(0.5)

    if not all_data:
        raise ValueError("Failed to fetch any F1 data from the API. Please check your network connection.")

    return pd.concat(all_data, ignore_index=True)


if __name__ == "__main__":
    df = build_dataset(start_year=2015)
    print(f"Dataset shape: {df.shape}")
    print(df.head())
    print(f"Winner distribution:\n{df['is_winner'].value_counts()}")
