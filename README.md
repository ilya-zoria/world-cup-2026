# World Cup 26 — iOS Companion App

A production-quality SwiftUI tournament explorer for the 2026 World Cup. It is an
**offline-first, structured navigation app** (matches, teams, groups, knockout
bracket) — not a live-score streaming product. Bundled JSON is the source of
truth; the Football-Data API only *enriches* match state (status/score) when
configured.

> Built for **iOS 17+ / Xcode 16+**. Uses the Observation framework
> (`@Observable`), async/await networking, and StoreKit 2.

---

## Running it

1. Open `WorldCup26.xcodeproj` in Xcode.
2. Select the **WorldCup26** scheme and an iOS 17+ simulator.
3. Run (`⌘R`). The app works fully offline out of the box with bundled sample
   data — no API key or network required.

The project uses Xcode's **file-system-synchronized groups**, so any file added
under `WorldCup26/` is included automatically; there's nothing to wire up in the
project navigator.

---

## Architecture (MVVM + Repository)

```
View  ──►  ViewModel (@Observable)  ──►  TournamentStore  ──►  Repositories
                                          (single source        ├─ LocalDataRepository  (bundled JSON)
                                           of truth)             └─ MatchAPIRepository   (Football-Data)
```

- **Models** (`Models/`) — `Team`, `Match`, `Group`, `Stadium`, `Score`,
  `MatchStatus`, `KnockoutRound`, `Standing`, plus `MatchVote` /
  `MatchDaySection`.
- **Repositories** (`Repositories/`)
  - `LocalDataRepository` — loads bundled JSON; the offline backbone.
  - `MatchAPIRepository` — fetches dynamic status/score from Football-Data;
    best-effort, never blocks the static experience.
  - `TournamentStore` — `@MainActor @Observable` hub. Loads static data
    synchronously at init (instant, offline), builds indexes, computes
    standings/feed sections locally, and orchestrates API refresh + caching.
- **Services** (`Services/`) — `APIClient`, `InMemoryCache` (TTL),
  `RefreshScheduler`, `LocalizationManager`, `ThemeManager`, and the
  "Who will win?" poll stack: `VoteStore` (coordinator + on-device state),
  `VoteService` (Supabase/PostgREST client), `VoteConfiguration`.
- **ViewModels** (`ViewModels/`) — one per screen, derive from the store.
- **Views** (`Views/`) — `RootView` (4-tab shell) → Home, Groups, Knockout,
  Teams; Settings and the Support link live in the Home header. Plus the core
  `MatchDetailView` (Overview / Stats).
- **Composition root** — `App/AppEnvironment.swift` builds the services once;
  `WorldCup26App` injects them into the environment.

### Offline-first & refresh strategy
- Teams, groups, schedule, stadiums and **standings** are computed locally and
  always available with no network.
- API refresh runs: once on launch, when the app returns to the foreground, on
  an **adaptive timer** (`RefreshScheduler` — ~90s while matches are live, 5 min
  when idle), and on pull-to-refresh. Every path goes through
  `TournamentStore.refresh()`, which applies two throttles tuned for the free
  tier's ~10 calls/min: a **15s hard floor between any two fetches** (so rapid
  pull-to-refresh can't spam the API — it silently no-ops within the window) and
  an adaptive snapshot TTL that automatic refreshes wait out (pull-to-refresh
  bypasses the TTL but not the floor). So the API is **never** called per UI
  interaction nor faster than the rate limit allows.

---

## Data

Bundled JSON lives in `WorldCup26/Data/`: `teams.json` (48), `groups.json` (12,
A–L), `stadiums.json` (16 real host venues), `matches.json` (104 — 72 group +
32 knockout). Keys map 1:1 to the Codable models (camelCase, ISO-8601 dates).

> The bundled JSON is the **real 2026 draw, fixtures and results**, generated
> from the Football-Data API and carrying `apiTeamId` / `apiMatchId` so live
> enrichment merges onto it. Regenerate anytime — see below.

### Regenerating the bundled data

`Tools/` holds a two-step, idempotent pipeline (no extra deps, Python 3 stdlib):

```bash
# 1. fetch raw API JSON into Tools/cache/  (3 calls, rate-limit friendly)
FOOTBALL_DATA_API_KEY=<key> python3 Tools/fetch_football_data.py --season 2026
# 2. transform cache + local-only fields → WorldCup26/Data/{teams,groups,matches}.json
python3 Tools/transform_football_data.py
```

The transform takes the group stage wholesale from the API, keeps the local
**knockout bracket scaffolding** (placeholders/match numbers — the API has no
bracket until teams qualify) while adopting real kickoff/score/`apiMatchId`, and
preserves local-only team fields (flag, ISO code, confederation, FIFA ranking).
Originals are backed up to `Tools/cache/local_backup/` on first run.

### Connecting the Football-Data API (live enrichment)
1. Get a free key at <https://www.football-data.org/client/register>.
2. Put it in `Secrets.xcconfig` at the repo root (gitignored):
   `FootballDataAPIKey = <key>`. `Config.xcconfig` includes it optionally and
   feeds it into the generated Info.plist via the partial `WorldCup26-Info.plist`
   (custom `INFOPLIST_KEY_*` settings are **not** honored by the auto-generator,
   hence the partial-plist + merge approach).
3. Without a key the include is skipped, the key resolves empty, and
   `MatchAPIRepository.isConfigured` stays `false` (app runs fully offline).

### Connecting Supabase (the "Who will win?" poll)

The poll's tallies are **real and global** — aggregated across all users by a
Supabase backend, not seeded. Setup:

1. Create a free project at <https://supabase.com>.
2. Run `Tools/supabase_setup.sql` in the Supabase SQL editor. It creates the
   `match_votes` table (one immutable row per user per match), the public
   `match_vote_tallies` aggregate view, and the RLS policies (anon can insert a
   vote and read aggregate counts, but not read individuals' picks).
3. In `Secrets.xcconfig` (gitignored), add the **host** (no scheme — xcconfig
   treats `//` as a comment) and the anon key from Settings → API:
   ```
   SupabaseHost    = <project-ref>.supabase.co
   SupabaseAnonKey = <anon/publishable key>
   ```
   These flow into Info.plist via `WorldCup26-Info.plist`, same as the API key.
4. Each install gets an anonymous voter UUID; a vote is a single insert keyed by
   `(match_id, user_id)`, so it can't be changed and can't be cast twice. The
   poll only appears for knockout fixtures once both teams are decided.
5. **Without** Supabase configured, `VoteConfiguration.live` is `nil`,
   `VoteStore.isRemoteEnabled` is `false`, and the poll degrades to a local-only
   pick (the user sees their own choice, but no cross-user counts).

---

## Monetization

The app is **ad-free** and monetized via voluntary support:

- **Support** — a "Buy me a coffee" link (`Support/SupportLink.swift`,
  <https://buymeacoffee.com/TienJuf>) surfaced both in the Home header
  (top-left) and in Settings. Update the URL in `SupportLink` to change it.

> Earlier versions shipped banner/interstitial ads and a "Remove Ads" IAP;
> these were removed in favour of the support link. If you ever want ads back,
> reintroduce a `BannerAdView` placeholder + the Google Mobile Ads SDK.

---

## Localization

11 languages: EN, ES, UK (Ukrainian), PT, DE, FR, IT, NL, NB (Norwegian), SV,
DA. Strings live in a single `Resources/Localizable.xcstrings` String Catalog.

The in-app language picker (Settings) overrides the **SwiftUI environment
locale** (`\.locale`) rather than swapping bundles, so the whole UI
re-localizes live without a restart. On-screen text uses `Text(LKey(...))`
(never `String(localized:)`) so it follows that override — see
`Support/Localization+Helpers.swift`.

---

## Known limitations / next steps
- **Venues**: the free API exposes no venue, so `matches[].stadiumId` is `null`.
  `stadiums.json` still ships the 16 real host venues — wire per-match venue
  assignments from the official 2026 schedule if you want them on match cards.
- **FIFA rankings**: `null` for the 12 qualifiers that weren't in the old sample
  set (the transform doesn't fabricate them); populate from a real source if
  wanted. All other team fields are real.
- **Knockout pairings**: bracket placeholders ("Winner Group A" …) are the local
  scaffolding, not yet the verified official 2026 bracket; teams fill in live as
  the group stage resolves.
- **Lineups were intentionally removed.** No fully-free data source has complete
  WC2026 lineups (Football-Data free omits them; API-Football free has no 2026
  season; TheSportsDB free caps at 5 players). Match detail shows Overview / Stats
  only. To add lineups back, a paid data plan would be needed.
- Add a real `AppIcon` before release.
- The "Who will win?" poll needs a Supabase project to show global tallies (see
  *Connecting Supabase* above); until it's configured, votes stay local-only.
  Vote integrity is best-effort — the anon key can insert arbitrary rows, so add
  rate-limiting / verification (e.g. an Edge Function or per-IP throttle) before
  it matters competitively.
