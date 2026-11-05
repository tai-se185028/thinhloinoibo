begin;

create or replace function public.delete_sales_order_draft(p_sales_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  order_row public.sales_orders%rowtype;
begin
  if actor is null or private.current_user_role() not in ('admin', 'sales_staff') then
    raise exception 'UNAUTHORIZED';
  end if;

  select * into order_row
  from public.sales_orders
  where id = p_sales_order_id
  for update;

  if not found then
    raise exception 'SALES_ORDER_NOT_FOUND';
  end if;
  if order_row.status <> 'draft' then
    raise exception 'SALES_ORDER_NOT_DRAFT';
  end if;

  delete from public.sales_orders where id = p_sales_order_id;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id)
  values (actor, 'delete', 'sales_order', p_sales_order_id);
end;
$$;

revoke all on function public.delete_sales_order_draft(uuid) from public, anon;
grant execute on function public.delete_sales_order_draft(uuid) to authenticated;

commit;
