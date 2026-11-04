begin;

create or replace function public.mark_invoice_paid(
  p_invoice_id uuid,
  p_payment_method text default 'bank_transfer'
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  inv public.invoices%rowtype;
  paid numeric(18,2);
  remaining numeric(18,2);
  actor uuid := auth.uid();
begin
  if actor is null or private.current_user_role() not in ('admin', 'accountant') then
    raise exception 'UNAUTHORIZED';
  end if;

  select * into inv from public.invoices where id = p_invoice_id for update;
  if not found then raise exception 'INVOICE_NOT_FOUND'; end if;
  if inv.status <> 'finalized' then raise exception 'INVOICE_NOT_FINALIZED'; end if;

  select coalesce(sum(amount), 0) into paid
  from public.payments
  where invoice_id = inv.id and reversed_at is null;
  remaining := greatest(inv.total_amount - paid, 0);

  if remaining > 0 then
    insert into public.payments(
      invoice_id, amount, payment_method, note, created_by
    ) values (
      inv.id, remaining, p_payment_method, 'Đánh dấu hóa đơn đã thanh toán', actor
    );
  end if;

  update public.invoices
  set payment_status = 'paid', updated_at = now()
  where id = inv.id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values(actor, 'mark_paid', 'invoice', inv.id, jsonb_build_object('amount', remaining));
end;
$$;

revoke all on function public.mark_invoice_paid(uuid, text) from public, anon;
grant execute on function public.mark_invoice_paid(uuid, text) to authenticated;

commit;
