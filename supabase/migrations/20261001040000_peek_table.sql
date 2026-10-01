-- Join a table by code without knowing its game first: a signed-in player with the code sees which game
-- the table plays, its expansions and which sides are taken, then picks a free side and calls join_table.
-- Nothing else about the table (its state, who sits there) is shown before joining.

create function public.peek_table(code text)
returns table (game text, expansions text[], taken_sides text[])
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  player uuid := public.require_player();
begin
  return query
    select t.game, t.expansions,
           coalesce(array_agg(p.side) filter (where p.side is not null and p.user_id <> player), '{}')
      from public.game_tables t
      left join public.table_players p on p.table_id = t.id
     where t.code = upper(trim(peek_table.code))
     group by t.id;
  if not found then
    raise exception 'No table with that code.' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.peek_table(text) from public, anon;
grant execute on function public.peek_table(text) to authenticated;
