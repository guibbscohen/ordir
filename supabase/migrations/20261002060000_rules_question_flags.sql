-- Why a rules question didn't get a normal answer, for the daily pause and the tester dashboard:
-- off_topic or manipulation (screened out before Claude Opus read the rules), retried_long (the first
-- answer reached the cap and the retry finished), too_long (the retry reached the cap too). Null otherwise.
alter table public.rules_questions
  add column flag text check (flag in ('off_topic', 'manipulation', 'retried_long', 'too_long'));
create index rules_questions_flagged on public.rules_questions (user_id, created_at desc) where flag is not null;
