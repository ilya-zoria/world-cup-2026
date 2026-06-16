#!/usr/bin/env python3
"""Fetch match lineups from API-Football and publish a static feed the app reads.

This is the *central* fetcher in the "fetch once, serve to all users" model: it
runs on a schedule (see .github/workflows/lineups.yml), calls the rate-limited
API-Football endpoint at most a handful of times per match, and writes a single
`lineups.json` that every app install reads for free. The app never calls
API-Football directly — so the free tier's 100-requests/day cap is shared by one
job, not multiplied by every user.

Output shape (decodes directly into the app's MatchLineups models, keyed by our
local match id):

    {
      "generatedAt": "2026-06-16T18:30:00Z",
      "lineups": {
        "m001": {
          "home": {"formation": "4-3-3",
                   "startingXI": [{"id": 1, "name": "...", "position": "G", "shirtNumber": 1}, ...],
                   "bench": [...]},
          "away": {...}
        }
      },
      "_fixtureIds": {"m001": {"fixture": 123, "home": 769, "away": 774}},
      "_attempts":   {"m001": 3}
    }

The `_`-prefixed keys are bookkeeping the app ignores (it only decodes `lineups`).

Request budget: idle runs (no match within its kickoff window per the LOCAL
schedule) make ZERO calls. Active runs make 1 fixtures-map call (cached forever
after) plus ≤ MAX_ATTEMPTS lineup calls per in-window match. With the defaults
that stays comfortably under 100/day even on a 12-match group day.

Usage:
    API_FOOTBALL_KEY=xxx python3 Tools/fetch_lineups.py \
        --matches WorldCup26/Data/matches.json \
        --teams   WorldCup26/Data/teams.json \
        --out     public/lineups.json \
        --base-url https://<owner>.github.io/<repo>/lineups.json   # persist prior runs
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

HOST = "https://v3.football.api-sports.io"
AUTH_HEADER = "x-apisports-key"

# Fetch policy (tunable). Window is relative to kickoff.
PRE_MIN = 40            # start trying this many minutes before kickoff
POST_MIN = 140          # stop trying this many minutes after kickoff
FINALIZE_AFTER_MIN = 25 # once we have a lineup AND we're past KO+this, stop refetching
MAX_ATTEMPTS = 6        # hard cap on calls per match (protects the daily quota)
CALL_SPACING_S = 6      # gap between API calls (free tier per-minute friendliness)

# API-Football team names that differ from our football-data names. Both sides
# are normalised (lowercase, accent/punctuation-stripped) before lookup, so only
# genuinely different spellings need an entry here.
NAME_ALIASES = {
    "korearepublic": "southkorea",
    "republicofkorea": "southkorea",
    "czechrepublic": "czechia",
    "bosniaandherzegovina": "bosniaherzegovina",
    "turkiye": "turkey",
    "usa": "unitedstates",
    "unitedstatesofamerica": "unitedstates",
    "cotedivoire": "ivorycoast",
    "capeverde": "capeverdeislands",
    "drcongo": "congodr",
    "democraticrepublicofcongo": "congodr",
    "congodemocraticrepublic": "congodr",
}


def norm(name: str) -> str:
    s = unicodedata.normalize("NFKD", name or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = "".join(c for c in s.lower() if c.isalnum())
    return NAME_ALIASES.get(s, s)


def api_get(path: str, key: str) -> dict:
    url = f"{HOST}/{path}"
    req = urllib.request.Request(url, headers={AUTH_HEADER: key})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"HTTP {e.code} from API-Football ({path}): {body}")
    except urllib.error.URLError as e:
        raise SystemExit(f"Network error calling API-Football ({path}): {e}")


def check_errors(payload: dict, ctx: str) -> None:
    """API-Football returns 200 with an `errors` field on quota/auth problems."""
    errs = payload.get("errors")
    if errs:  # dict or list, non-empty
        raise SystemExit(f"API-Football error during {ctx}: {json.dumps(errs)}")


def map_players(entries: list) -> list:
    out = []
    for i, e in enumerate(entries or []):
        p = (e or {}).get("player", {}) or {}
        out.append({
            "id": p.get("id") if p.get("id") is not None else -(i + 1),
            "name": p.get("name") or "",
            "position": p.get("pos"),
            "shirtNumber": p.get("number"),
        })
    return out


def map_team_lineup(side: dict) -> dict:
    return {
        "formation": side.get("formation"),
        "startingXI": map_players(side.get("startXI")),
        "bench": map_players(side.get("substitutes")),
    }


def load_base(args) -> dict:
    """Load the previously published feed so lineups persist across runs."""
    empty = {"generatedAt": None, "lineups": {}, "_fixtureIds": {}, "_attempts": {}}
    if args.base_file and Path(args.base_file).exists():
        try:
            data = json.loads(Path(args.base_file).read_text())
        except Exception:
            return empty
    elif args.base_url:
        try:
            with urllib.request.urlopen(args.base_url, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except (urllib.error.HTTPError, urllib.error.URLError, ValueError):
            return empty  # first run / not published yet
    else:
        return empty
    for k, v in empty.items():
        data.setdefault(k, v)
    return data


def parse_dt(s: str) -> datetime:
    # Accept "...Z" and "...+00:00".
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--matches", default="WorldCup26/Data/matches.json")
    ap.add_argument("--teams", default="WorldCup26/Data/teams.json")
    ap.add_argument("--out", default="public/lineups.json")
    ap.add_argument("--base-url", default=None, help="URL of the currently published feed (to persist).")
    ap.add_argument("--base-file", default=None, help="Local prior feed (alternative to --base-url).")
    ap.add_argument("--league", type=int, default=1, help="API-Football league id (World Cup = 1).")
    ap.add_argument("--season", type=int, default=2026)
    ap.add_argument("--now", default=None, help="Override 'now' as ISO8601 (testing).")
    args = ap.parse_args()

    key = os.environ.get("API_FOOTBALL_KEY", "").strip()
    if not key:
        print("ERROR: set API_FOOTBALL_KEY", file=sys.stderr)
        return 2

    now = parse_dt(args.now) if args.now else datetime.now(timezone.utc)
    matches = json.loads(Path(args.matches).read_text())
    teams = {t["id"]: t for t in json.loads(Path(args.teams).read_text())}

    # Which matches are inside their kickoff window right now? (No API call.)
    window = []
    for m in matches:
        if not m.get("homeTeamId") or not m.get("awayTeamId"):
            continue  # knockout slot not resolved yet → no teams to match on
        ko = parse_dt(m["kickoff"])
        mins = (now - ko).total_seconds() / 60.0
        if -PRE_MIN <= mins <= POST_MIN:
            window.append((m, ko, mins))

    base = load_base(args)
    out = {
        "generatedAt": now.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "lineups": dict(base["lineups"]),
        "_fixtureIds": dict(base["_fixtureIds"]),
        "_attempts": dict(base["_attempts"]),
    }

    if not window:
        print("No matches in window — 0 API calls.")
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
        return 0

    print(f"{len(window)} match(es) in window: {[m['id'] for m, _, _ in window]}")
    calls = 0

    # Build the fixture-id map once (cached in the feed thereafter).
    need_map = any(m["id"] not in out["_fixtureIds"] for m, _, _ in window)
    if need_map:
        print("Fetching fixtures map (1 call)...")
        payload = api_get(f"fixtures?league={args.league}&season={args.season}", key)
        check_errors(payload, "fixtures")
        calls += 1
        # Index AF fixtures by (date, frozenset of normalised names).
        af_index = {}
        for f in payload.get("response", []):
            fx, tms = f.get("fixture", {}), f.get("teams", {})
            home, away = tms.get("home", {}), tms.get("away", {})
            try:
                d = parse_dt(fx["date"]).date()
            except Exception:
                continue
            key2 = (d, frozenset({norm(home.get("name", "")), norm(away.get("name", ""))}))
            af_index[key2] = (fx.get("id"), home, away)
        for m, ko, _ in window:
            if m["id"] in out["_fixtureIds"]:
                continue
            hn = norm(teams.get(m["homeTeamId"], {}).get("name", ""))
            an = norm(teams.get(m["awayTeamId"], {}).get("name", ""))
            hit = af_index.get((ko.date(), frozenset({hn, an})))
            if not hit:
                print(f"  ⚠️  no API-Football fixture matched for {m['id']} "
                      f"({m['homeTeamId']} v {m['awayTeamId']} on {ko.date()})")
                continue
            fid, ah, aa = hit
            # Decide which AF side is our home vs away.
            home_id = ah.get("id") if norm(ah.get("name", "")) == hn else aa.get("id")
            away_id = aa.get("id") if home_id == ah.get("id") else ah.get("id")
            out["_fixtureIds"][m["id"]] = {"fixture": fid, "home": home_id, "away": away_id}

    # Fetch lineups for in-window matches, bounded by the policy above.
    for m, ko, mins in window:
        mid = m["id"]
        ref = out["_fixtureIds"].get(mid)
        if not ref or not ref.get("fixture"):
            continue
        have = mid in out["lineups"]
        attempts = out["_attempts"].get(mid, 0)
        if have and mins > FINALIZE_AFTER_MIN:
            continue  # already captured and match is underway/done — final
        if attempts >= MAX_ATTEMPTS:
            continue

        if calls > 0:
            time.sleep(CALL_SPACING_S)
        print(f"  fetching lineups for {mid} (fixture {ref['fixture']}, attempt {attempts + 1})...")
        payload = api_get(f"fixtures/lineups?fixture={ref['fixture']}", key)
        check_errors(payload, "lineups")
        calls += 1
        out["_attempts"][mid] = attempts + 1

        sides = {s.get("team", {}).get("id"): s for s in payload.get("response", [])}
        home = sides.get(ref["home"])
        away = sides.get(ref["away"])
        mapped = {}
        if home and (home.get("startXI") or home.get("substitutes")):
            mapped["home"] = map_team_lineup(home)
        if away and (away.get("startXI") or away.get("substitutes")):
            mapped["away"] = map_team_lineup(away)
        if mapped:
            out["lineups"][mid] = mapped
            print(f"    ✓ stored ({'home' if 'home' in mapped else ''} "
                  f"{'away' if 'away' in mapped else ''})".strip())
        else:
            print("    … not announced yet")

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
    print(f"\nDone. {calls} API call(s); {len(out['lineups'])} match(es) with lineups; wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
