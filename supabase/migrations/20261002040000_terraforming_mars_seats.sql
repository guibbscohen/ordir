-- Terraforming Mars (2–5 players, no fixed sides): own-phone tables seat Player 1 to Player 5.

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
    when 'terraformingMars' then array['seat1', 'seat2', 'seat3', 'seat4', 'seat5']
    else array[]::text[]
  end;
$$;
