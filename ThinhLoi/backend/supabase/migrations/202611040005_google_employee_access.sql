begin;

-- OAuth creates an Auth identity only. Employees are explicitly provisioned.
alter table public.profiles alter column role drop default;
alter table public.profiles alter column is_active set default false;
revoke insert, update, delete on public.profiles from anon, authenticated;

-- Restrictive policies combine with every existing permissive policy.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'categories','products','warehouses','inventory_balances','suppliers','customers',
    'inbound_vouchers','inbound_items','outbound_vouchers','outbound_items',
    'stock_movements','invoices','invoice_items','invoice_attachments','payments',
    'business_settings','audit_logs'
  ] loop
    execute format('create policy active_employee_required on public.%I as restrictive for all to authenticated using (private.current_user_role() is not null) with check (private.current_user_role() is not null)', table_name);
  end loop;
end $$;

create policy active_employee_documents on storage.objects as restrictive
for all to authenticated
using (bucket_id not in ('product-images','invoice-documents','purchase-documents','company-assets') or private.current_user_role() is not null)
with check (bucket_id not in ('product-images','invoice-documents','purchase-documents','company-assets') or private.current_user_role() is not null);

update storage.buckets set public = false
where id in ('product-images','invoice-documents','purchase-documents','company-assets');

-- SQL NULL NOT IN (...) yields NULL: PL/pgSQL IF would not reject it.
-- Preserve each RPC body and its grants, adding an explicit NULL rejection.
do $$
declare signature text; definition text;
begin
  foreach signature in array array[
    'public.confirm_inbound_voucher(uuid)',
    'public.confirm_outbound_voucher(uuid)',
    'public.create_inbound_draft(uuid,uuid,text,jsonb)',
    'public.create_outbound_draft(uuid,uuid,text,numeric,jsonb)',
    'public.create_invoice_draft(uuid,uuid,numeric,jsonb)',
    'public.finalize_invoice(uuid)',
    'public.record_invoice_payment(uuid,numeric,text,text,text)'
  ] loop
    definition := pg_get_functiondef(signature::regprocedure);
    if position('actor is null or private.current_user_role() not in' in definition) = 0 then
      raise exception 'Unexpected authorization guard in %', signature;
    end if;
    execute replace(definition,
      'actor is null or private.current_user_role() not in',
      'actor is null or private.current_user_role() is null or private.current_user_role() not in');
  end loop;
end $$;

commit;
