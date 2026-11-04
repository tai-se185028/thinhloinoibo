begin;

create or replace function public.create_inbound_draft(p_warehouse_id uuid,p_supplier_id uuid,p_note text,p_items jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; item jsonb; actor uuid:=auth.uid();
begin
 if actor is null or private.current_user_role() not in ('admin','warehouse_staff') then raise exception 'UNAUTHORIZED'; end if;
 if jsonb_array_length(coalesce(p_items,'[]'))=0 then raise exception 'EMPTY_VOUCHER'; end if;
 insert into public.inbound_vouchers(voucher_code,warehouse_id,supplier_id,note,created_by) values(public.next_document_code('PNK'),p_warehouse_id,p_supplier_id,p_note,actor) returning id into v_id;
 for item in select * from jsonb_array_elements(p_items) loop
  insert into public.inbound_items(voucher_id,product_id,quantity,unit_price) values(v_id,(item->>'product_id')::uuid,(item->>'quantity')::numeric,(item->>'unit_price')::numeric);
 end loop;
 update public.inbound_vouchers set total_amount=(select sum(line_total) from public.inbound_items where voucher_id=v_id) where id=v_id;
 return jsonb_build_object('id',v_id);
end; $$;

create or replace function public.create_outbound_draft(p_warehouse_id uuid,p_customer_id uuid,p_note text,p_discount_amount numeric,p_items jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; item jsonb; actor uuid:=auth.uid(); v_subtotal numeric(18,2);
begin
 if actor is null or private.current_user_role() not in ('admin','warehouse_staff','sales_staff') then raise exception 'UNAUTHORIZED'; end if;
 if jsonb_array_length(coalesce(p_items,'[]'))=0 then raise exception 'EMPTY_VOUCHER'; end if;
 if coalesce(p_discount_amount,0)<0 then raise exception 'INVALID_DISCOUNT'; end if;
 insert into public.outbound_vouchers(voucher_code,warehouse_id,customer_id,note,discount_amount,created_by) values(public.next_document_code('PXK'),p_warehouse_id,p_customer_id,p_note,coalesce(p_discount_amount,0),actor) returning id into v_id;
 for item in select * from jsonb_array_elements(p_items) loop
  insert into public.outbound_items(voucher_id,product_id,quantity,unit_price) values(v_id,(item->>'product_id')::uuid,(item->>'quantity')::numeric,(item->>'unit_price')::numeric);
 end loop;
 select sum(line_total) into v_subtotal from public.outbound_items where voucher_id=v_id;
 if p_discount_amount>v_subtotal then raise exception 'INVALID_DISCOUNT'; end if;
 update public.outbound_vouchers set total_amount=v_subtotal-coalesce(p_discount_amount,0) where id=v_id;
 return jsonb_build_object('id',v_id);
end; $$;

create or replace function public.create_invoice_draft(p_customer_id uuid,p_outbound_voucher_id uuid,p_discount_amount numeric,p_items jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; item jsonb; actor uuid:=auth.uid(); v_subtotal numeric(18,2); outbound_status public.document_status;
begin
 if actor is null or private.current_user_role() not in ('admin','sales_staff','accountant') then raise exception 'UNAUTHORIZED'; end if;
 insert into public.invoices(invoice_code,customer_id,outbound_voucher_id,discount_amount,created_by) values(public.next_document_code('HDNB'),p_customer_id,p_outbound_voucher_id,coalesce(p_discount_amount,0),actor) returning id into v_id;
 if p_outbound_voucher_id is not null then
  select status into outbound_status from public.outbound_vouchers where id=p_outbound_voucher_id;
  if outbound_status <> 'confirmed' then raise exception 'OUTBOUND_NOT_CONFIRMED'; end if;
  insert into public.invoice_items(invoice_id,product_id,description,quantity,unit_price)
   select v_id,oi.product_id,p.name,oi.quantity,oi.unit_price from public.outbound_items oi join public.products p on p.id=oi.product_id where oi.voucher_id=p_outbound_voucher_id;
 else
  for item in select * from jsonb_array_elements(coalesce(p_items,'[]')) loop
   insert into public.invoice_items(invoice_id,product_id,description,quantity,unit_price) values(v_id,nullif(item->>'product_id','')::uuid,item->>'description',(item->>'quantity')::numeric,(item->>'unit_price')::numeric);
  end loop;
 end if;
 select coalesce(sum(line_total),0) into v_subtotal from public.invoice_items where invoice_id=v_id;
 if p_discount_amount<0 or p_discount_amount>v_subtotal then raise exception 'INVALID_DISCOUNT'; end if;
 update public.invoices set subtotal=v_subtotal,total_amount=v_subtotal-coalesce(p_discount_amount,0) where id=v_id;
 return jsonb_build_object('id',v_id);
end; $$;

create or replace function public.finalize_invoice(p_invoice_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare inv public.invoices%rowtype; actor uuid:=auth.uid(); calculated numeric(18,2);
begin
 if actor is null or private.current_user_role() not in ('admin','sales_staff','accountant') then raise exception 'UNAUTHORIZED'; end if;
 select * into inv from public.invoices where id=p_invoice_id for update;
 if inv.status<>'draft' then raise exception 'INVOICE_NOT_DRAFT'; end if;
 select coalesce(sum(line_total),0) into calculated from public.invoice_items where invoice_id=inv.id;
 update public.invoices set subtotal=calculated,total_amount=calculated-discount_amount,status='finalized',updated_at=now() where id=inv.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(actor,'finalize','invoice',inv.id);
end; $$;

create or replace function public.record_invoice_payment(p_invoice_id uuid,p_amount numeric,p_payment_method text,p_reference_number text,p_note text) returns void language plpgsql security definer set search_path='' as $$
declare inv public.invoices%rowtype; paid numeric(18,2); actor uuid:=auth.uid();
begin
 if actor is null or private.current_user_role() not in ('admin','accountant') then raise exception 'UNAUTHORIZED'; end if;
 if p_amount<=0 then raise exception 'INVALID_PAYMENT'; end if;
 select * into inv from public.invoices where id=p_invoice_id for update;
 if inv.status<>'finalized' then raise exception 'INVOICE_NOT_FINALIZED'; end if;
 select coalesce(sum(amount),0) into paid from public.payments where invoice_id=inv.id;
 if paid+p_amount>inv.total_amount then raise exception 'OVERPAYMENT'; end if;
 insert into public.payments(invoice_id,amount,payment_method,reference_number,note,created_by) values(inv.id,p_amount,p_payment_method,p_reference_number,p_note,actor);
 paid:=paid+p_amount;
 update public.invoices set payment_status=case when paid=0 then 'unpaid'::public.payment_status when paid<total_amount then 'partial'::public.payment_status else 'paid'::public.payment_status end,updated_at=now() where id=inv.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(actor,'payment','invoice',inv.id,jsonb_build_object('amount',p_amount));
end; $$;

create or replace function public.dashboard_summary() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
  'product_count',(select count(*) from public.products where is_active),
  'stock_quantity',(select coalesce(sum(quantity),0) from public.inventory_balances),
  'stock_value',(select coalesce(sum(b.quantity*p.purchase_price),0) from public.inventory_balances b join public.products p on p.id=b.product_id),
  'inbound_total',(select coalesce(sum(total_amount),0) from public.inbound_vouchers where status='confirmed'),
  'outbound_total',(select coalesce(sum(total_amount),0) from public.outbound_vouchers where status='confirmed'),
  'revenue',(select coalesce(sum(total_amount),0) from public.invoices where status='finalized'),
  'low_stock_count',(select count(*) from public.product_stock_view where stock_quantity<=minimum_stock)
 ); $$;

revoke all on function public.create_inbound_draft(uuid,uuid,text,jsonb),public.create_outbound_draft(uuid,uuid,text,numeric,jsonb),public.create_invoice_draft(uuid,uuid,numeric,jsonb),public.finalize_invoice(uuid),public.record_invoice_payment(uuid,numeric,text,text,text),public.dashboard_summary() from public,anon;
grant execute on function public.create_inbound_draft(uuid,uuid,text,jsonb),public.create_outbound_draft(uuid,uuid,text,numeric,jsonb),public.create_invoice_draft(uuid,uuid,numeric,jsonb),public.finalize_invoice(uuid),public.record_invoice_payment(uuid,numeric,text,text,text),public.dashboard_summary() to authenticated;

commit;
