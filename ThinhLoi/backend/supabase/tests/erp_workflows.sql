-- Run only on a disposable/local database. All changes are rolled back.
begin;
do $$
begin
  assert to_regclass('public.sales_orders') is not null, 'missing sales_orders';
  assert to_regclass('public.sales_order_items') is not null, 'missing sales_order_items';
  assert to_regclass('public.business_documents') is not null, 'missing business_documents';
  assert exists(select 1 from information_schema.columns where table_schema='public' and table_name='outbound_items' and column_name='actual_quantity'), 'missing actual outbound quantity';
  assert exists(select 1 from information_schema.columns where table_schema='public' and table_name='inbound_items' and column_name='actual_received_quantity'), 'missing actual inbound quantity';
  assert exists(select 1 from information_schema.columns where table_schema='public' and table_name='outbound_vouchers' and column_name='company_snapshot'), 'missing document snapshot';
  assert has_function_privilege('anon','public.create_outbound_draft_v2(jsonb)','EXECUTE') = false, 'anon can create dispatch';
  assert has_function_privilege('authenticated','public.create_outbound_draft_v2(jsonb)','EXECUTE'), 'employee cannot create dispatch';
  assert (select relrowsecurity from pg_class where oid='public.sales_orders'::regclass), 'sales_orders RLS disabled';
  assert (select relrowsecurity from pg_class where oid='public.business_documents'::regclass), 'documents RLS disabled';
end $$;
rollback;
