-- Keeps each game's base rules warm in Claude's 1-hour prompt cache, so most rules questions only pay
-- for a cache read. rules-answer records every read here; every 10 minutes the rules-keep-warm job asks it
-- to re-read the base rules of any game nobody has read for 45 minutes (a max_tokens 0 request).

create table private.rules_cache_warmth (
  game text primary key,
  warmed_at timestamptz not null
);

-- Records a read of a game's base rules and returns true, unless the last one was under
-- p_stale_minutes ago (then null). The keep-warm call passes 45, so each game gets at most one
-- keep-warm request per 45 minutes however often the function is called; a real question passes 0.
create function public.claim_rules_cache_warm(p_game text, p_stale_minutes int)
returns boolean
language sql
security definer
set search_path = ''
as $$
  insert into private.rules_cache_warmth as w (game, warmed_at) values (p_game, now())
  on conflict (game) do update set warmed_at = now()
    where w.warmed_at < now() - make_interval(mins => p_stale_minutes)
  returning true;
$$;
revoke execute on function public.claim_rules_cache_warm(text, int) from public, anon, authenticated;
grant execute on function public.claim_rules_cache_warm(text, int) to service_role;

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- The key is the preview's public (publishable) key; the function needs no secret for keep-warm.
select cron.schedule(
  'rules-keep-warm',
  '*/10 * * * *',
  $$
  select net.http_post(
    url := 'https://dhaeqyvdjkhbedqsnqzj.supabase.co/functions/v1/rules-answer',
    headers := '{"Content-Type": "application/json", "apikey": "sb_publishable_8tU1Ih0mwFEaHMz0o_i3gg_nLm2NjjM"}'::jsonb,
    body := '{"keepWarm": true}'::jsonb
  );
  $$
);
