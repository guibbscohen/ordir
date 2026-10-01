-- is_seated only backs the row-level policies, so it moves out of the API's public schema
-- (Supabase's advisor flagged it as callable over /rest/v1/rpc). The table functions stay public:
-- they are the API, and each checks the caller itself.
create schema if not exists private;
grant usage on schema private to authenticated;

create function private.is_seated(t uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.table_players p where p.table_id = t and p.user_id = (select auth.uid()));
$$;
revoke execute on function private.is_seated(uuid) from public, anon;
grant execute on function private.is_seated(uuid) to authenticated;

alter policy "Players read their tables" on public.game_tables using (private.is_seated(id));
alter policy "Players see who sits at their tables" on public.table_players using (private.is_seated(table_id));
drop function public.is_seated(uuid);
