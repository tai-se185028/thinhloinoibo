begin;

create or replace function public.consume_auth_login_attempt(p_fingerprint text)
returns boolean
language sql volatile security definer set search_path = '' as $$
  select private.consume_auth_login_attempt(p_fingerprint);
$$;

revoke all on function public.consume_auth_login_attempt(text) from public, anon, authenticated;
grant execute on function public.consume_auth_login_attempt(text) to service_role;

commit;
