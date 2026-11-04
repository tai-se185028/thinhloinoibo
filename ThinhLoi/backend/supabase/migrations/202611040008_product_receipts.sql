begin;
alter table public.stock_movements drop constraint stock_movements_reference_type_check;
alter table public.stock_movements add constraint stock_movements_reference_type_check
  check (reference_type in ('inbound_voucher','outbound_voucher','reversal','product_receipt'));

create or replace function public.receive_product(p_product jsonb, p_quantity integer, p_product_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  item public.products%rowtype;
  v_product_id uuid;
  warehouse uuid;
  balance numeric;
begin
  if actor is null or coalesce(private.current_user_role()::text,'') not in ('admin','warehouse_staff') then
    raise exception 'UNAUTHORIZED';
  end if;
  if p_quantity is null or p_quantity < 0 or (p_product_id is null and p_quantity = 0) then
    raise exception 'INVALID_QUANTITY';
  end if;
  item := jsonb_populate_record(null::public.products, p_product);
  if coalesce(trim(item.name),'') = '' or coalesce(trim(item.sku),'') = '' then
    raise exception 'PRODUCT_NAME_AND_SKU_REQUIRED';
  end if;
  if p_product_id is null then
    insert into public.products(sku,name,category_id,dimension_length,dimension_width,dimension_height,
      material,unit,packaging_specification,layer_count,dimension_unit,description,purchase_price,selling_price,minimum_stock)
    values(item.sku,item.name,item.category_id,item.dimension_length,item.dimension_width,item.dimension_height,
      item.material,item.unit,item.packaging_specification,item.layer_count,item.dimension_unit,item.description,
      item.purchase_price,item.selling_price,item.minimum_stock) returning id into v_product_id;
  else
    select id into v_product_id from public.products where id=p_product_id and is_active for update;
    if not found then raise exception 'PRODUCT_NOT_FOUND'; end if;
    update public.products set name=item.name,sku=item.sku,category_id=item.category_id,
      dimension_length=item.dimension_length,dimension_width=item.dimension_width,dimension_height=item.dimension_height,
      material=item.material,unit=item.unit,packaging_specification=item.packaging_specification,
      layer_count=item.layer_count,dimension_unit=item.dimension_unit,description=item.description,
      purchase_price=item.purchase_price,selling_price=item.selling_price,minimum_stock=item.minimum_stock,
      updated_at=now() where id=v_product_id;
  end if;
  if p_quantity > 0 then
    select id into warehouse from public.warehouses where is_active order by created_at,id limit 1;
    if warehouse is null then
      insert into public.warehouses(code,name) values('MAIN','Kho chính')
        on conflict(code) do update set is_active=true returning id into warehouse;
    end if;
    insert into public.inventory_balances as b(warehouse_id,product_id,quantity)
      values(warehouse,v_product_id,p_quantity)
      on conflict(warehouse_id,product_id) do update set quantity=b.quantity+excluded.quantity,updated_at=now()
      returning quantity into balance;
    insert into public.stock_movements(warehouse_id,product_id,movement_type,reference_type,reference_id,
      quantity_change,balance_after,created_by)
      values(warehouse,v_product_id,'IN','product_receipt',gen_random_uuid(),p_quantity,balance,actor);
  end if;
  return v_product_id;
end $$;
revoke all on function public.receive_product(jsonb,integer,uuid) from public,anon;
grant execute on function public.receive_product(jsonb,integer,uuid) to authenticated;
commit;
