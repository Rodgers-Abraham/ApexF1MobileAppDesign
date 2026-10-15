import { useEffect, useMemo, useState, type ReactNode } from "react"
import {
  drivers,
  news,
  teamFor,
  teams,
  type Compound,
  type Driver,
  type TeamId,
} from "./data"

type NavId = "pitwall" | "live" | "standings" | "predictor" | "settings"
type FlagType = "green" | "yellow" | "vsc" | "sc" | "red"
type LiveMode = "TIMING" | "MAP" | "RADIO" | "TYRES"

const icons: Record<string, ReactNode> = {
  home: (
    <>
      <path d="m3 11 9-8 9 8" />
      <path d="M5 10v10h14V10" />
      <path d="M9 20v-6h6v6" />
    </>
  ),
  activity: (
    <>
      <path d="M3 12h3l2.5-7 4 14 3-9 2 2H21" />
    </>
  ),
  trophy: (
    <>
      <path d="M8 4h8v4a4 4 0 0 1-8 0V4Z" />
      <path d="M6 5H3v2a4 4 0 0 0 5 4M18 5h3v2a4 4 0 0 1-5 4M12 12v5M8 21h8M9 17h6" />
    </>
  ),
  target: (
    <>
      <circle cx="12" cy="12" r="8" />
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3" />
    </>
  ),
  settings: (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" />
    </>
  ),
  cloud: (
    <>
      <path d="M6 18h11a4 4 0 1 0-.8-7.9A6 6 0 0 0 4.5 12 3 3 0 0 0 6 18Z" />
      <path d="M9 21v-1M14 21v-1" />
    </>
  ),
  arrow: (
    <>
      <path d="M5 12h14M14 7l5 5-5 5" />
    </>
  ),
  radio: (
    <>
      <path d="M5 9v6M9 6v12M13 10v4M17 4v16M21 8v8" />
    </>
  ),
  play: <path d="m9 6 9 6-9 6Z" />,
  pause: (
    <>
      <path d="M9 6v12M15 6v12" />
    </>
  ),
  flag: (
    <>
      <path d="M5 21V4" />
      <path d="M5 5h11l-2 3 2 3H5" />
    </>
  ),
  tyre: (
    <>
      <circle cx="12" cy="12" r="8" />
      <circle cx="12" cy="12" r="3" />
      <path d="M8 5.1 10 9M16 5.1 14 9M8 18.9 10 15M16 18.9 14 15" />
    </>
  ),
  chevron: <path d="m9 18 6-6-6-6" />,
  bolt: <path d="m13 2-8 12h7l-1 8 8-12h-7Z" />,
  check: <path d="m5 12 4 4L19 6" />,
}

interface IconProps {
  name: string
  size?: number
}

function Icon({ name, size = 20 }: IconProps) {
  return (
    <svg
      aria-hidden="true"
      className="icon"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {icons[name]}
    </svg>
  )
}

function Logo() {
  return (
    <div className="logo" aria-label="Apex F1">
      <span className="logo-mark">A</span>
      <span>APEX</span>
      <b>F1</b>
    </div>
  )
}

function AssetImage({
  src,
  alt,
  fallback,
  className = "",
}: {
  src: string
  alt: string
  fallback: string
  className?: string
}) {
  const [failed, setFailed] = useState(false)
  if (failed)
    return (
      <div className={`image-fallback ${className}`} aria-label={alt}>
        {fallback}
      </div>
    )
  return (
    <img
      className={className}
      src={src}
      alt={alt}
      loading="lazy"
      onError={() => setFailed(true)}
    />
  )
}

function ScreenTitle({
  eyebrow,
  title,
  right,
}: {
  eyebrow: string
  title: string
  right?: ReactNode
}) {
  return (
    <header className="screen-title">
      <div>
        <span className="eyebrow">{eyebrow}</span>
        <h1>{title}</h1>
      </div>
      {right}
    </header>
  )
}

interface SectionTitleProps {
  title: string
  meta?: string
}

function SectionTitle({ title, meta }: SectionTitleProps) {
  return (
    <div className="section-title">
      <h2>{title}</h2>
      {meta && <span>{meta}</span>}
    </div>
  )
}

function Segmented<T extends string>({
  items,
  value,
  onChange,
  label,
}: {
  items: T[]
  value: T
  onChange: (item: T) => void
  label: string
}) {
  return (
    <div className="segments" role="group" aria-label={label}>
      {items.map((item) => (
        <button
          key={item}
          className={value === item ? "active" : ""}
          aria-pressed={value === item}
          onClick={() => onChange(item)}
        >
          {item}
        </button>
      ))}
    </div>
  )
}

function TrackMap({
  large = false,
  markers = false,
}: {
  large?: boolean
  markers?: boolean
}) {
  return (
    <svg
      className={`track-map ${large ? "large" : ""}`}
      viewBox="0 0 320 190"
      role="img"
      aria-label="Albert Park circuit map"
    >
      <path
        className="track-shadow"
        d="M55 148c-9-9-20-25-9-37 8-9 31-1 37-15 6-13-15-28-2-41 9-9 24 9 38 4 10-4 10-22 22-26 14-5 23 14 37 13 14 0 19-17 34-18 16-2 18 18 31 24 12 6 29-6 36 6 8 13-14 26-10 41 4 14 29 18 27 34-2 15-24 11-35 18-14 9-15 29-32 31-17 2-23-20-39-23-15-3-29 14-43 7-13-6-16-27-32-28-15-1-29 22-44 10Z"
      />
      <path
        className="track-line"
        d="M55 148c-9-9-20-25-9-37 8-9 31-1 37-15 6-13-15-28-2-41 9-9 24 9 38 4 10-4 10-22 22-26 14-5 23 14 37 13 14 0 19-17 34-18 16-2 18 18 31 24 12 6 29-6 36 6 8 13-14 26-10 41 4 14 29 18 27 34-2 15-24 11-35 18-14 9-15 29-32 31-17 2-23-20-39-23-15-3-29 14-43 7-13-6-16-27-32-28-15-1-29 22-44 10Z"
      />
      <path
        className="drs-zone"
        d="M83 55c9-9 24 9 38 4M243 52c12 6 29-6 36 6M261 151c-14 9-15 29-32 31M96 166c-13-6-16-27-32-28"
      />
      <g className="start-line">
        <path d="M81 154v19" />
        <path d="M76 158h10M76 163h10M76 168h10" />
      </g>
      {markers && (
        <>
          <circle className="car-marker leader" cx="175" cy="46" r="7" />
          <text x="175" y="49">
            N
          </text>
          <circle className="car-marker ferrari" cx="231" cy="41" r="7" />
          <text x="231" y="44">
            L
          </text>
          <circle className="car-marker merc" cx="270" cy="113" r="7" />
          <text x="270" y="116">
            R
          </text>
          <circle className="car-marker redbull" cx="197" cy="169" r="7" />
          <text x="197" y="172">
            V
          </text>
          <circle className="car-marker neutral" cx="105" cy="61" r="7" />
          <text x="105" y="64">
            H
          </text>
        </>
      )}
    </svg>
  )
}

const flagCopy: Record<FlagType, {
  label: string
  detail: string
}> = {
  green: { label: "TRACK CLEAR", detail: "GREEN FLAG · DRS ENABLED" },
  yellow: { label: "YELLOW FLAG", detail: "SECTOR 2 · DEBRIS AT TURN 9" },
  vsc: {
    label: "VIRTUAL SAFETY CAR",
    detail: "MAINTAIN POSITIVE DELTA · 40% REDUCTION",
  },
  sc: {
    label: "SAFETY CAR DEPLOYED",
    detail: "TURN 4 INCIDENT · NO OVERTAKING",
  },
  red: { label: "SESSION STOPPED", detail: "RED FLAG · RETURN TO PIT LANE" },
}

function SessionFlag({
  type,
  compact = false,
}: {
  type: FlagType
  compact?: boolean
}) {
  const copy = flagCopy[type]
  return (
    <div className={`session-flag ${type} ${compact ? "compact" : ""}`}>
      <div className="warning-chevron">
        <Icon name="chevron" size={18} />
      </div>
      <div>
        <span>{copy.label}</span>
        <strong>{copy.detail}</strong>
      </div>
      <Icon name="flag" size={18} />
    </div>
  )
}

function TopBar() {
  return (
    <div className="topbar">
      <Logo />
      <div className="live-cluster">
        <div className="live-pill">
          <i />
          RACE LIVE
        </div>
        <span>R01 · MEL</span>
      </div>
    </div>
  )
}

interface PitwallScreenProps {
  setNav: (nav: NavId) => void
  prefs: Preferences
}

function PitwallScreen({ setNav, prefs }: PitwallScreenProps) {
  const [flag, setFlag] = useState<FlagType>("green")
  const [remaining, setRemaining] = useState({ d: 0, h: 18, m: 42, s: 18 })
  useEffect(() => {
    const timer = window.setInterval(
      () =>
        setRemaining((value) => {
          let total =
            value.d * 86400 + value.h * 3600 + value.m * 60 + value.s - 1
          if (total < 0) total = 172800
          return {
            d: Math.floor(total / 86400),
            h: Math.floor((total % 86400) / 3600),
            m: Math.floor((total % 3600) / 60),
            s: total % 60,
          }
        }),
      1000,
    )
    return () => window.clearInterval(timer)
  }, [])
  return (
    <div className="screen">
      <TopBar />
      <main>
        <section className="gp-hero">
          <div className="hero-grid" />
          <div className="hero-head">
            <div>
              <span className="eyebrow">FORMULA 1 · ROUND 01</span>
              <h1>
                AUSTRALIAN
                <br />
                <em>GRAND PRIX</em>
              </h1>
            </div>
            <span className="flag-round">🇦🇺</span>
          </div>
          <div className="countdown" aria-label="Race countdown">
            {Object.entries(remaining).map(([key, value]) => (
              <div key={key}>
                <strong>{String(value).padStart(2, "0")}</strong>
                <span>
                  {{ d: "DAYS", h: "HRS", m: "MIN", s: "SEC" }[(key as "d")]}
                </span>
              </div>
            ))}
          </div>
          <div className="circuit-wrap">
            <TrackMap />
            <div className="circuit-copy">
              <span>CIRCUIT 01</span>
              <strong>ALBERT PARK</strong>
              <small>MELBOURNE · AUSTRALIA</small>
            </div>
          </div>
          <div className="hero-stats">
            <div>
              <b>58</b>
              <span>LAPS</span>
            </div>
            <div>
              <b>5.278</b>
              <span>KM</span>
            </div>
            <div>
              <b>4</b>
              <span>DRS ZONES</span>
            </div>
          </div>
          <div className="weather-row">
            <div className="weather-main">
              <Icon name="cloud" />
              <div>
                <strong>PARTLY CLOUDY</strong>
                <span>RAIN 10%</span>
              </div>
            </div>
            <div>
              <b>{prefs.celsius ? "24°" : "75°"}</b>
              <span>AIR</span>
            </div>
            <div>
              <b>{prefs.celsius ? "38°" : "100°"}</b>
              <span>TRACK</span>
            </div>
            <div>
              <b>45%</b>
              <span>HUM</span>
            </div>
          </div>
        </section>

        <section className="section-block">
          <SectionTitle title="Race Control" meta="LIVE FEED" />
          <SessionFlag type={flag} />
          <div
            className="flag-selector"
            aria-label="Preview race control states"
          >
            {(["green", "yellow", "vsc", "sc", "red"] as FlagType[]).map(
              (type) => (
                <button
                  key={type}
                  className={`${type} ${flag === type ? "active" : ""}`}
                  onClick={() => setFlag(type)}
                >
                  {type.toUpperCase()}
                </button>
              ),
            )}
          </div>
        </section>

        <section className="section-block">
          <SectionTitle title="Race Pulse" meta="LAP 34 / 58" />
          <button className="race-pulse" onClick={() => setNav("live")}>
            <div>
              <span>LEADER</span>
              <strong>
                <i style={{ background: teamFor("mclaren").color }} />
                NORRIS
              </strong>
              <small>McLAREN · MEDIUM 12L</small>
            </div>
            <div>
              <span>FASTEST LAP</span>
              <strong className="purple">1:21.733</strong>
              <small>PIASTRI · LAP 31</small>
            </div>
            <Icon name="arrow" />
          </button>
        </section>

        <section className="section-block news-section">
          <SectionTitle title="Paddock Feed" meta="LATEST" />
          <div className="news-rail">
            {news.map((item) => (
              <article className="news-card" key={item.headline}>
                <div className="news-image">
                  <AssetImage
                    src={item.image}
                    alt="Formula racing editorial"
                    fallback="APEX"
                  />
                  <span>{item.category}</span>
                </div>
                <div className="news-copy">
                  <h3>{item.headline}</h3>
                  <div>
                    <span>
                      {item.time} READ · PHOTO {item.credit.toUpperCase()}
                    </span>
                    <Icon name="arrow" size={17} />
                  </div>
                </div>
              </article>
            ))}
          </div>
        </section>
      </main>
    </div>
  )
}

function DriverPortrait({
  driver,
  size = "normal",
}: {
  driver: Driver
  size?: "small" | "normal" | "large"
}) {
  return (
    <div
      className={`portrait ${size}`}
      style={{ "--team": teamFor(driver.team).color } as React.CSSProperties}
    >
      <AssetImage
        src={driver.portrait}
        alt={`${driver.name} portrait`}
        fallback={driver.code}
      />
      <span>#{driver.number}</span>
    </div>
  )
}

interface CompoundBadgeProps {
  compound: Compound
  age: number
}

function CompoundBadge({ compound, age }: CompoundBadgeProps) {
  return (
    <div className={`compound compound-${compound.toLowerCase()}`}>
      <b>{compound}</b>
      <span>{age}L</span>
    </div>
  )
}

function TimingRow({
  driver,
  selected,
  onSelect,
  comfortable,
}: {
  driver: Driver
  selected: boolean
  onSelect: () => void
  comfortable: boolean
}) {
  const team = teamFor(driver.team)
  const state = driver.state ?? (driver.drs ? "drs" : "racing")
  return (
    <button
      className={`timing-row ${state} ${selected ? "selected" : ""} ${
        comfortable ? "comfortable" : ""
      }`}
      onClick={onSelect}
      style={{ "--team": team.color } as React.CSSProperties}
    >
      <div className="position">
        <strong>{driver.position}</strong>
        <span
          className={
            driver.change > 0 ? "gain" : driver.change < 0 ? "loss" : ""
          }
        >
          {driver.change > 0
            ? `▲${driver.change}`
            : driver.change < 0
              ? `▼${Math.abs(driver.change)}`
              : "—"}
        </span>
      </div>
      <DriverPortrait driver={driver} size="small" />
      <div className="driver-info">
        <strong>
          {driver.code}
          <small>#{driver.number}</small>
        </strong>
        <span>{team.name}</span>
      </div>
      <div className="gap-info">
        {driver.state === "dnf" ? (
          <>
            <strong>OUT</strong>
            <span>{driver.reason}</span>
          </>
        ) : driver.state === "pit" ? (
          <>
            <strong className="pit-label">IN PIT</strong>
            <span>STOP {driver.pits}</span>
          </>
        ) : (
          <>
            <strong className={driver.position === 1 ? "leader" : ""}>
              {driver.gap}
            </strong>
            <span>INT {driver.interval}</span>
          </>
        )}
      </div>
      <div className="row-badges">
        {driver.drs && <b className="drs-badge">DRS</b>}
        <CompoundBadge compound={driver.compound} age={driver.tyreAge} />
        <small>{driver.pits}P</small>
      </div>
      <div className={`lap-time ${driver.fastest ? "fastest" : ""}`}>
        <strong>{driver.lastLap}</strong>
        <span>{driver.fastest ? "FASTEST" : "LAST LAP"}</span>
      </div>
    </button>
  )
}

interface TelemetryStripProps {
  driver: Driver
  kph: boolean
}

function TelemetryStrip({ driver, kph }: TelemetryStripProps) {
  return (
    <div className="telemetry-strip">
      <div className="telemetry-driver">
        <DriverPortrait driver={driver} size="small" />
        <div>
          <span>ONBOARD</span>
          <strong>{driver.code}</strong>
        </div>
      </div>
      <div>
        <strong>{driver.state === "dnf" ? "0" : kph ? "294" : "183"}</strong>
        <span>{kph ? "KM/H" : "MPH"}</span>
      </div>
      <div>
        <strong>{driver.state === "dnf" ? "N" : "8"}</strong>
        <span>GEAR</span>
      </div>
      <div>
        <strong>{driver.state === "dnf" ? "0" : "97"}</strong>
        <span>THR %</span>
      </div>
      <div>
        <strong>61</strong>
        <span>ERS %</span>
      </div>
    </div>
  )
}

function RadioPanel({
  driver,
  playing,
  onPlay,
}: {
  driver: Driver
  playing: boolean
  onPlay: () => void
}) {
  return (
    <article
      className={`radio-panel ${playing ? "playing" : ""}`}
      style={{ "--team": teamFor(driver.team).color } as React.CSSProperties}
    >
      <div className="radio-head">
        <DriverPortrait driver={driver} />
        <div>
          <span>TEAM RADIO · LAP 33</span>
          <strong>{driver.name}</strong>
          <small>{teamFor(driver.team).name}</small>
        </div>
        <button
          aria-label={`${playing ? "Pause" : "Play"} ${driver.name} radio`}
          onClick={onPlay}
        >
          <Icon name={playing ? "pause" : "play"} />
        </button>
      </div>
      <div className="waveform">
        {Array.from({ length: 36 }, (_, index) => (
          <i key={index} style={{ height: `${8 + ((index * 13) % 26)}px` }} />
        ))}
      </div>
      <p>
        “
        {driver.code === "NOR"
          ? "Box this lap. Confirm box. We are switching to plan C."
          : driver.code === "LEC"
            ? "Mode push. Gap behind is three point seven."
            : "Safety car window is open. Stay out, stay out."}
        ”
      </p>
      <div className="radio-progress">
        <i />
        <span>0:08 / 0:17</span>
      </div>
    </article>
  )
}

interface TelemetryScreenProps {
  comfortable: boolean
  kph: boolean
}

function TelemetryScreen({ comfortable, kph }: TelemetryScreenProps) {
  const [mode, setMode] = useState<LiveMode>("TIMING")
  const [selected, setSelected] = useState("NOR")
  const [playing, setPlaying] = useState<string | null>(null)
  const selectedDriver =
    drivers.find((driver) => driver.code === selected) ?? drivers[0]
  return (
    <div className="screen">
      <main className="live-main">
        <ScreenTitle
          eyebrow="AUSTRALIAN GRAND PRIX"
          title="LIVE TIMING"
          right={
            <div className="sim-badge">
              <i />
              SIMULATED
            </div>
          }
        />
        <div className="lap-progress">
          <div>
            <strong>LAP 34</strong>
            <span>/ 58</span>
            <b>58.6%</b>
          </div>
          <div className="progress">
            <i style={{ width: "58.6%" }} />
          </div>
        </div>
        <SessionFlag type="sc" compact />
        <Segmented
          items={["TIMING", "MAP", "RADIO", "TYRES"] as LiveMode[]}
          value={mode}
          onChange={setMode}
          label="Live telemetry mode"
        />
        {mode === "TIMING" && (
          <section className="timing-list">
            <div className="tower-labels">
              <span>POS / DRIVER</span>
              <span>GAP / INT</span>
              <span>TYRE</span>
              <span>LAST LAP</span>
            </div>
            {drivers.map((driver) => (
              <TimingRow
                key={driver.code}
                driver={driver}
                selected={selected === driver.code}
                onSelect={() => setSelected(driver.code)}
                comfortable={comfortable}
              />
            ))}
          </section>
        )}
        {mode === "MAP" && (
          <section className="map-panel">
            <div className="map-status">
              <div>
                <span>LIVE TRACK</span>
                <strong>ALBERT PARK</strong>
              </div>
              <div className="clear-dot">TRACK CLEAR</div>
            </div>
            <TrackMap large markers />
            <div className="map-legend">
              <span>
                <i className="sector s1" />
                SECTOR 1
              </span>
              <span>
                <i className="sector s2" />
                SECTOR 2
              </span>
              <span>
                <i className="sector s3" />
                SECTOR 3
              </span>
              <span>
                <i className="drs-line" />
                DRS
              </span>
            </div>
            <TelemetryStrip driver={selectedDriver} kph={kph} />
          </section>
        )}
        {mode === "RADIO" && (
          <section className="radio-list">
            <div className="radio-live-title">
              <Icon name="radio" />
              <div>
                <strong>TEAM RADIO STREAM</strong>
                <span>3 NEW MESSAGES · LAP 33</span>
              </div>
            </div>
            {drivers.slice(0, 3).map((driver) => (
              <RadioPanel
                key={driver.code}
                driver={driver}
                playing={playing === driver.code}
                onPlay={() =>
                  setPlaying(playing === driver.code ? null : driver.code)
                }
              />
            ))}
          </section>
        )}
        {mode === "TYRES" && (
          <section className="strategy-panel">
            <div className="compound-legend">
              {(["S", "M", "H", "I", "W"] as Compound[]).map((compound) => (
                <CompoundBadge key={compound} compound={compound} age={0} />
              ))}
            </div>
            {drivers.slice(0, 12).map((driver) => (
              <div
                className="strategy-row"
                key={driver.code}
                style={
                  {
                    "--team": teamFor(driver.team).color,
                  } as React.CSSProperties
                }
              >
                <strong>{driver.position}</strong>
                <span className="strategy-code">{driver.code}</span>
                <div className="stints">
                  <i
                    className="stint soft"
                    style={{ width: `${25 + (driver.position % 4) * 5}%` }}
                  >
                    S
                  </i>
                  <i
                    className={`stint ${
                      driver.compound === "H" ? "hard" : "medium"
                    }`}
                    style={{ flex: 1 }}
                  >
                    {driver.compound} · {driver.tyreAge}L
                  </i>
                </div>
                <span className="pit-window">
                  {driver.position % 3 === 0
                    ? "BOX NOW"
                    : `L${40 + driver.position}–${43 + driver.position}`}
                </span>
              </div>
            ))}
            <div className="strategy-call">
              <Icon name="bolt" />
              <div>
                <span>PITWALL PREDICTION</span>
                <strong>Undercut window opening</strong>
                <p>
                  Medium runners gain an estimated 1.8s by stopping before lap
                  39.
                </p>
              </div>
            </div>
          </section>
        )}
        {mode === "TIMING" && (
          <TelemetryStrip driver={selectedDriver} kph={kph} />
        )}
      </main>
    </div>
  )
}

function StandingsScreen({ favorite }: { favorite: TeamId | null }) {
  const [tab, setTab] = useState<"DRIVERS" | "CONSTRUCTORS">("DRIVERS")
  const ranked = [...drivers]
    .sort((a, b) => b.points - a.points)
    .map((d, i) => ({ ...d, position: i + 1 }))
  return (
    <div className="screen">
      <main>
        <ScreenTitle eyebrow="2026 FIA FORMULA ONE" title="CHAMPIONSHIP" />
        <Segmented
          items={["DRIVERS", "CONSTRUCTORS"]}
          value={tab}
          onChange={setTab}
          label="Standings type"
        />
        {tab === "DRIVERS" ? (
          <>
            <section className="podium">
              {[ranked[1], ranked[0], ranked[2]].map((driver, index) => {
                const place = index === 1 ? 1 : index === 0 ? 2 : 3
                return (
                  <article
                    className={`podium-card place-${place}`}
                    key={driver.code}
                    style={
                      {
                        "--team": teamFor(driver.team).color,
                      } as React.CSSProperties
                    }
                  >
                    <span className="podium-place">0{place}</span>
                    <span className="podium-flag">{driver.flag}</span>
                    <DriverPortrait driver={driver} size="large" />
                    <div>
                      <strong>{driver.code}</strong>
                      <small>{driver.name}</small>
                      <b>
                        {driver.points}
                        <em> PTS</em>
                      </b>
                      <span>
                        {driver.wins} WINS · {teamFor(driver.team).name}
                      </span>
                    </div>
                  </article>
                )
              })}
            </section>
            <section className="standings-list">
              {ranked.slice(3).map((driver) => (
                <article
                  className="standing-row"
                  key={driver.code}
                  style={
                    {
                      "--team": teamFor(driver.team).color,
                    } as React.CSSProperties
                  }
                >
                  <strong className="rank">{driver.position}</strong>
                  <DriverPortrait driver={driver} size="small" />
                  <div className="standing-name">
                    <strong>
                      {driver.code}
                      <span>{driver.flag}</span>
                    </strong>
                    <small>{teamFor(driver.team).name}</small>
                  </div>
                  <span className="wins">
                    {driver.wins ? `${driver.wins}W` : "—"}
                  </span>
                  <strong className="points">
                    {driver.points}
                    <small> PTS</small>
                  </strong>
                </article>
              ))}
            </section>
          </>
        ) : (
          <section className="constructor-list">
            {teams.map((team, index) => (
              <article
                className={`constructor-card ${
                  favorite === team.id ? "favorite" : ""
                }`}
                key={team.id}
                style={{ "--team": team.color } as React.CSSProperties}
              >
                <div className="constructor-rank">
                  {String(index + 1).padStart(2, "0")}
                </div>
                <div className="team-mark">{team.mark}</div>
                <div className="constructor-copy">
                  <span>
                    {favorite === team.id
                      ? "★ FAVORITE TEAM"
                      : "2026 CONSTRUCTOR"}
                  </span>
                  <strong>{team.name}</strong>
                  <small>{team.spec}</small>
                </div>
                <div className="car-silhouette">
                  <i />
                  <i />
                  <span />
                </div>
                <div className="constructor-points">
                  <strong>{team.points}</strong>
                  <span>PTS</span>
                </div>
              </article>
            ))}
          </section>
        )}
      </main>
    </div>
  )
}

function DriverPicker({
  excluded,
  onPick,
}: {
  excluded: string[]
  onPick: (code: string) => void
}) {
  return (
    <div className="driver-picker">
      {drivers
        .slice(0, 12)
        .filter((driver) => !excluded.includes(driver.code))
        .map((driver) => (
          <button
            key={driver.code}
            onClick={() => onPick(driver.code)}
            style={
              { "--team": teamFor(driver.team).color } as React.CSSProperties
            }
          >
            <DriverPortrait driver={driver} size="small" />
            <span>
              <strong>{driver.code}</strong>
              <small>{teamFor(driver.team).name}</small>
            </span>
          </button>
        ))}
    </div>
  )
}

function PredictorScreen() {
  const [picks, setPicks] = useState<(string | null)[]>(["NOR", "LEC", null])
  const [activeSlot, setActiveSlot] = useState<number | null>(null)
  const [pole, setPole] = useState("LEC")
  const [fastest, setFastest] = useState("PIA")
  const [safetyCars, setSafetyCars] = useState(1)
  const [confidence, setConfidence] = useState(72)
  const [locked, setLocked] = useState(false)
  const [error, setError] = useState(false)
  const submit = () => {
    if (picks.some((pick) => !pick)) {
      setError(true)
      return
    }
    setError(false)
    setLocked(true)
  }
  return (
    <div className="screen">
      <main>
        <ScreenTitle
          eyebrow="RACE WEEKEND"
          title="PREDICTOR"
          right={
            <div className="lock-time">
              <span>LOCKS IN</span>
              <strong>18:42:18</strong>
            </div>
          }
        />
        <div className="predictor-hero">
          <div className="target-rings">
            <Icon name="target" size={32} />
          </div>
          <div>
            <span>ROUND 01 · MELBOURNE</span>
            <strong>{locked ? "PICKS LOCKED" : "CALL THE RACE"}</strong>
            <p>
              {locked
                ? "Your race card is live. Track your score as the Grand Prix unfolds."
                : "Build your race card. Higher confidence means higher reward — and higher risk."}
            </p>
          </div>
          <b>{locked ? "LIVE" : "0/5"}</b>
        </div>
        <SectionTitle title="Podium Prediction" meta="30 PTS" />
        <section className="podium-picks">
          {picks.map((pick, index) => {
            const driver = drivers.find((item) => item.code === pick)
            return (
              <button
                disabled={locked}
                key={index}
                className={`pick-slot pick-${index + 1} ${
                  activeSlot === index ? "active" : ""
                }`}
                onClick={() =>
                  setActiveSlot(activeSlot === index ? null : index)
                }
              >
                <span>P{index + 1}</span>
                {driver ? (
                  <>
                    <DriverPortrait driver={driver} />
                    <strong>{driver.code}</strong>
                    <small>{teamFor(driver.team).name}</small>
                  </>
                ) : (
                  <>
                    <div className="empty-driver">+</div>
                    <strong>SELECT</strong>
                    <small>DRIVER</small>
                  </>
                )}
              </button>
            )
          })}
        </section>
        {activeSlot !== null && !locked && (
          <DriverPicker
            excluded={picks.filter(Boolean) as string[]}
            onPick={(code) => {
              const next = [...picks]
              next[activeSlot] = code
              setPicks(next)
              setActiveSlot(null)
            }}
          />
        )}
        {error && (
          <div className="form-error">
            Complete all three podium positions before locking your picks.
          </div>
        )}
        <SectionTitle title="Race Calls" meta="20 PTS" />
        <section className="race-calls">
          <label>
            <span>POLE SITTER</span>
            <select
              value={pole}
              disabled={locked}
              onChange={(event) => setPole(event.target.value)}
            >
              {drivers.slice(0, 10).map((driver) => (
                <option key={driver.code}>{driver.code}</option>
              ))}
            </select>
          </label>
          <label>
            <span>FASTEST LAP</span>
            <select
              value={fastest}
              disabled={locked}
              onChange={(event) => setFastest(event.target.value)}
            >
              {drivers.slice(0, 10).map((driver) => (
                <option key={driver.code}>{driver.code}</option>
              ))}
            </select>
          </label>
          <div className="call-stepper">
            <span>SAFETY CARS</span>
            <div>
              <button
                disabled={locked}
                onClick={() => setSafetyCars(Math.max(0, safetyCars - 1))}
              >
                −
              </button>
              <strong>{safetyCars}</strong>
              <button
                disabled={locked}
                onClick={() => setSafetyCars(Math.min(4, safetyCars + 1))}
              >
                +
              </button>
            </div>
          </div>
          <label>
            <span>FIRST TEAM TO PIT</span>
            <select disabled={locked} defaultValue="Williams">
              {teams.map((team) => (
                <option key={team.id}>{team.name}</option>
              ))}
            </select>
          </label>
        </section>
        <section className="confidence">
          <div>
            <span>CONFIDENCE</span>
            <strong>{confidence}%</strong>
          </div>
          <input
            aria-label="Prediction confidence"
            type="range"
            min="25"
            max="100"
            value={confidence}
            disabled={locked}
            onChange={(event) => setConfidence(Number(event.target.value))}
          />
          <div>
            <span>SAFE</span>
            <span>MAX REWARD · {Math.round((50 * confidence) / 100)} PTS</span>
          </div>
        </section>
        {locked ? (
          <button
            className="primary-action secondary"
            onClick={() => setLocked(false)}
          >
            EDIT PICKS
          </button>
        ) : (
          <button className="primary-action" onClick={submit}>
            LOCK MY PICKS <Icon name="arrow" />
          </button>
        )}
      </main>
    </div>
  )
}

interface Preferences {
  celsius: boolean
  kph: boolean
  reduceMotion: boolean
  contrast: boolean
  comfortable: boolean
}

function Toggle({
  value,
  onChange,
  label,
}: {
  value: boolean
  onChange: () => void
  label: string
}) {
  return (
    <button
      className={`toggle ${value ? "on" : ""}`}
      role="switch"
      aria-checked={value}
      aria-label={label}
      onClick={onChange}
    >
      <i />
    </button>
  )
}

function SettingsScreen({
  favorite,
  setFavorite,
  prefs,
  setPrefs,
}: {
  favorite: TeamId | null
  setFavorite: (id: TeamId | null) => void
  prefs: Preferences
  setPrefs: (prefs: Preferences) => void
}) {
  const [notifications, setNotifications] = useState({
    flags: true,
    radio: true,
    pit: true,
    news: false,
  })
  const [experience, setExperience] = useState({
    haptics: true,
    dataSaver: false,
    autoplay: true,
  })
  const update = (key: keyof Preferences) =>
    setPrefs({ ...prefs, [key]: !prefs[key] })
  return (
    <div className="screen">
      <main>
        <ScreenTitle eyebrow="APEX F1 SYSTEM" title="SETTINGS" />
        <SectionTitle
          title="Favorite Team"
          meta={favorite ? teamFor(favorite).name.toUpperCase() : "NEUTRAL"}
        />
        <div className="team-selector">
          <button
            className={!favorite ? "active neutral" : "neutral"}
            onClick={() => setFavorite(null)}
          >
            <span>—</span>
            <small>NEUTRAL</small>
          </button>
          {teams.map((team) => (
            <button
              className={favorite === team.id ? "active" : ""}
              key={team.id}
              style={{ "--team": team.color } as React.CSSProperties}
              onClick={() => setFavorite(team.id)}
            >
              <span>{team.mark}</span>
              <small>{team.name}</small>
            </button>
          ))}
        </div>
        <p className="settings-note">
          Your team color personalizes selected states and highlights without
          changing safety-critical flag colors.
        </p>
        <SectionTitle title="Race Notifications" meta="DEVICE" />
        <div className="settings-group">
          {([
            ["flags", "Flag changes", "Red flags, safety cars and cautions"],
            ["radio", "Team radio", "New messages from selected drivers"],
            ["pit", "Pit stops", "Strategy calls and pit windows"],
            ["news", "Paddock news", "Breaking stories and analysis"],
          ] as const).map(([key, title, description]) => (
            <div className="setting-row" key={key}>
              <div>
                <strong>{title}</strong>
                <span>{description}</span>
              </div>
              <Toggle
                label={title}
                value={notifications[key]}
                onChange={() =>
                  setNotifications({
                    ...notifications,
                    [key]: !notifications[key],
                  })
                }
              />
            </div>
          ))}
        </div>
        <SectionTitle title="Units & Display" />
        <div className="settings-group">
          <div className="setting-row">
            <div>
              <strong>Temperature</strong>
              <span>Weather and track conditions</span>
            </div>
            <button className="unit-switch" onClick={() => update("celsius")}>
              <b className={prefs.celsius ? "active" : ""}>°C</b>
              <b className={!prefs.celsius ? "active" : ""}>°F</b>
            </button>
          </div>
          <div className="setting-row">
            <div>
              <strong>Speed</strong>
              <span>Onboard telemetry</span>
            </div>
            <button className="unit-switch" onClick={() => update("kph")}>
              <b className={prefs.kph ? "active" : ""}>KM/H</b>
              <b className={!prefs.kph ? "active" : ""}>MPH</b>
            </button>
          </div>
          <div className="setting-row">
            <div>
              <strong>Comfortable timing</strong>
              <span>Increase timing tower row height</span>
            </div>
            <Toggle
              label="Comfortable timing density"
              value={prefs.comfortable}
              onChange={() => update("comfortable")}
            />
          </div>
          <div className="setting-row">
            <div>
              <strong>Reduce motion</strong>
              <span>Disable live pulses and waveform motion</span>
            </div>
            <Toggle
              label="Reduce motion"
              value={prefs.reduceMotion}
              onChange={() => update("reduceMotion")}
            />
          </div>
          <div className="setting-row">
            <div>
              <strong>High contrast</strong>
              <span>Strengthen borders and secondary copy</span>
            </div>
            <Toggle
              label="High contrast"
              value={prefs.contrast}
              onChange={() => update("contrast")}
            />
          </div>
        </div>
        <SectionTitle title="Experience" meta="ON DEVICE" />
        <div className="settings-group">
          {([
            ["haptics", "Haptic feedback", "Tactile response for race alerts"],
            ["dataSaver", "Data saver", "Reduce nonessential image loading"],
            ["autoplay", "Auto-play radio", "Animate new radio messages"],
          ] as const).map(([key, title, description]) => (
            <div className="setting-row" key={key}>
              <div>
                <strong>{title}</strong>
                <span>{description}</span>
              </div>
              <Toggle
                label={title}
                value={experience[key]}
                onChange={() =>
                  setExperience({ ...experience, [key]: !experience[key] })
                }
              />
            </div>
          ))}
        </div>
        <div className="about-card">
          <div className="about-icon">
            <Logo />
          </div>
          <div>
            <span>APEX F1 · PROTOTYPE 1.0</span>
            <strong>SIMULATED DATA</strong>
            <p>
              Timing, standings, predictions and radio are illustrative. Not
              affiliated with Formula 1.
            </p>
          </div>
        </div>
      </main>
    </div>
  )
}

function BottomNav({
  active,
  onChange,
  accent,
}: {
  active: NavId
  onChange: (nav: NavId) => void
  accent: string
}) {
  const items: {
    id: NavId
    label: string
    icon: string
  }[] = [
    { id: "pitwall", label: "Pitwall", icon: "home" },
    { id: "live", label: "Live", icon: "activity" },
    { id: "standings", label: "Standings", icon: "trophy" },
    { id: "predictor", label: "Predict", icon: "target" },
    { id: "settings", label: "Settings", icon: "settings" },
  ]
  return (
    <nav
      className="bottom-nav"
      aria-label="Primary"
      style={{ "--accent": accent } as React.CSSProperties}
    >
      {items.map((item) => (
        <button
          key={item.id}
          className={active === item.id ? "active" : ""}
          aria-current={active === item.id ? "page" : undefined}
          onClick={() => onChange(item.id)}
        >
          <Icon name={item.icon} />
          <span>{item.label}</span>
        </button>
      ))}
    </nav>
  )
}

export default function App() {
  const [nav, setNav] = useState<NavId>("pitwall")
  const [favorite, setFavorite] = useState<TeamId | null>(null)
  const [prefs, setPrefs] = useState<Preferences>({
    celsius: true,
    kph: true,
    reduceMotion: false,
    contrast: false,
    comfortable: false,
  })
  const accent = favorite ? teamFor(favorite).color : "#FFFFFF"
  const screen = useMemo(() => {
    if (nav === "pitwall")
      return <PitwallScreen setNav={setNav} prefs={prefs} />
    if (nav === "live")
      return <TelemetryScreen comfortable={prefs.comfortable} kph={prefs.kph} />
    if (nav === "standings") return <StandingsScreen favorite={favorite} />
    if (nav === "predictor") return <PredictorScreen />
    return (
      <SettingsScreen
        favorite={favorite}
        setFavorite={setFavorite}
        prefs={prefs}
        setPrefs={setPrefs}
      />
    )
  }, [nav, favorite, prefs])
  useEffect(() => {
    document
      .querySelector(".app-scroll")
      ?.scrollTo({ top: 0, behavior: "smooth" })
  }, [nav])
  return (
    <div
      className={`app-shell ${prefs.reduceMotion ? "reduce-motion" : ""} ${
        prefs.contrast ? "high-contrast" : ""
      }`}
    >
      <div className="app-scroll">{screen}</div>
      <BottomNav active={nav} onChange={setNav} accent={accent} />
    </div>
  )
}
