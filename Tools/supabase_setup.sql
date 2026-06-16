-- Supabase schema for the "Who will win?" poll.
--
-- Run this once in the Supabase SQL editor (Dashboard → SQL Editor → New query).
-- Then put the project's host + anon key into the gitignored Secrets.xcconfig:
--
--     SupabaseHost    = <project-ref>.supabase.co
--     SupabaseAnonKey = <anon/publishable key>   (Settings → API)
--
-- Design (per product decision):
--   * One immutable vote per user per match — enforced by the (match_id, user_id)
--     primary key. Re-voting is a no-op (client sends Prefer: ignore-duplicates).
--   * Results are global: everyone reads the same aggregated counts.
--   * Individual rows are NOT readable by the anon client (no SELECT policy on the
--     base table); only the aggregated view is exposed, so picks stay private.

-- 1) Raw votes ---------------------------------------------------------------
create table if not exists public.match_votes (
    match_id   text        not null,
    user_id    text        not null,          -- anonymous per-install UUID
    choice     text        not null check (choice in ('home', 'draw', 'away')),
    created_at timestamptz  not null default now(),
    primary key (match_id, user_id)
);

alter table public.match_votes enable row level security;

-- anon may INSERT a vote (with a valid choice) but cannot read/update/delete rows.
drop policy if exists "anon can cast a vote" on public.match_votes;
create policy "anon can cast a vote"
    on public.match_votes
    for insert
    to anon
    with check (choice in ('home', 'draw', 'away'));

grant insert on public.match_votes to anon;

-- 2) Aggregated, public-readable tallies -------------------------------------
-- SECURITY DEFINER view (owned by postgres) so it can count rows the anon role
-- can't read directly. Returns one row per match that has at least one vote.
create or replace view public.match_vote_tallies as
    select
        match_id,
        (count(*) filter (where choice = 'home'))::int as home,
        (count(*) filter (where choice = 'draw'))::int as draw,
        (count(*) filter (where choice = 'away'))::int as away
    from public.match_votes
    group by match_id;

grant select on public.match_vote_tallies to anon;

-- The client reads:  GET /rest/v1/match_vote_tallies?match_id=eq.<id>&select=home,draw,away
-- The client writes: POST /rest/v1/match_votes   {match_id, user_id, choice}
--                    headers: Prefer: resolution=ignore-duplicates,return=minimal
