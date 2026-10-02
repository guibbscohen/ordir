-- Own-phone tables for games without fixed sides (Knarr, Brass: Birmingham, Dune: Imperium): players take
-- numbered seats, Player 1 to Player 4, instead of a faction.

create or replace function private.game_sides(game text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case game
    when 'duneWarForArrakis' then array['atreides', 'harkonnen']
    when 'starWarsRebellion' then array['rebel', 'imperial']
    when 'warOfTheRing2E' then array['freePeoples', 'shadow']
    when 'knarr' then array['seat1', 'seat2', 'seat3', 'seat4']
    when 'brassBirmingham' then array['seat1', 'seat2', 'seat3', 'seat4']
    when 'duneImperium' then array['seat1', 'seat2', 'seat3', 'seat4']
    else array[]::text[]
  end;
$$;
