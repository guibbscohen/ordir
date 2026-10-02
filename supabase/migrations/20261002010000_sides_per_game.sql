-- Own-phone tables only accepted Dune: War for Arrakis's two sides, so tables for Star Wars: Rebellion and
-- War of the Ring failed with "Pick a side.". The sides now come from each game (as in its turn script).
-- Games without fixed sides (Dune: Imperium, Brass, Knarr) have none here: they're one phone only for now.

create function private.game_sides(game text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case game
    when 'duneWarForArrakis' then array['atreides', 'harkonnen']
    when 'starWarsRebellion' then array['rebel', 'imperial']
    when 'warOfTheRing2E' then array['freePeoples', 'shadow']
    else array[]::text[]
  end;
$$;

-- Only the table functions (security definer) call it.
revoke execute on function private.game_sides(text) from public, anon, authenticated;

create or replace function public.create_table(game text, expansions text[], side text)
returns public.game_tables
language plpgsql
security definer
set search_path = ''
as $$
declare
  player uuid := public.require_player();
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  new_code text;
  created public.game_tables;
begin
  if create_table.side is null or not (create_table.side = any (private.game_sides(create_table.game))) then
    raise exception 'Pick a side.' using errcode = '22023';
  end if;
  loop
    new_code := '';
    for i in 1..6 loop
      new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.game_tables t where t.code = new_code);
  end loop;
  insert into public.game_tables (code, game, expansions, created_by)
    values (new_code, create_table.game, coalesce(create_table.expansions, '{}'), player)
    returning * into created;
  insert into public.table_players (table_id, user_id, side) values (created.id, player, create_table.side);
  return created;
end;
$$;

create or replace function public.join_table(code text, side text)
returns public.game_tables
language plpgsql
security definer
set search_path = ''
as $$
declare
  player uuid := public.require_player();
  found public.game_tables;
begin
  select * into found from public.game_tables t where t.code = upper(trim(join_table.code));
  if found.id is null then
    raise exception 'No table with that code.' using errcode = 'P0002';
  end if;
  if join_table.side is null or not (join_table.side = any (private.game_sides(found.game))) then
    raise exception 'Pick a side.' using errcode = '22023';
  end if;
  if exists (select 1 from public.table_players p
             where p.table_id = found.id and p.side = join_table.side and p.user_id <> player) then
    raise exception 'That side is taken.' using errcode = '23505';
  end if;
  insert into public.table_players (table_id, user_id, side) values (found.id, player, join_table.side)
    on conflict (table_id, user_id) do update set side = excluded.side;
  return found;
end;
$$;
