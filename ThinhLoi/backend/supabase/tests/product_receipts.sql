-- Transactional integration test: all test data is rolled back.
begin;
do $$
declare
  actor uuid;
  item uuid;
  payload jsonb := jsonb_build_object('sku','TEST-RECEIPT-'||gen_random_uuid(),
    'name','Receipt transaction test','unit','cai','purchase_price',100,'selling_price',150,
    'minimum_stock',0,'dimension_unit','cm');
  amount numeric;
  warehouse uuid;
  customer uuid;
  voucher uuid;
begin
  select id into actor from public.profiles where role='admin' and is_active limit 1;
  if actor is null then raise exception 'Test requires an active admin'; end if;
  perform set_config('request.jwt.claim.sub',actor::text,true);
  item := public.receive_product(payload,10);
  perform public.receive_product(payload,5,item);
  perform public.receive_product(payload,0,item);
  select sum(quantity) into amount from public.inventory_balances where product_id=item;
  if amount <> 15 then raise exception 'Expected stock 15, got %',amount; end if;
  if (select count(*) from public.stock_movements where product_id=item) <> 2 then
    raise exception 'Expected exactly two receipts';
  end if;
  begin
    perform public.receive_product(payload,-1,item);
    raise exception 'Negative quantity accepted';
  exception when others then
    if sqlerrm <> 'INVALID_QUANTITY' then raise; end if;
  end;
  select warehouse_id into warehouse from public.inventory_balances where product_id=item;
  insert into public.customers(code,name) values('TEST-'||gen_random_uuid(),'Receipt test customer') returning id into customer;
  voucher := (public.create_outbound_draft_v2(jsonb_build_object(
    'warehouse_id',warehouse,'customer_id',customer,'items',jsonb_build_array(jsonb_build_object(
      'product_id',item,'requested_quantity',4,'actual_quantity',4,'unit_price',150))))->>'id')::uuid;
  perform public.confirm_outbound_voucher(voucher);
  select sum(quantity) into amount from public.inventory_balances where product_id=item;
  if amount <> 11 then raise exception 'Expected remaining stock 11, got %',amount; end if;
end $$;
rollback;
