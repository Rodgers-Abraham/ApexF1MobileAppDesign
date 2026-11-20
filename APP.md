# Apex F1 — App Reference for Agents

This document is the authoritative reference for a new agent working on this codebase. Read it in full before modifying any feature. It maps every user-visible feature to the files, providers, and API endpoints that power it.

---

## 1. Stack at a Glance

| Layer | Technology |
|-------|-----------|
| Mobile framework | Flutter (Dart, SDK ≥ 3.4) |
| State management | Riverpod 2.x (`StateNotifier`, `FutureProvider`, `StateNotifierProvider`) |
| Routing | GoRouter 14 with `ShellRoute` |
| HTTP client | Dio 5 (`api_client.dart` injects Firebase ID token) |
| Auth | Firebase Auth (email/password) + Firestore user profiles |
| Push notifications | Firebase Messaging (FCM) |
| Backend | FastAPI (Python) on Render — `https://f1-backend-41t9.onrender.com` |
| Database | Neon Postgres |
| Design system | Custom — `DS.*` tokens in `lib/shared/theme/app_design_system.dart` |
| Fonts | `Formula1`, `Formula1Wide` (custom), plus Google Fonts |

---

## 2. Project Structure

```
frontend/
  lib/
    main.dart                          Entry point: Firebase init → ProviderScope → F1ApexApp
    firebase_options.dart              Auto-generated Firebase config
    core/
      providers/
        auth_provider.dart             AuthState + AuthNotifier (StateNotifier)
        session_provider.dart          latestSessionProvider, sessionNotifierProvider,
                                       raceDetailsProvider, latestPredictionProvider
        telemetry/
          providers.dart               All polling providers (see §8)
          models.dart                  LiveTelemetry, RaceFlagStatus, SessionLiveStatus,
                                       RaceControlEvent, RaceReplayState, etc.
      utils/
        router.dart                    GoRouter — redirect logic, all route definitions
        api_config.dart                Base URL from .env
      api/
        api_client.dart                Dio instance with Bearer token interceptor
      services/
        notification_permission_service.dart  FCM permission + token lifecycle
    features/
      auth/presentation/screens/
        onboarding_screen.dart         Register (4 steps) + Login screen
      home/presentation/
        screens/pitwall_screen.dart    Home screen (Pit Wall)
        widgets/gp_hero_widget.dart    Live/countdown hero banner
        widgets/season_calendar_widget.dart  2026 season calendar strip
      live/presentation/
        screens/live_tracker_screen.dart     Live timing + replay controller
        screens/practice_replay_screen.dart  FP replay
        screens/qualifying_replay_screen.dart Q replay (Q1/Q2/Q3 segments)
        widgets/replay_timing_tower_widget.dart  Driver tower widget
        widgets/session_flag_banner.dart     Flag status banner
        widgets/radio_card.dart              Team radio playback card
      sessions/
        data/sessions_provider.dart    allSessionsProvider, timingLiveStatusProvider,
                                       sessionDataProvider
        presentation/screens/
          sessions_list_screen.dart    All past sessions grouped by year/event
          practice_results_screen.dart FP1/FP2/FP3 final standings
          qualifying_results_screen.dart Q results with Q1/Q2/Q3 tabs
          race_results_screen.dart     Race results with fastest lap + DNF
      standings/                       Driver + constructor championship tables
      predictor/                       Podium prediction + scoring
      history/                         Historical seasons browser
      chat/                            Apex AI (Gemini-powered F1 assistant)
      settings/presentation/screens/
        settings_screen.dart           Profile edit, password, logout, delete account
    shared/
      widgets/dashboard_shell.dart     Bottom nav + MORE drawer shell
      theme/
        theme_provider.dart            F1Team enum, per-team color themes
        app_design_system.dart         DS.* design tokens, DSWidgets helpers
  test/                                Unit/widget tests (flutter_test)
  integration_test/                    On-device integration tests (integration_test SDK)
  patrol.yaml                          App bundle config (com.antigravity.f1)
backend/
  main.py                              FastAPI app, router mounts
  api/routes/
    sessions.py                        /api/sessions/* — latest session, predictions, simulate
    telemetry.py                       /api/f1/* — live data, standings, session-status, flags
    recap_sessions.py                  /api/timing/* — session list, data, SSE replay stream
  services/
    f1_api_client.py                   Sportradar + OpenF1 + Jolpica data fetching
    f1_poller.py                       Session state machine, live session management
```

---

## 3. Authentication

### Flow

**Registration (new user):**
1. `OnboardingScreen` starts in registration mode (4 steps):
   - **Details** — name, email, password, country
   - **Team** — pick favourite constructor
   - **Drivers** — pick favourite + rival driver
   - **Celebration** — success screen
2. Each step validation happens client-side before advancing.
3. Final step calls `AuthNotifier.register(...)` → `FirebaseAuth.createUserWithEmailAndPassword` → writes Firestore doc → calls `_persistAndSetState`.

**Login (returning user):**
1. Tap **SIGN IN** chip in header → `_isLoginMode = true`.
2. Enter email + password → tap **AUTHENTICATE ▶**.
3. `_handleDetailsNext` calls `AuthNotifier.login(email, password)`.
4. `login()` → `FirebaseAuth.signInWithEmailAndPassword` → fetches Firestore user doc → calls `_persistAndSetState`.
5. On success: `context.go('/')`.
6. On failure: `state.errorMessage` is set; red error banner appears below the password field.

**Auto-login (cold start):**
- `AuthNotifier` constructor calls `_tryAutoLogin()` (async, non-blocking).
- Checks `FirebaseAuth.instance.currentUser` first (Firebase persists tokens locally).
- Falls back to `SharedPreferences` key `auth_user` (JSON-encoded profile cache).
- A `try-finally` block guarantees `AuthState.isInitialized = true` when done, regardless of path.

### Key files

| File | Role |
|------|------|
| `lib/core/providers/auth_provider.dart` | `AuthState`, `AuthNotifier`, `authProvider` |
| `lib/features/auth/presentation/screens/onboarding_screen.dart` | UI for register + login |
| `lib/core/utils/router.dart` | Routing guard |

### AuthState fields

```dart
String? token          // Firebase UID — null = unauthenticated
String? email
String? name
String? favouriteTeam  // drives theme
String? favouriteDriver
String? country
String? rivalDriver
bool isLoading
String? errorMessage
bool isInitialized     // false until _tryAutoLogin completes
```

`isAuthenticated` getter: `token != null`.

### Router guard

`lib/core/utils/router.dart` runs on every navigation:
```dart
final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
final hasFirebaseUser = FirebaseAuth.instance.currentUser != null; // race-condition fix
final effectivelyCompleted = onboardingCompleted || hasFirebaseUser;
if (!effectivelyCompleted) return '/onboarding';
if (effectivelyCompleted && isOnboardingRoute) return '/';
```

> **Important:** Always check BOTH SP flag AND `FirebaseAuth.instance.currentUser`. Checking only SP causes a race condition where a returning user gets bounced to onboarding on cold start.

### Error message mapping (`_extractErrorMessage`)

| Firebase code | User message |
|---------------|-------------|
| `wrong-password` / `invalid-credential` | "Incorrect email or password." |
| `user-not-found` | "No account found with this email." |
| `email-already-in-use` | "Email is already registered." |
| `weak-password` | "Password must be at least 6 characters." |
| `too-many-requests` | "Too many attempts. Please try again later." |
| `network-request-failed` | "Network error. Check your internet connection." |

---

## 4. Navigation

### Shell structure

`DashboardShell` (`lib/shared/widgets/dashboard_shell.dart`) wraps every route inside the `ShellRoute`. It provides:

**Bottom navigation bar (5 items):**

| Label | Route | Screen |
|-------|-------|--------|
| PITWALL | `/` | `PitWallScreen` |
| TIMING | `/live` | `LiveTrackerScreen` |
| STANDINGS | `/standings` | `StandingsScreen` |
| PREDICT | `/predictor` | `PredictorScreen` |
| MORE | (opens drawer) | — |

**MORE drawer (4 items):**

| Label | Route | Screen |
|-------|-------|--------|
| REPLAY | `/sessions` | `SessionsListScreen` |
| APEX AI | `/chat` | `ChatScreen` |
| F1 ARCHIVE | `/history` | `HistoryScreen` |
| PIT LANE | `/settings` | `SettingsScreen` |

Additional routes (not in nav, navigated to programmatically):

| Path | Screen |
|------|--------|
| `/onboarding` | `OnboardingScreen` |
| `/results/practice/:id` | `PracticeResultsScreen` |
| `/results/qualifying/:id` | `QualifyingResultsScreen` |
| `/results/race/:id` | `RaceResultsScreen` |
| `/replay/practice/:id` | `PracticeReplayScreen` |
| `/replay/qualifying/:id` | `QualifyingReplayScreen` |

---

## 5. Home — Pit Wall (`/`)

**File:** `lib/features/home/presentation/screens/pitwall_screen.dart`

### GPHeroWidget

`lib/features/home/presentation/widgets/gp_hero_widget.dart`

- Reads `sessionLiveStatusProvider` (polls `/api/f1/session-status` every 30 s).
- **When live** (`isLive == true`): shows pulsing green **"LIVE ON TRACK · {sessionName}"** banner. Tapping navigates to `/live`.
- **When not live**: shows race countdown to next session (`nextSessionDate`, `secondsUntilNext`).

> Note: `get_session_status()` on the backend only distinguishes race-weekend ON/OFF. It does NOT distinguish P1 vs P2 vs Race within a weekend. `sessionName` may be empty during a weekend gap (e.g., between FP2 and FP3).

### SeasonCalendarWidget

`lib/features/home/presentation/widgets/season_calendar_widget.dart`

Full 2026 season calendar. Data sourced from `assets/f1_2026_db.json`.

---

## 6. Live Tracker & Replay (`/live`)

**File:** `lib/features/live/presentation/screens/live_tracker_screen.dart`

This screen handles both **live sessions** and **post-session replay**.

### Live mode

Activated when `sessionLiveStatusProvider.value?.isLive == true`.

Polling providers active during live mode:

| Provider | File | Poll interval | Endpoint |
|----------|------|--------------|----------|
| `liveTelemetryFeedProvider` | `telemetry/providers.dart` | 2 s (10 s on error) | `/api/f1/telemetry/live` |
| `raceFlagStatusProvider` | `telemetry/providers.dart` | 3 s | `/api/f1/race-control/status` |
| `teamRadioFeedProvider` | `telemetry/providers.dart` | 10 s | `/api/f1/team-radio` |
| `raceEventsFeedProvider` | `telemetry/providers.dart` | 8 s | `/api/f1/race-events` |
| `sessionLiveStatusProvider` | `telemetry/providers.dart` | 30 s (45 s on error) | `/api/f1/session-status` |

UI components shown live:
- `ReplayTimingTowerWidget` — driver positions, gap, tyre, fastest lap badges
- `FigmaSessionFlagBanner` — GREEN / YELLOW / SC / VSC / RED flag status
- Track map with driver positions (from `liveTelemetryFeedProvider`)
- Team radio cards

### Replay mode

Activated when `isLive == false`.

- User selects a session from the REPLAY list.
- `raceReplayProvider` (`StateNotifierProvider<RaceReplayNotifier>`) fetches `/api/timing/sessions/{id}/data` once.
- Local playback: notifier steps through laps client-side via a timer.

**Key `RaceReplayState` fields:**

```dart
int currentLap
int totalLaps
int? truncatedAt        // set when actual data < totalLaps
bool isPlaying
bool isAtEnd            // currentLap >= (truncatedAt ?? totalLaps)
List allLaps
bool showingGrid
RaceSummary? raceSummary
```

- `isAtEnd == true` → auto-pops podium card + summary sheet (fires once via `_hasSummaryBeenShown` guard).
- `truncatedAt != null` → shows banner: *"TIMING DATA ENDS AT LAP {n} · {total} LAPS SCHEDULED"*.
- Practice/qualifying progress bar is **hardcoded to 70%** (no lap count for non-race sessions).

### Dedicated replay screens

- `PracticeReplayScreen` — `/replay/practice/:id`
- `QualifyingReplayScreen` — `/replay/qualifying/:id` — tabs for Q1/Q2/Q3 segments

---

## 7. Sessions List — REPLAY (`/sessions`)

**File:** `lib/features/sessions/data/sessions_provider.dart`  
**Screen:** `lib/features/sessions/presentation/screens/sessions_list_screen.dart`

### Data flow

```
allSessionsProvider
  → GET /api/timing/sessions
  → returns { events: [...], live: { is_live, session_type, meeting_name } }
  → parsed into List<EventSessions>
```

Each `EventSessions` has:
- `year`, `event`, `eventName`, `country`
- `sessions: List<SessionEntry>` — each with `id`, `sessionType` (raw API codes)

### Session type label mapping

| API code | Chip label |
|----------|-----------|
| `P1` | FP1 |
| `P2` | FP2 |
| `P3` | FP3 |
| `Q` | QUALI |
| `SQ` | SQ |
| `Sprint` | SPRINT |
| `Race` | RACE |

### Navigation from chips

| Session type | Route |
|-------------|-------|
| P1, P2, P3 | `/results/practice/:id` |
| Q, SQ | `/results/qualifying/:id` |
| Race, Sprint | `/results/race/:id` |

Backend has 193 events from 2010–2026 (as of Las Vegas GP 2026).

---

## 8. Session Results Screens

All three results screens use `sessionDataProvider`:
```dart
sessionDataProvider(sessionId)
  → GET /api/timing/sessions/{id}/data
  → returns Map<String, dynamic> with laps, events, weather, results
```

### PracticeResultsScreen (`/results/practice/:id`)
- Shows final order: position, driver name, team, best lap time (formatted from float seconds), gap from P1, laps completed.

### QualifyingResultsScreen (`/results/qualifying/:id`)
- Tabs: Q1 / Q2 / Q3.
- Drivers eliminated from each segment tagged **"OUT"** in red.
- Pole position chip shown.

### RaceResultsScreen (`/results/race/:id`)
- Full race results with positions, time/gap, fastest lap marker, DNF/retired status.

---

## 9. Standings (`/standings`)

**Screen:** `lib/features/standings/presentation/screens/standings_screen.dart`

| Provider | Endpoint |
|----------|---------|
| `liveDriverStandingsProvider` | `GET /api/f1/live-standings/drivers` |
| `liveConstructorStandingsProvider` | `GET /api/f1/live-standings/constructors` |

Both are `FutureProvider.autoDispose` — no polling. Displays championship points tables with team branding.

---

## 10. Predictor (`/predictor`)

**Screen:** `lib/features/predictor/presentation/screens/predictor_screen.dart`

| Provider | Endpoint |
|----------|---------|
| `latestPredictionProvider` | `GET /api/sessions/predictions?session_key={key}` |
| `latestSessionProvider` | `GET /api/sessions/latest` |

Shows AI-generated win probabilities per driver for the latest session.

---

## 11. AI Chat — Apex AI (`/chat`)

**Screen:** `lib/features/chat/presentation/screens/chat_screen.dart`

Gemini-powered F1 assistant. All AI calls go through the backend (no direct Gemini SDK in the app). Backend endpoint: proxied via `/api/chat/*` or similar.

---

## 12. Settings (`/settings`)

**Screen:** `lib/features/settings/presentation/screens/settings_screen.dart`

Actions available:
- Edit display name, country, favourite driver, rival driver
- Change password (via `FirebaseAuth.updatePassword`)
- Change favourite team (triggers `AuthNotifier.updateFavouriteTeam` → updates Firestore + SP + theme)
- **Logout** → `AuthNotifier.logout()` → signs out Firebase, removes `auth_user` and `onboarding_completed` from SP, `state = AuthState(isInitialized: true)`, then UI navigates to `/onboarding`
- **Delete account** → requires recent login; calls `FirebaseAuth.delete()` + Firestore delete + backend `/api/auth/delete`

---

## 13. Backend API Reference

Base URL: `https://f1-backend-41t9.onrender.com`

### Live data (`/api/f1/*`)

| Method | Endpoint | Returns | Auth required |
|--------|---------|---------|--------------|
| GET | `/api/f1/session-status` | `SessionLiveStatus` (is_live, session_name, meeting_name, next_session_*, seconds_until_next) | No |
| GET | `/api/f1/telemetry/live` | `List<LiveTelemetry>` (pos, name, team, gap, status, tyre, lastLap, speed, x, y) | Yes |
| GET | `/api/f1/race-control/status` | `RaceFlagStatus` (flag, safetyCarActive, vscActive, redFlagActive) | No |
| GET | `/api/f1/race-events` | `List<RaceControlEvent>` | No |
| GET | `/api/f1/team-radio` | `List<TeamRadioItem>` | No |
| GET | `/api/f1/live-standings/drivers` | Championship driver standings | No |
| GET | `/api/f1/live-standings/constructors` | Constructor standings | No |
| GET | `/api/f1/news/live` | `List<NewsArticle>` | No |
| GET | `/api/f1/telemetry/track-conditions` | Track/air temp, rainfall | No |
| GET | `/api/f1/telemetry/tire-strategy` | Tyre compound strategy per driver | No |
| GET | `/api/f1/calendar` | Full 2026 season calendar | No |

### Timing / replay (`/api/timing/*`)

| Method | Endpoint | Returns | Auth required |
|--------|---------|---------|--------------|
| GET | `/api/timing/sessions` | `{ events: [...], live: { is_live, session_type, meeting_name } }` | No |
| GET | `/api/timing/sessions/live` | Current live session block | No |
| GET | `/api/timing/sessions/{id}/meta` | Session metadata (drivers, circuit) | No |
| GET | `/api/timing/sessions/{id}/data` | Full timing payload (laps, events, weather, results) | No |
| GET | `/api/timing/sessions/{id}/replay` | SSE stream — lap-by-lap events | No |

### Session management (`/api/sessions/*`)

| Method | Endpoint | Returns |
|--------|---------|---------|
| GET | `/api/sessions/latest` | `LatestSession` (session_key, meeting_name, session_type, **status**, results) |
| GET | `/api/sessions/predictions` | `SessionPredictions` (driver win probabilities) |
| POST | `/api/sessions/simulate` | Advances simulated session state machine |

### Auth (`/api/auth/*`)

| Method | Endpoint | Purpose |
|--------|---------|---------|
| PUT | `/api/auth/fcm-token` | Register FCM push token |
| DELETE | `/api/auth/fcm-token` | Remove FCM token on logout |
| DELETE | `/api/auth/delete` | Backend cleanup on account deletion |

All authenticated endpoints require `Authorization: Bearer {firebaseIdToken}` header. `api_client.dart` injects this automatically via a Dio interceptor.

---

## 14. Polling Providers

All live polling is in `lib/core/providers/telemetry/providers.dart`. Each is a `StateNotifierProvider` with an internal `Timer`.

| Provider | Interval | Endpoint | Model |
|----------|---------|---------|-------|
| `liveTelemetryFeedProvider` | 2 s (10 s on error) | `/api/f1/telemetry/live` | `List<LiveTelemetry>` |
| `raceFlagStatusProvider` | 3 s | `/api/f1/race-control/status` | `RaceFlagStatus` |
| `teamRadioFeedProvider` | 10 s | `/api/f1/team-radio` | `List<TeamRadioItem>` |
| `raceEventsFeedProvider` | 8 s | `/api/f1/race-events` | `List<RaceControlEvent>` |
| `liveNewsFeedProvider` | 5 min | `/api/f1/news/live` | `List<NewsArticle>` |
| `sessionLiveStatusProvider` | 30 s (45 s on error) | `/api/f1/session-status` | `SessionLiveStatus` |

> **Testing warning:** These timers prevent `tester.pumpAndSettle()` from ever settling. In integration tests, use `tester.pump(Duration(seconds: N))` instead.

`backendReachableProvider` (`Provider.autoDispose<bool>`) is derived from `sessionLiveStatusProvider` — `true` when the last poll succeeded.

---

## 15. Theme System

**Files:** `lib/shared/theme/theme_provider.dart`, `lib/shared/theme/app_design_system.dart`

The app applies a per-team color theme based on the user's `favouriteTeam`.

```dart
enum F1Team {
  ferrari, mercedes, redbull, mclaren, astonmartin,
  alpine, williams, haas, visacashapprb, kicksauber, // etc.
}
```

`themeProvider` holds the current `F1Team` and exposes `getThemeData()` which returns a `ThemeData` with the team's primary color as the accent.

### Design System tokens (`DS.*`)

All colors, radii, and typography use `DS.*` constants:

| Token | Purpose |
|-------|---------|
| `DS.bg` | Main scaffold background (`#09090B`) |
| `DS.surface0` / `DS.surface1` / `DS.surface2` | Card elevation levels |
| `DS.red` | Apex brand red |
| `DS.teal` | Secondary accent |
| `DS.textPrimary` / `DS.textMuted` | Text hierarchy |
| `DS.outline` | Border color |
| `DS.aeroCorner` | Asymmetric `BorderRadius(topLeft: 3, topRight: 12, ...)` |
| `DS.aeroCornerSm` | Smaller variant |

Typography helpers: `DS.headline()`, `DS.body()`, `DS.labelCaps()`, `DS.telemetry()`, `DS.driverCode()`.

Widget helpers in `DSWidgets`: `DSWidgets.inputField(...)`, `DSWidgets.statusChip(...)`, `DSWidgets.redBadge(...)`.

---

## 16. Testing

### Unit/widget tests (no device)

```bash
cd frontend
flutter test test/
```

Key files:
| File | What it tests |
|------|--------------|
| `test/auth_notifier_test.dart` | `AuthState` model, `copyWith`, `isInitialized`, error message strings |
| `test/widget_test.dart` | App boots to `OnboardingScreen` when unauthenticated |
| `test/notification_permission_test.dart` | `NotifPermissionStatus` state machine |
| `test/race_replay_widget_test.dart` | `ReplayTimingTowerWidget` — penalties, DNF, `isAtEnd` |
| `test/swap_queue_test.dart` | `ReplaySwapQueue` animation sequencing |

### Integration tests (requires emulator)

```bash
cd frontend
flutter test integration_test/login_test.dart -d emulator-5554
flutter test integration_test/sessions_test.dart -d emulator-5554
# or both:
flutter test integration_test/ -d emulator-5554
```

Emulator: `F1_Harness_API_36` (Android API 36). Launch with:
```bash
flutter emulators --launch F1_Harness_API_36
```

Key files:
| File | What it tests |
|------|--------------|
| `integration_test/login_test.dart` | Onboarding screen, login mode toggle, empty-field guard, wrong-credentials error, returning-user race condition |
| `integration_test/sessions_test.dart` | Home screen live banner absent, FP2 chip in sessions list, PracticeResultsScreen navigation, no LIVE SESSION label in live tracker |

> T5 (wrong-credentials test) makes a real Firebase network call with a 10 s timeout — may flake on slow networks.

---

## 17. Known Constraints & Gotchas

1. **Router race condition (FIXED):** The router now checks `FirebaseAuth.instance.currentUser` as a fallback. If you ever change the router redirect logic, keep this check — removing it will break returning users on cold start.

2. **Backend session granularity:** `GET /api/f1/session-status` only knows whether a race _weekend_ is active, not which individual session (P1/P2/P3/Q/Race) within it. `sessionName` can be empty during gaps between sessions in the same weekend.

3. **Polling timers in tests:** Every polling provider has a live `Timer`. Do not use `pumpAndSettle()` in integration tests — it will time out waiting for the timer. Use `pump(Duration(seconds: N))`.

4. **SharedPreferences keys:**
   - `onboarding_completed` (bool) — routing gate; cleared on logout
   - `auth_user` (String, JSON) — user profile cache for fast/offline auto-login

5. **`AuthState.copyWith` and `errorMessage`:** `errorMessage` is NOT preserved by `copyWith` unless explicitly passed. This is intentional — every new operation clears the previous error. If you add a new operation that should preserve error state, pass the existing `errorMessage` explicitly.

6. **`isInitialized` flag:** Always `false` on a fresh `AuthState()`. Set to `true` by the `try-finally` in `_tryAutoLogin`, and explicitly set to `true` in `_persistAndSetState` and `logout`. Do not create `AuthState()` defaults in new code paths without setting `isInitialized: true` where appropriate.

7. **dev_dependencies only:** `firebase_auth_mocks`, `fake_cloud_firestore`, `patrol` are dev-only — they do not affect the release APK.

8. **Backend URL:** Configured in `frontend/.env` as `API_URL`. On Android emulator, the host machine is reachable at `10.0.2.2`, but the production Render URL is used in `.env` and works from the emulator over the internet.
