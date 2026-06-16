#!/usr/bin/env python3
"""Fetch raw World Cup data from football-data.org and dump it to Tools/cache/.

Usage:
    FOOTBALL_DATA_API_KEY=xxxx python3 Tools/fetch_football_data.py [--season 2026]

This script ONLY fetches and caches the raw API responses (teams, matches,
standings). Transforming them into the app's bundled JSON schema is done by
transform_football_data.py, which reads from the cache so we never re-hit the
rate-limited API while iterating on the mapping.

Free tier is limited to ~10 calls/min, so this makes only 3 calls and pauses
between them.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://api.football-data.org/v4"
COMPETITION = "WC"  # World Cup, id 2000
CACHE_DIR = Path(__file__).resolve().parent / "cache"

ENDPOINTS = {
    "teams": "competitions/{comp}/teams",
    "matches": "competitions/{comp}/matches",
    "standings": "competitions/{comp}/standings",
}


def get(path: str, api_key: str) -> dict:
    url = f"{BASE}/{path}"
    req = urllib.request.Request(url, headers={"X-Auth-Token": api_key})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"HTTP {e.code} for {url}\n{body}")
    except urllib.error.URLError as e:
        raise SystemExit(f"Network error for {url}: {e}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--season", default=None,
                    help="Season start year, e.g. 2026. Omit to use the API default.")
    args = ap.parse_args()

    api_key = os.environ.get("FOOTBALL_DATA_API_KEY", "").strip()
    if not api_key:
        print("ERROR: set FOOTBALL_DATA_API_KEY env var.", file=sys.stderr)
        return 2

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    season_q = f"?season={args.season}" if args.season else ""

    for i, (name, tmpl) in enumerate(ENDPOINTS.items()):
        path = tmpl.format(comp=COMPETITION) + season_q
        print(f"[{i+1}/{len(ENDPOINTS)}] GET /{path} ...", flush=True)
        data = get(path, api_key)
        out = CACHE_DIR / f"{name}.json"
        out.write_text(json.dumps(data, indent=2, ensure_ascii=False))
        # Tiny summary so we can sanity-check immediately.
        if name == "teams":
            print(f"    -> {data.get('count', '?')} teams")
        elif name == "matches":
            print(f"    -> {data.get('count', '?')} matches")
        elif name == "standings":
            print(f"    -> {len(data.get('standings', []))} standings groups")
        print(f"    cached to {out}")
        if i < len(ENDPOINTS) - 1:
            time.sleep(7)  # stay under ~10 calls/min on the free tier

    print("\nDone. Inspect Tools/cache/*.json next.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
