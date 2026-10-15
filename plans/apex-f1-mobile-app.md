# Apex F1 Mobile Application — Implementation Plan

## 1. Goal and Success Criteria

Build a polished, broadcast-grade mobile Formula 1 companion in the existing React 19 + Vite + Tailwind CSS v4 project. The result will be an interactive, data-simulated prototype optimized for the requested 390 × 844 px viewport while remaining responsive on nearby mobile widths and usable on larger preview canvases.

The implementation is complete when:

- All five bottom-navigation destinations are functional: Pitwall, Live Telemetry, Standings, Predictor, and Settings.
- The three specified core screens contain all requested information and meaningful interactive states.
- Timing Tower, Track Map, Team Radio, and Tyre Strategy modes are functional rather than decorative.
- Drivers/Constructors standings switch correctly.
- Predictor selections, settings toggles, and favorite-team personalization update the interface during the session.
- Session flag variants, timing-row variants, tyre compounds, gains/losses, DRS, pit, and retirement states are visibly distinct and accessible.
- The app has a cohesive tokenized visual system with broadcast-inspired typography, spacing, color, motion, and responsive behavior.
- Remote imagery has graceful visual fallbacks so the UI remains complete if a host blocks or removes an asset.

## 2. Repository Findings and Constraints

- `src/App.tsx` is currently an empty application shell.
- `src/index.css` only imports Tailwind CSS v4.
- There is no pre-existing component library, design-system package, asset library, or routing package.
- Dependencies are limited to React and React DOM; the implementation should avoid adding packages unless a concrete need appears.
- The Vite server is already managed by Figma Make and must not be started manually.
- The final implementation will use React state for app navigation and prototype interactions rather than adding a router for five in-app tabs.
- The existing repository instructions require default component exports, valid JSX, and careful apostrophe quoting.

## 3. Product Decisions

### Data Model

- Use deterministic mock fixtures representing a simulated 2026 season and live Melbourne race.
- Label live content as simulated where appropriate so fabricated telemetry is not presented as real-world timing.
- Keep fixtures separate from rendering components so a future API layer can replace them without restructuring screens.
- Include 22 timing drivers and 11 constructors, including Audi and Cadillac.
- Use representative familiar driver codes and team associations for visual demonstration, while treating event telemetry, standings totals, radio messages, and news as prototype content.

### Personalization

- Start with no favorite team and a neutral white/slate active-navigation treatment.
- Allow the user to choose a favorite team in Settings.
- Once chosen, use that team token for active navigation glow, selected controls, and the favorite constructor card.
- Keep semantic states independent from team color: green/yellow/orange/red/purple continue to indicate race status and timing meaning.

### Asset Strategy

- Centralize remote driver portrait, team logo, and car-render URLs in the data fixtures rather than scattering URLs through components.
- Use publicly hosted official-looking imagery where available, as requested.
- Use Unsplash motorsport/editorial photography for Pitwall news cards, with deliberate 16:9 crops, dark overlays, and descriptive alt text.
- Provide an `AssetImage` wrapper with loading treatment and deterministic fallback content:
  - driver portrait fallback: initials/driver code on a team-color disc;
  - team logo fallback: compact typographic constructor mark;
  - car render fallback: local CSS/vector side-profile silhouette.
- Build the Albert Park circuit line as a local inline SVG so the hero remains reliable.
- Build interface icons as a small local SVG icon set to avoid adding a dependency and to keep stroke treatment consistent.

## 4. File and Module Structure

Keep `App.tsx` focused on state, navigation, and view composition.

- `src/App.tsx`
  - Root application state.
  - Current navigation destination.
  - Favorite team and user settings.
  - Shared simulated session state.
  - Screen switching and persistent bottom navigation.
- `src/data/apexData.ts`
  - Team tokens and metadata.
  - Driver/timing fixtures.
  - Driver and constructor standings.
  - News items.
  - Predictor options.
  - Session flags, weather, radio, tyre-strategy, and settings metadata.
- `src/types/apex.ts`
  - Shared unions/interfaces for teams, drivers, compounds, flags, timing states, navigation, settings, and predictions.
- `src/components/ui.tsx`
  - Local design-system primitives: `Surface`, `SectionHeader`, `Badge`, `SegmentedControl`, `IconButton`, `ProgressBar`, `Toggle`, `AssetImage`, `Stat`, and `ScreenHeader`.
- `src/components/icons.tsx`
  - Consistent inline SVG icon components.
- `src/components/BottomNav.tsx`
  - Five-item floating tab bar with safe-area support and team-color personalization.
- `src/components/SessionFlag.tsx`
  - Variants for Green, Yellow, Safety Car, Virtual Safety Car, and Red.
- `src/components/TimingRow.tsx`
  - Variants for Normal, Active DRS, In Pit, and DNF/Retired.
- `src/screens/PitwallScreen.tsx`
- `src/screens/TelemetryScreen.tsx`
- `src/screens/StandingsScreen.tsx`
- `src/screens/PredictorScreen.tsx`
- `src/screens/SettingsScreen.tsx`
- `src/index.css`
  - Tailwind import first.
  - Google Fonts imports for Orbitron, JetBrains Mono, and Inter.
  - Tailwind v4 `@theme` tokens.
  - Global resets, safe-area helpers, scrollbar treatment, keyframes, and reusable non-component visual utilities.

If the implementation remains more maintainable with a small number of files, closely related primitives may be consolidated, but screen/data/component boundaries should remain recognizable.

## 5. Design System

### Color Tokens

Define semantic CSS/Tailwind tokens rather than repeating raw colors:

- Canvas: `#0B0B0E`
- Surface: `#141419`
- Surface raised: a slightly lighter slate derived for interactive elevation
- Border: `#202028`
- Text primary: `#FFFFFF`
- Text secondary: `#8F909A`
- Flag clear: `#00E676`
- Flag caution: `#FFD600`
- Flag safety car: `#FF9100`
- Flag stopped: `#FF1744`
- Timing fastest: `#B388FF`
- All eleven requested constructor accent colors.

Add low-alpha semantic background and glow variants through `color-mix()` or tokenized CSS custom properties rather than arbitrary one-off colors.

### Typography

- Display/headings: Orbitron, uppercase, 700/900, tracked for a technical broadcast character.
- Telemetry/timing/numerals: JetBrains Mono, 600/700, tabular figures.
- Body/UI: Inter, 400/500/600.
- Keep headings compact on 390 px screens and establish clear tiers for app title, section title, card title, labels, and metadata.

### Spacing and Shape

- Core spacing scale: 4, 8, 12, 16, and 24 px, exposed as design tokens.
- Use a compact broadcast density without reducing touch targets below 44 px.
- Cards use subtle borders, restrained radii, and directional accent lines rather than generic large rounded “dashboard” tiles.
- Use clipped corners and thin grid/scan-line details sparingly to evoke pitwall displays while preserving readability.

### Motion

- Live status dot: subtle pulse.
- Alert chevron: controlled warning sweep for caution states.
- Segmented control indicator and screen transitions: 160–220 ms ease-out.
- Radio waveform: animated only while playing.
- Respect `prefers-reduced-motion` by disabling pulses, sweeping warnings, waveform movement, and nonessential transitions.

## 6. Shared Application Shell

- Use a centered mobile app canvas with full-width behavior on narrow screens and a capped width on desktop preview.
- Apply pitch-dark background, top and bottom safe-area padding, and sufficient bottom content padding for the floating navigation.
- Keep bottom navigation persistent across all screens.
- Navigation items:
  - Pitwall
  - Live
  - Standings
  - Predictor
  - Settings
- Each item uses an icon and short label; the active item gets a top indicator, subtle glow, and favorite-team color when available.
- Navigation uses actual buttons with `aria-current` and accessible labels.
- Scroll each destination to the top when the selected nav item changes.

## 7. Screen Specifications

### 7.1 Pitwall

1. **Top bar**
   - Custom “APEX F1” wordmark with speed-stripe motif.
   - Live pill with pulsing status dot and `RACE LIVE`.
   - Secondary round/event tag: `R01 · MELBOURNE`.

2. **Grand Prix hero**
   - Event eyebrow and race title.
   - Countdown with four monospaced cells: days, hours, minutes, seconds.
   - Countdown runs client-side from a fixed future demo timestamp and wraps predictably for prototype use.
   - Local Albert Park line-map SVG with start/finish marker and DRS markers.
   - Circuit name, Australian flag, 58 laps, and four DRS zones.
   - Weather strip for condition, air, track, humidity, and rain probability.

3. **Session control**
   - Full-width dynamic status component.
   - Demo control cycles among Green, Yellow, VSC, SC, and Red states so all component variants can be reviewed.
   - Each state includes status, event copy, and delta/speed instruction when relevant.

4. **News**
   - Horizontal snap carousel with 16:9 photography.
   - Category badge, bold headline, reading time, and external-arrow affordance.
   - External cards are interactive; use safe links and clear external-link labeling.

5. **Compact race pulse**
   - Add a small “race pulse” strip with leader, fastest lap, and latest pit stop so the dashboard feels live without duplicating the full Timing Tower.

### 7.2 Live Telemetry

1. **Header**
   - `LAP 34 / 58`, race title, and monospaced progress percentage.
   - Live progress bar.
   - Full-width Safety Car demo banner with animated chevron and event description.

2. **Mode switcher**
   - Horizontally scrollable segmented control:
     - Timing Tower
     - Track Map
     - Team Radio
     - Tyre Strategy
   - Preserve selected mode while moving to another bottom-nav destination and back.

3. **Timing Tower**
   - Render all 22 drivers as compact, readable rows.
   - Each row includes position, gain/loss, team stripe, portrait, helmet/number micro-badge, code, constructor, gap, interval, DRS state, compound/age/pit count, and last lap.
   - On compact width, maintain hierarchy by using a two-line grid rather than horizontal overflow.
   - Fastest lap uses purple time treatment and a small `FL` marker.
   - `IN PIT` uses amber status.
   - DNF rows are muted/red-tinted and show `OUT · REASON`.
   - Tapping a normal driver selects/highlights that row and updates the mini telemetry footer with speed, gear, throttle, brake, and energy deployment.

4. **Track Map**
   - Enlarged Albert Park SVG.
   - Driver-position markers colored by team, with selected driver emphasized.
   - Track-status legend, sector markers, DRS zones, and selected-driver telemetry.

5. **Team Radio**
   - Radio cards/drawer-style panels with portrait, waveform, timestamp, play/pause control, driver/team metadata, and transcript snippet.
   - Only one clip can be “playing” at a time.
   - Playback is simulated; waveform animation and elapsed progress communicate state without requiring audio assets.

6. **Tyre Strategy**
   - Per-driver stint timeline bars using compound colors.
   - Current tyre/age, pit count, predicted pit window, and undercut/overcut risk.
   - Include compact compound legend and selected-driver strategy detail.

### 7.3 Standings

1. **Drivers/Constructors switch**
   - Sticky or near-top segmented control with counts and clear selected state.

2. **Drivers**
   - Top-three podium composition:
     - Champion centered and visually tallest.
     - Gold, silver, and bronze details conveyed with restrained metallic gradients and labels, not color alone.
     - Driver cutout, national flag, team logo/fallback, points, and wins.
   - Positions 4–22 in dense rows with position, portrait, team line, code, constructor, wins badge, and points.

3. **Constructors**
   - Eleven cards including Audi and Cadillac.
   - Team logo, constructor name, chassis/power-unit subtitle, car render/fallback, and points.
   - If a favorite is selected, that card gets a team-colored edge and glow plus a `FAVORITE` label.
   - Cards remain visually rich but use lazy-loaded imagery to avoid blocking initial content.

### 7.4 Predictor

- Header explains that picks lock at the scheduled race start.
- Prediction status card shows round, lock countdown, completion, and potential points.
- Podium predictor:
  - Three position slots with gold/silver/bronze styling.
  - Tap a slot, then choose a driver from a bottom-sheet-style inline selector.
  - Prevent the same driver from occupying more than one podium slot.
- Additional predictions:
  - Pole sitter.
  - Fastest lap.
  - Safety-car count using a stepped choice.
  - First team to pit.
  - Winning tyre strategy.
- Confidence slider/stepped selector changes the risk/reward summary.
- Submission button validates required picks, shows an inline error if incomplete, and transitions to a locked summary state when valid.
- “Edit picks” returns to the editable state in the prototype.
- Keep all behavior local; no account or backend is implied.

### 7.5 Settings

- Profile-free settings screen focused on race experience.
- Favorite team selector:
  - All eleven teams.
  - Initial state is “No favorite / Neutral.”
  - Selection immediately updates app accent treatments.
- Notifications:
  - Session start.
  - Flag changes.
  - Team radio.
  - Pit stops.
  - Results/news.
- Experience:
  - Haptics toggle (visual preference only in web prototype).
  - Data saver toggle; when enabled, remote imagery receives a muted/placeholder presentation rather than fetching new nonessential imagery where practical.
  - Auto-play radio waveform toggle.
- Units:
  - Celsius/Fahrenheit.
  - km/h/mph.
  - Values on Pitwall and Telemetry update from these preferences.
- Accessibility:
  - Reduce motion override.
  - Increased contrast toggle.
  - Compact/comfortable timing density choice.
- About/data panel:
  - `SIMULATED DATA` disclosure.
  - Prototype version and data-refresh label.

## 8. Component Variants and State Contracts

### `TimingRow`

- `normal`: standard slate surface and complete metrics.
- `drs`: green DRS pill and faint green edge treatment.
- `pit`: amber status pill; gap area replaced by pit state where appropriate.
- `retired`: reduced contrast, muted red wash, and retirement reason.
- Orthogonal modifiers:
  - `selected`
  - `fastestLap`
  - positive/negative/neutral position delta
  - tyre compound S/M/H/I/W

### `SessionFlag`

- `green`: clear/active racing.
- `yellow`: sector or local caution.
- `vsc`: yellow/orange restriction treatment and target-delta copy.
- `sc`: orange treatment and queue/speed instruction.
- `red`: prominent stoppage treatment.
- Warning animation applies only to Yellow/VSC/SC/Red and is removed under reduced motion.

### Shared Controls

- Segmented controls use accessible button groups with selected state.
- Toggles expose `role="switch"` and keyboard behavior.
- Interactive cards have visible focus states.
- Icon-only actions always have accessible labels.

## 9. Responsive and Accessibility Behavior

- Primary target: 390 × 844 px.
- Validate down to approximately 360 px without horizontal page overflow.
- On wider screens, keep a centered mobile presentation rather than stretching timing rows beyond readable measure.
- Horizontal scrolling is limited to intentional carousels and segmented controls, both with snap/visible continuation cues.
- Use semantic regions and sensible heading hierarchy.
- Maintain WCAG AA contrast for body text and controls; secondary text remains readable against surfaces.
- Never rely on constructor color, compound color, or flag color alone; pair with labels, letters, and/or icons.
- Touch controls are at least 44 px in their primary hit dimension.
- Images have meaningful alt text or empty alt text when purely decorative.

## 10. Implementation Sequence

1. Add types and deterministic mock data.
2. Establish global tokens, fonts, canvas, safe-area behavior, focus styles, and motion utilities in `index.css`.
3. Build local UI primitives, SVG icon set, image fallback wrapper, flag variants, timing-row variants, and bottom navigation.
4. Implement root app state and five-screen navigation.
5. Implement Pitwall and validate the foundational visual language.
6. Implement Telemetry modes, 22-driver timing tower, row selection, radio state, and strategy views.
7. Implement Driver and Constructor standings with podium and favorite-team behavior.
8. Implement Predictor validation/locked state.
9. Implement Settings and connect preferences to units, motion, contrast, density, imagery, and app accent.
10. Perform responsive, accessibility, asset-fallback, and build checks; fix only issues relevant to this implementation.

## 11. Verification Plan

### Automated

- Run the repository formatter using its documented command: `pnpm format`.
- Run the production build using the documented package script: `pnpm build`.
- Search produced source files for accidental uncentralized team/semantic colors and obvious invalid raw interactive markup patterns.

### Manual Preview

- Check each of the five bottom-navigation destinations at 390 × 844.
- Check a narrow mobile width around 360 px and a wider desktop preview.
- Confirm no page-level horizontal overflow.
- Exercise:
  - session flag variant control;
  - all four telemetry modes;
  - timing-row selection;
  - radio play/pause and single-playing behavior;
  - Drivers/Constructors switch;
  - favorite-team selection and neutral reset;
  - unit conversion;
  - reduced motion and density settings;
  - predictor duplicate prevention, incomplete validation, submit, lock, and edit;
  - remote image failure fallbacks.
- Confirm focus visibility and keyboard activation for navigation, segment controls, rows, toggles, radio actions, predictor controls, and links.
- Confirm the UI remains understandable with color removed or reduced because all semantic states include text/icon reinforcement.

## 12. Out of Scope

- Real Formula 1 timing, standings, weather, news, or radio APIs.
- User authentication, cloud persistence, push notification delivery, payments, or social features.
- Actual audio streaming.
- Licensing clearance or bundling of official F1/team/driver media; remote assets are prototype references with resilient fallbacks.
- Native iOS/Android packaging. The deliverable is a responsive web prototype visually and behaviorally designed for mobile.
- A literal editable Figma file/frame hierarchy. Auto-layout intent is implemented as responsive CSS layout and reusable React components in this code repository.
