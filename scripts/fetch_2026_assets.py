#!/usr/bin/env python3
"""
Downloads and organizes official 2026 Formula 1 assets:
- Fonts (Formula1-Regular, Formula1-Bold, Formula1-Black, Formula1-Wide)
- Team Logos, Chassis & Power Unit data, Team Colors
- Driver Portraits, Numbers, Helmets, Flags
- 2026 Official Calendar Schedule
"""
import os
import re
import json
import time
import requests
from bs4 import BeautifulSoup
from concurrent.futures import ThreadPoolExecutor

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS_DIR = os.path.join(BASE_DIR, "frontend", "assets")
FONTS_DIR = os.path.join(ASSETS_DIR, "fonts")
TEAMS_DIR = os.path.join(ASSETS_DIR, "teams")
DRIVERS_DIR = os.path.join(ASSETS_DIR, "drivers")
HELMETS_DIR = os.path.join(ASSETS_DIR, "helmets")
NUMBERS_DIR = os.path.join(ASSETS_DIR, "numbers")

for d in [FONTS_DIR, TEAMS_DIR, DRIVERS_DIR, HELMETS_DIR, NUMBERS_DIR]:
    os.makedirs(d, exist_ok=True)

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}

def download_file(url, target_path, timeout=10):
    if os.path.exists(target_path) and os.path.getsize(target_path) > 500:
        return True
    try:
        if url.startswith("/"):
            url = f"https://turn1visuals.com{url}"
        resp = requests.get(url, headers=HEADERS, timeout=timeout)
        if resp.status_code == 200 and len(resp.content) > 100:
            with open(target_path, "wb") as f:
                f.write(resp.content)
            return True
        else:
            print(f"Failed {url}: HTTP {resp.status_code}")
    except Exception as e:
        print(f"Error downloading {url}: {e}")
    return False

# 1. Download Fonts
font_urls = {
    "Formula1-Regular.otf": "https://turn1visuals.com/f1-2026-assets/fonts/formula1/Formula1-Regular.otf",
    "Formula1-Bold.otf": "https://turn1visuals.com/f1-2026-assets/fonts/formula1/Formula1-Bold.otf",
    "Formula1-Black.otf": "https://turn1visuals.com/f1-2026-assets/fonts/formula1/Formula1-Black.otf",
    "Formula1-Wide.otf": "https://turn1visuals.com/f1-2026-assets/fonts/formula1/Formula1-Wide.otf",
    "Formula1-Italic.otf": "https://turn1visuals.com/f1-2026-assets/fonts/formula1/Formula1-Italic.otf",
}

print("=== Downloading Fonts ===")
for name, url in font_urls.items():
    dest = os.path.join(FONTS_DIR, name)
    ok = download_file(url, dest)
    print(f"Font {name}: {'OK' if ok else 'FAIL'} ({os.path.getsize(dest) if ok else 0} bytes)")

# 2. Parse HTML
html_path = os.path.join(BASE_DIR, "backend", "turn1visuals.html")
with open(html_path, "r", encoding="utf-8") as f:
    soup = BeautifulSoup(f.read(), "html.parser")

# 3. Parse and Download Teams
print("\n=== Parsing & Downloading Teams ===")
teams_data = []
teams_sec = soup.find("section", id="tab-teams")
if teams_sec:
    for tr in teams_sec.find_all("tr")[1:]:
        tds = tr.find_all("td")
        if len(tds) < 4:
            continue
        team_name = tds[0].text.strip()
        chassis_pu_raw = tds[2].text.strip()
        
        # Split chassis and power unit
        parts = chassis_pu_raw.split(" ", 1)
        chassis = parts[0] if len(parts) > 0 else ""
        power_unit = parts[1] if len(parts) > 1 else ""
        
        # Colors
        color_text = tds[4].text.strip() if len(tds) > 4 else ""
        hexes = re.findall(r"#[0-9a-fA-F]{6}", color_text)
        primary_color = hexes[0] if len(hexes) > 0 else "#FFFFFF"
        secondary_color = hexes[1] if len(hexes) > 1 else "#000000"

        # Images
        imgs = [img["src"] for img in tr.find_all("img") if img.get("src")]
        slug = team_name.lower().replace(" ", "").replace("-", "")

        logo_color_url = ""
        logo_white_url = ""
        car_left_url = ""
        car_front_url = ""

        for u in imgs:
            if "logowhite.svg" in u:
                logo_white_url = u
            elif "logo.svg" in u:
                logo_color_url = u
            elif "carleft" in u:
                car_left_url = u
            elif "carfront" in u:
                car_front_url = u

        # Fallbacks
        if not logo_white_url and imgs:
            logo_white_url = imgs[0]
        if not logo_color_url and imgs:
            logo_color_url = imgs[0]

        logo_white_local = f"assets/teams/{slug}_white.svg"
        logo_color_local = f"assets/teams/{slug}_color.svg"
        car_front_local = f"assets/teams/{slug}_car_front.png"

        if logo_white_url:
            download_file(logo_white_url, os.path.join(TEAMS_DIR, f"{slug}_white.svg"))
        if logo_color_url:
            download_file(logo_color_url, os.path.join(TEAMS_DIR, f"{slug}_color.svg"))
        if car_front_url:
            download_file(car_front_url, os.path.join(TEAMS_DIR, f"{slug}_car_front.png"))

        team_entry = {
            "name": team_name,
            "slug": slug,
            "chassis": chassis,
            "power_unit": power_unit,
            "chassis_pu": chassis_pu_raw,
            "primary_color": primary_color,
            "secondary_color": secondary_color,
            "logo_color_url": logo_color_url,
            "logo_white_url": logo_white_url,
            "logo_white_asset": logo_white_local,
            "logo_color_asset": logo_color_local,
            "car_front_url": car_front_url,
            "car_front_asset": car_front_local if car_front_url else ""
        }
        teams_data.append(team_entry)
        print(f"Team: {team_name} | Chassis: {chassis} | PU: {power_unit} | Color: {primary_color}")

# 4. Parse and Download Drivers
print("\n=== Parsing & Downloading Drivers ===")
drivers_data = []
drivers_sec = soup.find("section", id="tab-drivers")
if drivers_sec:
    for tr in drivers_sec.find_all("tr")[1:]:
        tds = tr.find_all("td")
        if len(tds) < 6:
            continue
        driver_name = tds[0].text.strip()
        code = tds[1].text.strip()
        team = tds[2].text.strip()
        helmet_url = ""
        flag_url = ""
        born = tds[6].text.strip() if len(tds) > 6 else ""

        portrait_square = ""
        portrait_front = ""
        number_white_url = ""

        slug = driver_name.lower().replace(" ", "_")

        for img in tr.find_all("img"):
            src = img.get("src", "")
            if "portrait-circle" in img.get("class", []):
                portrait_square = src
            elif "driverhelmets" in src:
                helmet_url = src
            elif "flags" in src:
                flag_url = src
            elif "front.png" in src and not portrait_front:
                portrait_front = src
            elif "numberwhite.svg" in src:
                number_white_url = src

        country = tds[5].text.strip() if len(tds) > 5 else ""

        # Local asset files
        portrait_local = f"assets/drivers/{slug}_portrait.png"
        helmet_local = f"assets/helmets/{slug}_helmet.png"
        number_local = f"assets/numbers/{slug}_number.svg"

        if portrait_square:
            download_file(portrait_square, os.path.join(DRIVERS_DIR, f"{slug}_portrait.png"))
        if helmet_url:
            download_file(helmet_url, os.path.join(HELMETS_DIR, f"{slug}_helmet.png"))
        if number_white_url:
            download_file(number_white_url, os.path.join(NUMBERS_DIR, f"{slug}_number.svg"))

        driver_entry = {
            "name": driver_name,
            "code": code,
            "team": team,
            "country": country,
            "born": born,
            "portrait_square_url": portrait_square,
            "portrait_front_url": portrait_front,
            "portrait_asset": portrait_local if portrait_square else "",
            "helmet_url": helmet_url,
            "helmet_asset": helmet_local if helmet_url else "",
            "number_white_url": number_white_url,
            "number_asset": number_local if number_white_url else ""
        }
        drivers_data.append(driver_entry)
        print(f"Driver: {driver_name} ({code}) - {team}")

# 5. Parse Schedule
print("\n=== Parsing Schedule ===")
schedule_data = []
sched_sec = soup.find("section", id="tab-schedule")
if sched_sec:
    for tr in sched_sec.find_all("tr")[1:]:
        tds = tr.find_all("td")
        if len(tds) >= 4:
            round_no = tds[0].text.strip()
            grand_prix = tds[1].text.strip()
            circuit = tds[2].text.strip()
            dates = tds[3].text.strip()
            schedule_data.append({
                "round": round_no,
                "grand_prix": grand_prix,
                "circuit": circuit,
                "dates": dates
            })

# 6. Save Database JSON
db_file = os.path.join(ASSETS_DIR, "f1_2026_db.json")
full_db = {
    "season": 2026,
    "teams": teams_data,
    "drivers": drivers_data,
    "schedule": schedule_data
}
with open(db_file, "w", encoding="utf-8") as f:
    json.dump(full_db, f, indent=2, ensure_ascii=False)

print(f"\n[DONE] Saved complete 2026 database to {db_file}")
print(f"Total Teams: {len(teams_data)}, Drivers: {len(drivers_data)}, Races: {len(schedule_data)}")
