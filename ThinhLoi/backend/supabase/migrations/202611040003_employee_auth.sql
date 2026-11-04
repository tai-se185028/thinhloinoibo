begin;

alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists phone text;

update public.profiles
set username = 'employee_' || left(replace(id::text, '-', ''), 16)
where username is null;

alter table public.profiles alter column username set not null;
alter table public.profiles alter column is_active set default false;
alter table public.profiles
  add constraint profiles_username_format
  check (username = lower(username) and username ~ '^[a-z0-9_]{3,30}$') not valid;
alter table public.profiles validate constraint profiles_username_format;
alter table public.profiles
  add constraint profiles_phone_format
  check (phone is null or phone ~ '^\+84[0-9]{9,10}$') not valid;
alter table public.profiles validate constraint profiles_phone_format;

create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username));
create unique index if not exists profiles_phone_unique
  on public.profiles (phone) where phone is not null;

create or replace function private.current_user_role()
returns public.app_role
language sql stable security definer set search_path = '' as $$
  select p.role
  from public.profiles p
  where p.id = (select auth.uid()) and p.is_active = true;
$$;

create table if not exists private.auth_login_attempts (
  fingerprint text primary key,
  attempts integer not null default 0,
  window_started_at timestamptz not null default now(),
  blocked_until timestamptz
);

create or replace function private.consume_auth_login_attempt(p_fingerprint text)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_row private.auth_login_attempts%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  insert into private.auth_login_attempts(fingerprint)
  values (p_fingerprint)
  on conflict (fingerprint) do nothing;

  select * into v_row
  from private.auth_login_attempts
  where fingerprint = p_fingerprint
  for update;

  if v_row.blocked_until is not null and v_row.blocked_until > v_now then
    return false;
  end if;

  if v_row.window_started_at < v_now - interval '15 minutes' then
    update private.auth_login_attempts
      set attempts = 1, window_started_at = v_now, blocked_until = null
      where fingerprint = p_fingerprint;
    return true;
  end if;

  update private.auth_login_attempts
    set attempts = attempts + 1,
        blocked_until = case when attempts + 1 >= 8 then v_now + interval '15 minutes' else null end
    where fingerprint = p_fingerprint;
  return v_row.attempts + 1 < 8;
end;
$$;

revoke all on table private.auth_login_attempts from public, anon, authenticated;
revoke all on function private.consume_auth_login_attempt(text) from public, anon, authenticated;
grant execute on function private.consume_auth_login_attempt(text) to service_role;

commit;
