#!/usr/bin/env python3
"""Transform cached football-data.org responses into the app's bundled JSON.

Reads Tools/cache/{teams,matches}.json (produced by fetch_football_data.py) plus
the EXISTING WorldCup26/Data/{teams,matches}.json, and regenerates:
    WorldCup26/Data/teams.json   (48 real qualifiers, real group draw)
    WorldCup26/Data/groups.json  (12 groups A-L, real membership)
    WorldCup26/Data/matches.json (104 fixtures: real group stage + bracket)

Design notes:
- Group stage is taken wholesale from the API (real teams/fixtures/scores/ids).
- Knockout teams are undecided in the API and it carries no bracket placeholders,
  so we KEEP the local bracket scaffolding (placeholders, matchNumber, round) and
  only adopt the API's real kickoff/status/score/apiMatchId, matched within each
  round in chronological order.
- The API exposes no venue, so stadiumId is null on every match (see README gap).
- Local-only team fields (flag, isoCode, confederation, fifaRanking) are preserved
  by matching API teams to local teams by code, then by name. The 12 qualifiers
  absent from the old sample data get flag/ISO/confederation from STATIC_TEAM_REF.

Run AFTER fetch_football_data.py. Idempotent; backs up the originals once.
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(__file__).resolve().parent / "cache"
DATA = ROOT / "WorldCup26" / "Data"
BACKUP = CACHE / "local_backup"

# Stage (API) -> KnockoutRound rawValue (app)
STAGE_TO_ROUND = {
    "LAST_32": "round_of_32",
    "LAST_16": "round_of_16",
    "QUARTER_FINALS": "quarter_final",
    "SEMI_FINALS": "semi_final",
    "THIRD_PLACE": "third_place",
    "FINAL": "final",
}

# Flag emoji / ISO / confederation for qualifiers missing from the old sample data.
# (fifaRanking left null — not fabricated; populate from a real source if wanted.)
STATIC_TEAM_REF = {
    "BIH": ("🇧🇦", "ba", "UEFA"),
    "COD": ("🇨🇩", "cd", "CAF"),
    "CPV": ("🇨🇻", "cv", "CAF"),
    "CUW": ("🇨🇼", "cw", "CONCACAF"),
    "CZE": ("🇨🇿", "cz", "UEFA"),
    "HAI": ("🇭🇹", "ht", "CONCACAF"),
    "IRQ": ("🇮🇶", "iq", "AFC"),
    "JOR": ("🇯🇴", "jo", "AFC"),
    "NOR": ("🇳🇴", "no", "UEFA"),
    "RSA": ("🇿🇦", "za", "CAF"),
    "TUR": ("🇹🇷", "tr", "UEFA"),
    "UZB": ("🇺🇿", "uz", "AFC"),
}


def status_from_api(s: str) -> str:
    s = (s or "").upper()
    if s in ("IN_PLAY", "PAUSED", "SUSPENDED"):
        return "live"
    if s in ("FINISHED", "AWARDED"):
        return "finished"
    return "scheduled"  # SCHEDULED, TIMED, POSTPONED, CANCELLED


def score_from_api(api_score: dict | None) -> dict | None:
    if not api_score:
        return None
    ft = api_score.get("fullTime") or {}
    ht = api_score.get("halfTime") or {}
    if ft.get("home") is None and ft.get("away") is None:
        return None  # not played yet -> no score block
    return {
        "home": ft.get("home"),
        "away": ft.get("away"),
        "homeHalfTime": ht.get("home"),
        "awayHalfTime": ht.get("away"),
        "winner": api_score.get("winner"),
    }


def main() -> int:
    api_teams = json.loads((CACHE / "teams.json").read_text())["teams"]
    api_matches = json.loads((CACHE / "matches.json").read_text())["matches"]
    local_teams = json.loads((DATA / "teams.json").read_text())
    local_matches = json.loads((DATA / "matches.json").read_text())

    BACKUP.mkdir(parents=True, exist_ok=True)
    for f in ("teams.json", "groups.json", "matches.json"):
        if not (BACKUP / f).exists():
            shutil.copy2(DATA / f, BACKUP / f)
    print(f"Backed up originals to {BACKUP}")

    local_by_code = {t["id"]: t for t in local_teams}
    local_by_name = {t["name"].strip().lower(): t for t in local_teams}

    # ---- derive group membership from group-stage matches ----
    group_members: dict[str, set] = {}
    for m in api_matches:
        g = m.get("group")
        if not g:
            continue
        letter = g.replace("GROUP_", "")
        for side in ("homeTeam", "awayTeam"):
            tla = (m.get(side) or {}).get("tla")
            if tla:
                group_members.setdefault(letter, set()).add(tla)
    tla_to_group = {tla: g for g, tlas in group_members.items() for tla in tlas}

    # ---- build teams ----
    teams_out = []
    missing_enrichment = []
    for t in api_teams:
        tla = t["tla"]
        name = t["name"]
        local = local_by_code.get(tla) or local_by_name.get(name.strip().lower())
        if local:
            flag = local.get("flag", "")
            iso = local.get("isoCode")
            conf = local.get("confederation")
            rank = local.get("fifaRanking")
        elif tla in STATIC_TEAM_REF:
            flag, iso, conf = STATIC_TEAM_REF[tla]
            rank = None
        else:
            flag, iso, conf, rank = "", None, None, None
            missing_enrichment.append(tla)
        teams_out.append({
            "id": tla,
            "name": name,
            "flag": flag,
            "isoCode": iso,
            "groupId": tla_to_group.get(tla),
            "confederation": conf,
            "fifaRanking": rank,
            "apiTeamId": t["id"],
        })
    teams_out.sort(key=lambda x: (x["groupId"] or "Z", x["id"]))

    # ---- build groups ----
    groups_out = [
        {"id": g, "name": f"Group {g}", "teamIds": sorted(group_members[g])}
        for g in sorted(group_members)
    ]

    # ---- build matches: group stage from API ----
    group_api = sorted(
        (m for m in api_matches if m["stage"] == "GROUP_STAGE"),
        key=lambda m: (m["utcDate"], m["id"]),
    )
    matches_out = []
    for i, m in enumerate(group_api, start=1):
        sc = score_from_api(m.get("score"))
        match = {
            "id": f"m{i:03d}",
            "stage": "group",
            "groupId": (m.get("group") or "").replace("GROUP_", "") or None,
            "round": None,
            "matchNumber": i,
            "homeTeamId": (m.get("homeTeam") or {}).get("tla"),
            "awayTeamId": (m.get("awayTeam") or {}).get("tla"),
            "homePlaceholder": None,
            "awayPlaceholder": None,
            "stadiumId": None,  # API exposes no venue
            "kickoff": m["utcDate"],
            "status": status_from_api(m["status"]),
            "apiMatchId": m["id"],
        }
        if sc is not None:
            match["score"] = sc
        matches_out.append(match)

    # ---- knockout: keep local scaffolding, adopt API kickoff/status/score/id ----
    local_ko_by_round: dict[str, list] = {}
    for m in local_matches:
        if m["stage"] == "knockout":
            local_ko_by_round.setdefault(m["round"], []).append(m)
    for r in local_ko_by_round:
        local_ko_by_round[r].sort(key=lambda m: m.get("matchNumber", 0))

    api_ko_by_round: dict[str, list] = {}
    for m in api_matches:
        r = STAGE_TO_ROUND.get(m["stage"])
        if r:
            api_ko_by_round.setdefault(r, []).append(m)
    for r in api_ko_by_round:
        api_ko_by_round[r].sort(key=lambda m: m["utcDate"])

    ko_out = []
    for r, locals_ in local_ko_by_round.items():
        apis = api_ko_by_round.get(r, [])
        for idx, lm in enumerate(locals_):
            am = apis[idx] if idx < len(apis) else None
            match = {
                "id": lm["id"],
                "stage": "knockout",
                "groupId": None,
                "round": r,
                "matchNumber": lm["matchNumber"],
                "homeTeamId": None,
                "awayTeamId": None,
                "homePlaceholder": lm.get("homePlaceholder"),
                "awayPlaceholder": lm.get("awayPlaceholder"),
                "stadiumId": None,
                "kickoff": am["utcDate"] if am else lm["kickoff"],
                "status": status_from_api(am["status"]) if am else "scheduled",
                "apiMatchId": am["id"] if am else None,
            }
            sc = score_from_api(am.get("score")) if am else None
            if sc is not None:
                match["score"] = sc
            ko_out.append(match)
    ko_out.sort(key=lambda m: m["matchNumber"])
    matches_out.extend(ko_out)

    # ---- write ----
    (DATA / "teams.json").write_text(json.dumps(teams_out, indent=2, ensure_ascii=False) + "\n")
    (DATA / "groups.json").write_text(json.dumps(groups_out, indent=2, ensure_ascii=False) + "\n")
    (DATA / "matches.json").write_text(json.dumps(matches_out, indent=2, ensure_ascii=False) + "\n")

    # ---- summary ----
    played = sum(1 for m in matches_out if "score" in m)
    print(f"\nWrote {len(teams_out)} teams, {len(groups_out)} groups, {len(matches_out)} matches")
    print(f"  group matches: {sum(1 for m in matches_out if m['stage']=='group')}, "
          f"knockout: {sum(1 for m in matches_out if m['stage']=='knockout')}")
    print(f"  matches with a score (played): {played}")
    print(f"  teams enriched from STATIC_TEAM_REF: "
          f"{sorted(set(STATIC_TEAM_REF) & {t['id'] for t in teams_out})}")
    if missing_enrichment:
        print(f"  WARNING: no flag/iso for: {missing_enrichment}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
