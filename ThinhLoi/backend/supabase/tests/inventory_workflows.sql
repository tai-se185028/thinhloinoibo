begin;
do $$
begin
  assert exists(select 1 from pg_constraint where conname='inventory_balances_quantity_check'), 'Thiếu constraint chống tồn kho âm';
  assert exists(select 1 from pg_indexes where indexname='one_final_invoice_per_outbound'), 'Thiếu unique invoice/outbound';
  assert has_function_privilege('anon','public.confirm_outbound_voucher(uuid)','EXECUTE') = false, 'anon không được gọi RPC xác nhận';
  assert has_function_privilege('authenticated','public.confirm_outbound_voucher(uuid)','EXECUTE') = true, 'authenticated cần quyền gọi RPC';
  assert (select relrowsecurity from pg_class where oid='public.inventory_balances'::regclass), 'inventory_balances phải bật RLS';
  assert (select relrowsecurity from pg_class where oid='public.stock_movements'::regclass), 'stock_movements phải bật RLS';
end $$;
rollback;
