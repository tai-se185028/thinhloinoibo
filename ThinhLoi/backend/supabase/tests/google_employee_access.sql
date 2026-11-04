-- Run in a disposable/local database, or as a rollback-only verification.
begin;
do $$
declare employee uuid := gen_random_uuid(); unknown_user uuid := gen_random_uuid();
  product uuid := gen_random_uuid(); warehouse uuid := gen_random_uuid(); customer uuid := gen_random_uuid();
begin
  insert into auth.users(id) values(employee), (unknown_user);
  insert into public.profiles(id,username,full_name,role,is_active)
  values(employee,'test_' || left(replace(employee::text,'-',''),20),'OAuth test','warehouse_staff',true);
  insert into public.products(id,sku,name,unit) values(product,product::text,'OAuth test','box');
  insert into public.warehouses(id,code,name) values(warehouse,warehouse::text,'OAuth test');
  insert into public.inventory_balances(warehouse_id,product_id,quantity) values(warehouse,product,1);
  insert into public.customers(id,code,name) values(customer,customer::text,'OAuth test');
  insert into public.invoices(invoice_code,customer_id,created_by) values(employee::text,customer,employee);
  perform set_config('test.employee',employee::text,true);
  perform set_config('test.unknown',unknown_user::text,true);
  perform set_config('request.jwt.claim.sub',unknown_user::text,true);
end $$;

set local role authenticated;
do $$
begin
  assert (select count(*) = 0 from public.products), 'Unknown Google user can read products';
  assert (select count(*) = 0 from public.inventory_balances), 'Unknown Google user can read inventory';
  assert (select count(*) = 0 from public.invoices), 'Unknown Google user can read invoices';
  assert (select count(*) = 0 from public.profiles), 'Employee list leaked';
  begin
    perform public.confirm_inbound_voucher(gen_random_uuid());
    raise exception 'RPC should reject unknown employee';
  exception when raise_exception then
    assert sqlerrm = 'UNAUTHORIZED', 'RPC did not deny missing profile';
  end;
end $$;

select set_config('request.jwt.claim.sub',current_setting('test.employee'),true);
do $$
begin
  assert (select count(*) > 0 from public.products), 'Approved employee cannot read products';
  assert (select count(*) > 0 from public.inventory_balances), 'Approved employee cannot read balances';
  assert (select count(*) > 0 from public.invoices), 'Approved employee cannot read invoices';
  begin
    update public.profiles set role = 'admin' where id = auth.uid();
    raise exception 'Self escalation allowed';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
update public.profiles set is_active = false where id = current_setting('test.employee')::uuid;
set local role authenticated;
do $$
begin
  assert (select count(*) = 0 from public.products), 'Disabled employee retains access';
  assert (select count(*) = 0 from public.inventory_balances), 'Disabled employee retains inventory';
  assert (select count(*) = 0 from public.invoices), 'Disabled employee retains invoices';
  begin
    perform public.finalize_invoice(gen_random_uuid());
    raise exception 'RPC should reject disabled employee';
  exception when raise_exception then
    assert sqlerrm = 'UNAUTHORIZED', 'RPC did not deny disabled employee';
  end;
end $$;
reset role;
do $$
begin
  assert not exists(select 1 from storage.buckets where id in ('product-images','invoice-documents','purchase-documents','company-assets') and public), 'Business bucket is public';
end $$;
rollback;
