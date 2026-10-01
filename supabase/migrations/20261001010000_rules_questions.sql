-- Rules questions: the official source text the rules-answer Edge Function reads, and a log of
-- questions asked (for each player's history and a daily cap).

-- One row per page of each official source, extracted by tools/rules_corpus.py. The text is the
-- publisher's, so it is not stored in the repo and no client can read it: RLS is on with no
-- policies, and only the Edge Function (service role) reads it.
create table public.rules_pages (
  game text not null,
  source text not null,
  page integer not null check (page > 0),
  text text not null,
  source_sha256 text not null,
  primary key (game, source, page)
);
alter table public.rules_pages enable row level security;

-- Every question and the cited answer it got. Players see their own; only the function writes.
create table public.rules_questions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  game text not null,
  expansions text[] not null default '{}',
  question text not null check (char_length(question) between 3 and 500),
  answer jsonb,
  model text,
  usage jsonb,
  created_at timestamptz not null default now()
);
create index rules_questions_user_created on public.rules_questions (user_id, created_at desc);
alter table public.rules_questions enable row level security;
create policy "Players read their own questions"
  on public.rules_questions for select
  to authenticated
  using ((select auth.uid()) = user_id);
