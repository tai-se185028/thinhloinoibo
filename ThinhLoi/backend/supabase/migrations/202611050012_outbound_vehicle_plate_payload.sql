begin;

create or replace function public.create_outbound_draft_v2(p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  v_id uuid;
  actor uuid := auth.uid();
  item jsonb;
  v_subtotal numeric(18,2);
  v_discount numeric(18,2);
  order_customer uuid;
begin
  if actor is null or private.current_user_role() not in ('admin','warehouse_staff','sales_staff') then
    raise exception 'UNAUTHORIZED';
  end if;
  if jsonb_array_length(coalesce(p_payload->'items','[]'))=0 then
    raise exception 'EMPTY_VOUCHER';
  end if;
  v_discount := coalesce((p_payload->>'discount_amount')::numeric,0);
  if p_payload->>'sales_order_id' is not null then
    select customer_id into order_customer
    from public.sales_orders
    where id=(p_payload->>'sales_order_id')::uuid
      and status in ('confirmed','partially_fulfilled');
    if order_customer is null or order_customer<>(p_payload->>'customer_id')::uuid then
      raise exception 'INVALID_SALES_ORDER';
    end if;
  end if;

  insert into public.outbound_vouchers(
    voucher_code, warehouse_id, customer_id, sales_order_id, recipient_name,
    recipient_department, delivery_address, dispatch_reason, destination,
    voucher_date, note, discount_amount, vehicle_plate, created_by
  ) values (
    public.next_document_code('PXK'),
    (p_payload->>'warehouse_id')::uuid,
    (p_payload->>'customer_id')::uuid,
    nullif(p_payload->>'sales_order_id','')::uuid,
    p_payload->>'recipient_name',
    p_payload->>'recipient_department',
    p_payload->>'delivery_address',
    p_payload->>'dispatch_reason',
    p_payload->>'destination',
    coalesce((p_payload->>'voucher_date')::date,current_date),
    p_payload->>'note',
    v_discount,
    nullif(trim(p_payload->>'vehicle_plate'),''),
    actor
  ) returning id into v_id;

  for item in select * from jsonb_array_elements(p_payload->'items') loop
    insert into public.outbound_items(
      voucher_id, sales_order_item_id, product_id, quantity,
      requested_quantity, actual_quantity, unit_price
    ) values (
      v_id,
      nullif(item->>'sales_order_item_id','')::uuid,
      (item->>'product_id')::uuid,
      (item->>'actual_quantity')::numeric,
      (item->>'requested_quantity')::numeric,
      (item->>'actual_quantity')::numeric,
      (item->>'unit_price')::numeric
    );
  end loop;

  select coalesce(sum(line_total),0) into v_subtotal
  from public.outbound_items where voucher_id=v_id;
  if v_discount<0 or v_discount>v_subtotal then
    raise exception 'INVALID_DISCOUNT';
  end if;
  update public.outbound_vouchers
  set subtotal=v_subtotal,total_amount=v_subtotal-v_discount
  where id=v_id;
  return jsonb_build_object('id',v_id);
end $$;

revoke all on function public.create_outbound_draft_v2(jsonb) from public, anon;
grant execute on function public.create_outbound_draft_v2(jsonb) to authenticated;

commit;
