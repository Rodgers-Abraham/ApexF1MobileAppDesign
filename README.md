# Apex F1

A Formula 1 companion app for the 2026 season — live telemetry, standings, race predictions, AI chat, and historical archive, all wrapped in a team-themed dark UI inspired by F1 TV broadcasts.

Built with **Flutter** (frontend) and **FastAPI** (backend).

## Features

- **Pit Wall** — GP countdown hero, race control flags, leader pulse, paddock news, and the full season calendar
- **Live Tracker** — Real-time timing tower, interactive track map, team radio playback, and tyre strategy view
- **Standings** — Driver and constructor championship tables with podium cards and team branding
- **Predictor** — Pick your podium, pole sitter, fastest lap, and safety cars; earn points for correct calls
- **AI Chat** — Gemini-powered F1 assistant for stats, strategy, and trivia
- **History** — Browse and search past seasons and race results
- **Team Theming** — Pick your favourite constructor and the entire UI shifts to their accent colours

## Architecture

```
frontend/               Flutter mobile app (Android, iOS, Web)
├── lib/
│   ├── core/           Providers, API client, routing, utilities
│   ├── features/       Feature modules (home, live, standings, predictor, chat, history, settings)
│   └── shared/         Theme system, constants, shared widgets
└── assets/             Circuits, drivers, helmets, teams, fonts, animations

backend/                FastAPI Python server
├── api/routes/         Auth, telemetry, sessions, chatbot, predictor, history, calendar
├── core/               Config, database, auth middleware
└── services/           F1 API client, Gemini integration
```

### Frontend Stack

| Layer | Tech |
|-------|------|
| Framework | Flutter (SDK >=3.4) |
| State | Riverpod (StateNotifier + FutureProvider) |
| Routing | GoRouter with ShellRoute |
| HTTP | Dio with Bearer token interceptor |
| Auth | Firebase Auth |
| Fonts | Formula1, Formula1Wide, Google Fonts (Orbitron, Outfit) |

### Backend Stack

| Layer | Tech |
|-------|------|
| Framework | FastAPI + Uvicorn |
| Database | Neon Postgres |
| Auth | JWT (HS256) |
| AI | Google Gemini via backend proxy |
| Data | Jolpica (Ergast) F1 API + OpenF1 telemetry |
| Hosting | Render (free tier) |

## Getting Started

### Prerequisites

- Flutter SDK >=3.4
- Python 3.11+
- A [Neon](https://neon.tech) Postgres database
- Firebase project (for auth)

### Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# Create .env
cat <<EOF > .env
DATABASE_URL=postgresql://...
JWT_SECRET=your-secret
GEMINI_API_KEY=your-key
ALLOWED_ORIGINS=*
EOF

uvicorn main:app --reload
```

The API runs at `http://localhost:8000`. Docs at `/docs`.

### Frontend

```bash
cd frontend
flutter pub get

# Create .env
echo "API_BASE_URL=http://localhost:8000" > .env

flutter run
```

For Android emulator connecting to local backend, the app auto-maps `localhost` to your LAN IP.

### Deployment

The backend deploys to Render via `render.yaml`. Set `DATABASE_URL`, `JWT_SECRET`, `GEMINI_API_KEY`, and `ALLOWED_ORIGINS` in Render environment variables.

For mobile releases, build with:

```bash
flutter build apk --release
flutter build ios --release
```

## Design

- **Dark-only** — Scaffold `#09090B`, cards `#141418`
- **Team accent system** — 11 F1 constructors, each with a primary colour that themes the entire app
- **Asymmetric border radius** — `topLeft: 3, topRight: 12` as a signature design motif
- **F1 broadcast aesthetic** — Timing tower layout, telemetry strips, flag banners

## License

All rights reserved.
