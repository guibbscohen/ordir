-- Tester feedback: usage events, bug reports and tester labels, read by the tester dashboard (a private
-- claude.ai page that queries this project through the owner's Supabase connector, as the service role).
-- Phones only ever add rows: RLS lets anyone insert (signed in or not) and nobody read, update or delete.

-- One row per thing that happened in the app: screens, games, rules questions, errors, ratings.
-- device_id is a random id the phone keeps; user_id links the account when the player is signed in.
create table public.events (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  client_at timestamptz,
  device_id uuid not null,
  session_id uuid not null,
  user_id uuid default auth.uid(),
  name text not null check (name ~ '^[a-z][a-z0-9_]{1,39}$'),
  props jsonb not null default '{}' check (jsonb_typeof(props) = 'object' and pg_column_size(props) < 8000),
  build text check (char_length(build) <= 80),
  lang text check (char_length(lang) <= 12),
  standalone boolean,
  screen text check (char_length(screen) <= 40)
);
create index events_at on public.events (at desc);
create index events_name_at on public.events (name, at desc);
create index events_device on public.events (device_id, at desc);
alter table public.events enable row level security;
create policy "Anyone adds events" on public.events for insert to anon, authenticated
  with check (user_id is null or user_id = auth.uid());

-- A tester's report from "Report a problem": what happened, an optional screenshot (a small JPEG data URL)
-- and the context the app attached. Status, priority and notes are for triage on the dashboard.
create table public.bug_reports (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  device_id uuid not null,
  session_id uuid,
  user_id uuid default auth.uid(),
  description text not null check (char_length(description) between 3 and 4000),
  screenshot text check (screenshot is null or (screenshot like 'data:image/jpeg;base64,%' and char_length(screenshot) < 1500000)),
  context jsonb not null default '{}' check (jsonb_typeof(context) = 'object' and pg_column_size(context) < 32000),
  build text check (char_length(build) <= 80),
  status text not null default 'new' check (status in ('new', 'triaged', 'fixing', 'fixed', 'wontfix')),
  priority text check (priority in ('p1', 'p2', 'p3')),
  notes text check (char_length(notes) <= 4000),
  updated_at timestamptz not null default now()
);
create index bug_reports_at on public.bug_reports (at desc);
alter table public.bug_reports enable row level security;
create policy "Anyone reports a problem" on public.bug_reports for insert to anon, authenticated
  with check ((user_id is null or user_id = auth.uid()) and status = 'new' and priority is null and notes is null);

-- Names for testers' phones ("Ana's iPhone") and which ones are the team's own, set on the dashboard only.
create table public.tester_labels (
  device_id uuid primary key,
  label text not null check (char_length(label) between 1 and 60),
  internal boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.tester_labels enable row level security;
