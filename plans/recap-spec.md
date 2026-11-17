# Recap spec: Live Timing + Race Recap (Workstream A)

Place this file at `plans/recap-spec.md`. It is the target behaviour for the Live Timing / Race Recap feature. Much of it already exists in the codebase (see section 2), so the job is to compare, reuse what works, fix what is broken, and build what is missing. Before changing anything, list the differences between this spec and the current implementation and wait for approval.

## 1. What the feature does

When no session is live, users pick a past session of an event (Practice 1/2/3, Qualifying, Sprint Qualifying, Sprint, Race) and replay it like a TV timing screen. During a real session, the same screens show live timing. Replay and live use the same data shape per screen type so each screen has one rendering path.

## 2. Current state (from the Step 0 report; verify)

- Backend: `backend/api/routes/recap_sessions.py` serves `GET /api/timing/sessions`, `/sessions/{id}/meta`, `/sessions/{id}/data` and an unused SSE `/sessions/{id}/replay`. No auth required.
- Ingest: `backend/ingest/` (runner, parser, event_engine, upsert) writes to the `sessions` table in Neon. `.github/workflows/ingest.yml` runs it on a schedule.
- Flutter: `features/sessions/` has the provider, `sessions_list_screen.dart`, `practice_replay_screen.dart`, `qualifying_replay_screen.dart`. Race replay is wired through `selectedReplaySessionProvider` into `live_tracker_screen.dart`.
- Known gaps: (1) practice and qualifying screens have no routes in `router.dart`; (2) `_openSession()` sends every session type to `/live`, so practice and qualifying chips open the race tracker; (3) the SSE replay endpoint is unused because replay is client-side.

## 3. Required fixes first

1. Add routes for the practice and qualifying replay screens, and make `_openSession()` open the right screen by session type (practice, qualifying/sprint qualifying, race/sprint).
2. Decide whether the SSE replay endpoint stays. Replay is client-driven (section 7), so do not build on it. Do not delete it without asking me.
3. Compare each screen against sections 5 and 6 and list what is missing or different.

## 4. Data sources (backend only; the app never calls them directly)

1. TracingInsights GitHub data (https://github.com/TracingInsights/2026 and per-season repos): source for past sessions. Per session folder: drivers.json, rcm.json (race control messages), corners.json, session_laptimes.json, weather.json, per-driver lap files. Appears about 30 minutes after a session. Not live.
2. Sportradar F1 API v2: LIVE only. The app has a trial key (about 1,000 requests per 30 days, 1 request per second, historical/replay data only). True live data needs production access. Reuse the existing client. Put live behind a feature flag with a mock mode that replays recorded data. Do not store Sportradar data in Neon unless I confirm their terms allow it.
3. Jolpica F1 API: schedule (which weekends are race weekends), results, final classification, finishing status, and lap-by-lap positions/times if TracingInsights lacks them.
4. FastF1: fallback for anything else. Unofficial.
5. Team radio: not in the TracingInsights files. The Live Tracker already plays team radio; find out how and reuse it. Store metadata and links only, never audio.

Data check (report before building): read DATA_REFERENCE.md and sample files and confirm the real schema. For every session type confirm: (a) per-lap position for each driver, or whether it must be computed from cumulative lap times; (b) lap times, sector times, pit in/out; (c) timestamps for when each lap was set, i.e. whether a session clock can be reconstructed (needed for practice and qualifying replay); (d) tyre compound; (e) rcm.json messages for flags, SC/VSC, penalties, deleted laps, retirements; (f) how DNS appears; (g) how qualifying segments (Q1/Q2/Q3, SQ1/SQ2/SQ3) are marked. Do not assume field names. Report gaps and the fallback source for each.

## 5. Screens (TV timing graphics style)

Use the existing design system (dark scaffold, team accent colours, asymmetric border radius, existing fonts). Purple = fastest in the current scope (session, qualifying segment, or race lap); green = personal best.

### Practice screen (P1, P2, P3)
- Header: session name, SESSION CLOCK counting down (e.g. 60:00 to 0:00), track-status pill (GREEN / YELLOW / RED), weather summary.
- Timing table ordered by BEST LAP: position, team-colour bar, 3-letter code, best lap, gap to leader, laps completed, tyre compound if data exists, last lap time.
- Replay is driven by the session clock, not lap number. When a driver sets a faster lap, their row slides to its new position (green flash for the improver, red for the driver pushed down). The overall fastest lap shows purple. Drivers with no time sit at the bottom as "NO TIME".
- No overtake events and no race lap counter. Flags and red flags show as a banner and in the ticker; deleted laps show if the data has them.
- Replay speed: default about 10x (a 60-minute session in roughly 6 minutes); options 1x, 5x, 10x, 30x; pause and a scrubber over the session clock.

### Qualifying screen (Q and Sprint Qualifying)
- Segment tabs Q1 | Q2 | Q3 (SQ1 | SQ2 | SQ3 for sprint qualifying) with the current segment's countdown clock. The clock stops during red flags.
- Timing table ordered by BEST LAP in the current segment: position, team-colour bar, code, best lap, gap to leader, sector indicators (purple/green/yellow) and tyre compound if the data supports them.
- ELIMINATION ZONE: a red divider line and red tint on drivers currently in the drop zone. Derive the cut-off count from the session data (it differs by season and 22-car vs 20-car grids). Do NOT hardcode it.
- When a driver improves, their row slides to its new position with a green flash; those pushed into the drop zone flash red.
- At the end of Q1 and Q2, show eliminated drivers locked at the bottom with an "OUT" tag in their final order, then move to the next segment with only the survivors. After Q3, show the final grid with pole highlighted.
- Red-flag banner and ticker as in practice. Same clock-driven controls as practice, plus jumps between segments.

### Race screen (Race and Sprint): lap-boundary updates
Design decision: the app does NOT show overtakes mid-lap. Rows stay still during a lap and update at each lap boundary. All labels say "end of lap N".
- Top bar: event, session, "LAP 23/57", track-status pill (GREEN / YELLOW / SC / VSC / RED).
- Timing tower: ALL drivers from P1 to the last position (22 cars in 2026, 20 in earlier seasons; derive from the data). Row: position, team-colour bar, code, last lap time, badge area. Rows keyed by driver so they animate.
- At each lap boundary, in order: (1) lap counter ticks, (2) every driver's lap time updates, the driver with the fastest lap of THAT lap in purple and the rest in white, (3) position changes animate one after another in a queue. Never drop a change; compress animation time when there are many.
- Swap styling: overtake = slide (~500 ms), passer flashes green with an up arrow, passed driver red with a down arrow. Pit gain = slide with a blue/neutral flash and a "gained via pit stop" tag. Retirement gain = slide with a "+1 (retirement)" tag. Tags fade after the next lap.
- Event ticker: events of the lap just completed, e.g. "End of L23: ANT passes VER", "VER: 5 s penalty", "SAFETY CAR deployed". Tap opens the per-lap event list.
- Penalty icon on the driver row from the lap it was issued.
- Track-status banner: SC (yellow), VSC (yellow, "VSC"), RED FLAG (red), full width while active; a yellow flag icon in the status pill while a yellow is active.
- DNF: "DNF" badge beside the driver; the row dims and moves to the bottom. DNS: "DNS" from lap 0 at the bottom.
- Controls: play/pause, scrubber with markers at SC/VSC/red-flag laps and DNFs, previous/next lap. Default pace "Race Recap" = 3 seconds per lap; options 1x (3 s/lap), 2x, 4x, plus "Real time" using actual lap durations.

### Live mode (all three screens)
Same screens with no scrubber, a "LIVE" pill, and a "Reconnecting..." state with auto-reconnect and backoff. The live session type decides which screen opens. Do not break the existing Live Tracker behaviour (timing tower, track map, team radio, tyre strategy).

All screens: loading, empty and error states; respect reduced-motion settings; 60 fps on a mid-range Android phone.

## 6. Event engine (backend, race sessions)

For each lap boundary, diff the order after lap N against lap N-1 (for lap 1, the grid vs the end of lap 1). Classify each position change:
- OVERTAKE: A moved ahead of B on track.
- PIT GAIN: moved up because a rival pitted or was in the pit lane that lap; labelled "gained via pit stop"; never shown as a pass.
- RETIREMENT GAIN: moved up because a driver ahead retired; labelled "+1 (retirement)".
- Priority when several causes fit: retirement, then pit, then overtake. Document the rule.
- Net changes only: a pass and re-pass within one lap shows nothing. Document this in the README.

Also per lap: PENALTY, SAFETY CAR, VSC, RED FLAG, YELLOW FLAG, DNF (driver, lap), DNS. Every event: {type, lap, drivers[], detail, label}. For practice and qualifying, produce time-stamped best-lap improvements, segment boundaries, eliminations and flag/red-flag periods instead. Tests: a known race and a known qualifying session, compared against official results. Review the existing `event_engine.py` against these rules before changing it.

## 7. Replay delivery (Render free tier sleeps)

- Replay is CLIENT-DRIVEN. The API returns the whole session payload in one request (roughly 100 to 300 KB) and the Flutter app plays it locally: pause, speed, seek and scrubbing all happen on the device. This avoids WebSocket cold-start and dropped-connection problems on Render's free tier.
- Use WebSocket/SSE only for LIVE mode, from one backend poller fanned out to all clients.
- Handle Render cold starts in the app: a clear "waking the server" loading state and retry with backoff.

## 8. Database (Neon), only for this feature

Reuse the existing `sessions` table if it fits. Lap-level and time-stamped data only; NO raw telemetry.
- One row per session: id, year, event, session_type (P1, P2, P3, Q, SQ, Sprint, Race), session_date; status 'pending' | 'ready' | 'failed'; error, source, source_hash, ingested_at; JSONB columns: meta (session info, drivers, teams, colours, corners, qualifying segment info), laps (race: grid order, per-lap order, lap times, pit stops, fastest lap per lap; practice/qualifying: the time-stamped timing data), events, weather, results, radio (optional, metadata/links only).
- UNIQUE (year, event, session_type). The API serves only status 'ready'. Validate with Pydantic before writing. Neon data must always be re-creatable from the sources. Report real storage sizes after the first backfill.

## 9. Ingest job

New sessions must appear in Neon automatically after each session. Review the existing `backend/ingest/` and `ingest.yml` against these rules and fix differences:
1. DETECT with the GitHub REST API (authenticated token): list session folders and latest commit times, compare with the sessions table, queue missing sessions and sessions whose content hash changed. No cloning.
2. STABILITY RULE: ingest only when all required files exist and the folder has had no new commits for about 10 minutes.
3. FETCH, VALIDATE against the real schema, PROCESS (build the payload, run the event engine).
4. CROSS-CHECK final order/DNF/DNS (race) and final classification (qualifying) against Jolpica results. On disagreement, mark the session 'failed' with a clear error instead of serving wrong data.
5. UPSERT on (year, event, session_type); safe to run twice. If a re-ingest fails, keep the previous 'ready' data.
6. Retries with exponential backoff, timeouts, per-session outcome logging.
7. BACKFILL for all seasons, and re-ingest of one session by name.
8. Schedule: every 15 minutes Friday to Monday, daily otherwise (as in the existing workflow). Actions cron can be delayed; note this in the README.

## 10. API

- Sessions list (with a live true/false flag), session meta, session data (full payload shaped per session type, for client-driven replay), and a live endpoint (WebSocket/SSE) that uses the same shapes via one backend poller, with Sportradar in mock mode until a production key exists.
- The recap API never calls GitHub or TracingInsights at request time.
- Auth: recap endpoints stay public (no login) as they are today. Do not add auth to them.
- README licensing note: these sources originate from F1's feeds and are unofficial; hosting copies raises licensing questions; Sportradar is the licensed route for production.

## 11. Acceptance criteria

- Tapping a Practice, Qualifying or Race chip opens the matching screen.
- A race recap plays at 3 s/lap by default, shows all drivers, updates lap times each lap with the lap's fastest in purple, animates position swaps in a queue, labels pit and retirement gains, and shows penalties, SC/VSC/red/yellow banners, DNF and DNS badges.
- Practice replays by session clock with best-lap ordering. Qualifying shows Q1/Q2/Q3 tabs, the elimination zone, "OUT" tags and the final grid.
- Pause, speed and seek work on all three screens.
- New sessions appear in Neon automatically within a reasonable time after they land in the source repo.
- Existing features (Pit Wall, Standings, Predictor, Chat, History, theming, team radio and tyre strategy in the Live Tracker) still work.
- Each screen has a stable widget key for the elements tests will use.