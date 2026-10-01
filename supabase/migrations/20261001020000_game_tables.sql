-- Own-phone play: players sit at a game table (joined by a short code), each on their own phone,
-- and share one guide position. Every change goes through the functions below, which check that
-- the caller is a signed-in player at that table; Realtime sends each change to the other phones.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create table public.game_tables (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  game text not null,
  expansions text[] not null default '{}',
  -- The guide's shared position (phase, step, round, game states, battle, winner), as the
  -- app and the preview keep it. Written only by advance_table, which bumps version.
  state jsonb not null default '{}' check (pg_column_size(state) < 32768),
  version integer not null default 0,
  step_started_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.game_tables enable row level security;

create table public.table_players (
  table_id uuid not null references public.game_tables (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  side text not null,
  joined_at timestamptz not null default now(),
  primary key (table_id, user_id),
  unique (table_id, side)
);
create index table_players_user on public.table_players (user_id);
alter table public.table_players enable row level security;

-- Seated at the table? Security definer so policies on table_players can use it without recursion.
create function public.is_seated(t uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.table_players p where p.table_id = t and p.user_id = (select auth.uid()));
$$;
revoke execute on function public.is_seated(uuid) from public, anon;
grant execute on function public.is_seated(uuid) to authenticated;

create policy "Players read their tables"
  on public.game_tables for select to authenticated
  using (public.is_seated(id));

create policy "Players see who sits at their tables"
  on public.table_players for select to authenticated
  using (public.is_seated(table_id));

create policy "Players read their own profile and their table-mates'"
  on public.profiles for select to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1 from public.table_players mine
      join public.table_players theirs on theirs.table_id = mine.table_id
      where mine.user_id = (select auth.uid()) and theirs.user_id = profiles.id
    )
  );
create policy "Players create their own profile"
  on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy "Players rename themselves"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- A signed-in player with an email account (guests can't host or join).
create function public.require_player()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) then
    raise exception 'Sign in to play at a table.' using errcode = '42501';
  end if;
  return (select auth.uid());
end;
$$;

-- Opens a table and seats its creator; returns the table.
create function public.create_table(game text, expansions text[], side text)
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
  if side not in ('atreides', 'harkonnen') then
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

-- Joins a table by its code on a free side (or switches the caller's own seat); returns the table.
create function public.join_table(code text, side text)
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
  if side not in ('atreides', 'harkonnen') then
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

-- Saves the guide's next position if nobody else moved it first (version check); returns the table.
-- A stale version raises, and the phone reloads the table and shows the newer position.
create function public.advance_table(table_id uuid, expected_version integer, state jsonb, step_changed boolean)
returns public.game_tables
language plpgsql
security definer
set search_path = ''
as $$
declare
  player uuid := public.require_player();
  updated public.game_tables;
begin
  if not exists (select 1 from public.table_players p where p.table_id = advance_table.table_id and p.user_id = player) then
    raise exception 'You are not at this table.' using errcode = '42501';
  end if;
  if jsonb_typeof(advance_table.state) <> 'object' then
    raise exception 'State must be an object.' using errcode = '22023';
  end if;
  update public.game_tables t
    set state = advance_table.state,
        version = t.version + 1,
        step_started_at = case when step_changed then now() else t.step_started_at end,
        updated_at = now()
    where t.id = advance_table.table_id and t.version = expected_version
    returning * into updated;
  if updated.id is null then
    raise exception 'The table moved on; reload.' using errcode = '40001';
  end if;
  return updated;
end;
$$;

-- Leaves a table; the last player out closes it.
create function public.leave_table(table_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  player uuid := public.require_player();
begin
  delete from public.table_players p where p.table_id = leave_table.table_id and p.user_id = player;
  delete from public.game_tables t
    where t.id = leave_table.table_id
      and not exists (select 1 from public.table_players p where p.table_id = t.id);
end;
$$;

revoke execute on function public.require_player() from public, anon;
revoke execute on function public.create_table(text, text[], text) from public, anon;
revoke execute on function public.join_table(text, text) from public, anon;
revoke execute on function public.advance_table(uuid, integer, jsonb, boolean) from public, anon;
revoke execute on function public.leave_table(uuid) from public, anon;
grant execute on function public.require_player() to authenticated;
grant execute on function public.create_table(text, text[], text) to authenticated;
grant execute on function public.join_table(text, text) to authenticated;
grant execute on function public.advance_table(uuid, integer, jsonb, boolean) to authenticated;
grant execute on function public.leave_table(uuid) to authenticated;

-- Each phone subscribes to its table's row and seats; Realtime applies the policies above.
alter publication supabase_realtime add table public.game_tables, public.table_players;
