begin;

-- Non-destructive ERP extension. Existing IDs, rows and RPC signatures remain valid.
do $$ begin
  create type public.sales_order_status as enum ('draft','confirmed','partially_fulfilled','fulfilled','cancelled');
exception when duplicate_object then null; end $$;

alter table public.business_settings
  add column if not exists company_short_name text,
  add column if not exists tax_code text,
  add column if not exists website text,
  add column if not exists representative_name text,
  add column if not exists default_currency text not null default 'VND',
  add column if not exists invoice_footer text,
  add column if not exists created_at timestamptz not null default now();

alter table public.customers
  add column if not exists contact_person text,
  add column if not exists delivery_address text,
  add column if not exists is_active boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();
alter table public.suppliers
  add column if not exists contact_person text,
  add column if not exists delivery_address text,
  add column if not exists is_active boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

alter table public.products
  add column if not exists layer_count integer,
  add column if not exists dimension_unit text not null default 'cm',
  add column if not exists description text;
do $$ begin
  alter table public.products add constraint products_layer_count_check check (layer_count is null or layer_count > 0);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.products add constraint products_dimensions_check check (
    (dimension_length is null or dimension_length > 0) and
    (dimension_width is null or dimension_width > 0) and
    (dimension_height is null or dimension_height > 0)
  );
exception when duplicate_object then null; end $$;

alter table public.inbound_vouchers
  add column if not exists voucher_date date not null default current_date,
  add column if not exists received_by uuid references auth.users(id),
  add column if not exists received_at timestamptz,
  add column if not exists subtotal numeric(18,2) not null default 0,
  add column if not exists discount_amount numeric(18,2) not null default 0,
  add column if not exists shipping_amount numeric(18,2) not null default 0,
  add column if not exists company_snapshot jsonb,
  add column if not exists supplier_snapshot jsonb;
alter table public.inbound_items
  add column if not exists requested_quantity numeric(18,3),
  add column if not exists actual_received_quantity numeric(18,3),
  add column if not exists unit_snapshot text,
  add column if not exists product_snapshot jsonb,
  add column if not exists note text;
update public.inbound_items set
  requested_quantity=coalesce(requested_quantity,quantity),
  actual_received_quantity=coalesce(actual_received_quantity,quantity)
where requested_quantity is null or actual_received_quantity is null;
alter table public.inbound_items alter column requested_quantity set not null;
alter table public.inbound_items alter column actual_received_quantity set not null;

create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  order_code text not null unique,
  customer_id uuid not null references public.customers(id),
  order_date date not null default current_date,
  expected_delivery_date date,
  delivery_address text,
  status public.sales_order_status not null default 'draft',
  note text,
  subtotal numeric(18,2) not null default 0 check (subtotal >= 0),
  discount_amount numeric(18,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(18,2) not null default 0 check (total_amount >= 0),
  customer_snapshot jsonb,
  company_snapshot jsonb,
  created_by uuid not null references auth.users(id),
  confirmed_by uuid references auth.users(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.sales_order_items (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null references public.sales_orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  ordered_quantity numeric(18,3) not null check (ordered_quantity > 0),
  fulfilled_quantity numeric(18,3) not null default 0 check (fulfilled_quantity >= 0 and fulfilled_quantity <= ordered_quantity),
  unit_price numeric(18,2) not null check (unit_price >= 0),
  discount_amount numeric(18,2) not null default 0 check (discount_amount >= 0),
  line_total numeric(18,2) generated always as (round(ordered_quantity * unit_price - discount_amount,2)) stored,
  product_snapshot jsonb,
  unique(sales_order_id,product_id)
);
create index if not exists sales_orders_customer_date_idx on public.sales_orders(customer_id,order_date desc);
create index if not exists sales_order_items_product_idx on public.sales_order_items(product_id);

alter table public.outbound_vouchers
  add column if not exists sales_order_id uuid references public.sales_orders(id),
  add column if not exists recipient_name text,
  add column if not exists recipient_department text,
  add column if not exists delivery_address text,
  add column if not exists dispatch_reason text,
  add column if not exists destination text,
  add column if not exists voucher_date date not null default current_date,
  add column if not exists subtotal numeric(18,2) not null default 0,
  add column if not exists company_snapshot jsonb,
  add column if not exists customer_snapshot jsonb;
alter table public.outbound_items
  add column if not exists sales_order_item_id uuid references public.sales_order_items(id),
  add column if not exists requested_quantity numeric(18,3),
  add column if not exists actual_quantity numeric(18,3),
  add column if not exists unit_snapshot text,
  add column if not exists product_snapshot jsonb;
update public.outbound_items set
  requested_quantity=coalesce(requested_quantity,quantity),
  actual_quantity=coalesce(actual_quantity,quantity)
where requested_quantity is null or actual_quantity is null;
alter table public.outbound_items alter column requested_quantity set not null;
alter table public.outbound_items alter column actual_quantity set not null;
create index if not exists outbound_sales_order_idx on public.outbound_vouchers(sales_order_id);

alter table public.invoices
  add column if not exists finalized_at timestamptz,
  add column if not exists due_date date,
  add column if not exists company_snapshot jsonb,
  add column if not exists customer_snapshot jsonb;
alter table public.invoice_items
  add column if not exists source_outbound_item_id uuid references public.outbound_items(id),
  add column if not exists product_name_snapshot text,
  add column if not exists specification_snapshot text,
  add column if not exists unit_snapshot text,
  add column if not exists discount_amount numeric(18,2) not null default 0;

alter table public.payments
  add column if not exists idempotency_key text,
  add column if not exists reversed_at timestamptz,
  add column if not exists reversed_by uuid references auth.users(id),
  add column if not exists reversal_reason text;
create unique index if not exists payments_idempotency_idx on public.payments(created_by,idempotency_key) where idempotency_key is not null;

create table if not exists public.business_documents (
  id uuid primary key default gen_random_uuid(),
  document_type text not null check (document_type in ('inbound_voucher','outbound_voucher','internal_invoice','supplier_attachment','delivery_document','customer_attachment')),
  reference_id uuid not null,
  partner_id uuid,
  document_code text,
  document_date date not null default current_date,
  file_name text not null,
  storage_path text not null unique,
  mime_type text not null,
  version integer not null default 1 check (version > 0),
  snapshot_hash text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique(document_type,reference_id,version)
);
create index if not exists business_documents_search_idx on public.business_documents(document_type,document_date desc,document_code);

alter table public.sales_orders enable row level security;
alter table public.sales_order_items enable row level security;
alter table public.business_documents enable row level security;
create policy sales_orders_read on public.sales_orders for select to authenticated using (private.current_user_role() is not null);
create policy sales_orders_draft_manage on public.sales_orders for all to authenticated
  using (status='draft' and private.current_user_role() in ('admin','sales_staff'))
  with check (status='draft' and created_by=(select auth.uid()) and private.current_user_role() in ('admin','sales_staff'));
create policy sales_order_items_read on public.sales_order_items for select to authenticated using (private.current_user_role() is not null);
create policy sales_order_items_draft_manage on public.sales_order_items for all to authenticated
  using (exists(select 1 from public.sales_orders s where s.id=sales_order_id and s.status='draft'))
  with check (exists(select 1 from public.sales_orders s where s.id=sales_order_id and s.status='draft' and s.created_by=(select auth.uid())));
create policy business_documents_read on public.business_documents for select to authenticated using (private.current_user_role() is not null);
create policy business_documents_insert on public.business_documents for insert to authenticated
  with check (created_by=(select auth.uid()) and private.current_user_role() is not null);
create policy active_employee_required on public.sales_orders as restrictive for all to authenticated
  using (private.current_user_role() is not null) with check (private.current_user_role() is not null);
create policy active_employee_required on public.sales_order_items as restrictive for all to authenticated
  using (private.current_user_role() is not null) with check (private.current_user_role() is not null);
create policy active_employee_required on public.business_documents as restrictive for all to authenticated
  using (private.current_user_role() is not null) with check (private.current_user_role() is not null);

create or replace function private.company_snapshot() returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(to_jsonb(s),'{}'::jsonb) from public.business_settings s order by s.created_at limit 1
$$;
revoke all on function private.company_snapshot() from public,anon;
grant execute on function private.company_snapshot() to authenticated;

create or replace function public.create_sales_order_draft(
  p_customer_id uuid,p_expected_delivery_date date,p_delivery_address text,p_note text,p_discount_amount numeric,p_items jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; actor uuid:=auth.uid(); item jsonb; v_subtotal numeric(18,2);
begin
  if actor is null or private.current_user_role() not in ('admin','sales_staff') then raise exception 'UNAUTHORIZED'; end if;
  if jsonb_array_length(coalesce(p_items,'[]'))=0 then raise exception 'EMPTY_ORDER'; end if;
  insert into public.sales_orders(order_code,customer_id,expected_delivery_date,delivery_address,note,discount_amount,created_by)
  values(public.next_document_code('DH'),p_customer_id,p_expected_delivery_date,p_delivery_address,p_note,coalesce(p_discount_amount,0),actor) returning id into v_id;
  for item in select * from jsonb_array_elements(p_items) loop
    insert into public.sales_order_items(sales_order_id,product_id,ordered_quantity,unit_price,discount_amount)
    values(v_id,(item->>'product_id')::uuid,(item->>'quantity')::numeric,(item->>'unit_price')::numeric,coalesce((item->>'discount_amount')::numeric,0));
  end loop;
  select coalesce(sum(line_total),0) into v_subtotal from public.sales_order_items where sales_order_id=v_id;
  if coalesce(p_discount_amount,0)<0 or coalesce(p_discount_amount,0)>v_subtotal then raise exception 'INVALID_DISCOUNT'; end if;
  update public.sales_orders set subtotal=v_subtotal,total_amount=v_subtotal-coalesce(p_discount_amount,0) where id=v_id;
  return jsonb_build_object('id',v_id);
end $$;

create or replace function public.confirm_sales_order(p_sales_order_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.sales_orders%rowtype; actor uuid:=auth.uid();
begin
  if actor is null or private.current_user_role() not in ('admin','sales_staff') then raise exception 'UNAUTHORIZED'; end if;
  select * into v from public.sales_orders where id=p_sales_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if v.status<>'draft' then raise exception 'ORDER_NOT_DRAFT'; end if;
  if not exists(select 1 from public.sales_order_items where sales_order_id=v.id) then raise exception 'EMPTY_ORDER'; end if;
  update public.sales_order_items oi set product_snapshot=jsonb_build_object(
    'id',p.id,'sku',p.sku,'name',p.name,'material',p.material,'layer_count',p.layer_count,
    'length',p.dimension_length,'width',p.dimension_width,'height',p.dimension_height,
    'dimension_unit',p.dimension_unit,'unit',p.unit,'specification',p.packaging_specification
  ) from public.products p where oi.sales_order_id=v.id and p.id=oi.product_id;
  update public.sales_orders set status='confirmed',confirmed_by=actor,confirmed_at=now(),
    customer_snapshot=(select to_jsonb(c) from public.customers c where c.id=v.customer_id),
    company_snapshot=private.company_snapshot(),updated_at=now() where id=v.id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(actor,'confirm','sales_order',v.id);
end $$;

create or replace function public.create_inbound_draft_v2(p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; actor uuid:=auth.uid(); item jsonb; v_subtotal numeric(18,2); v_discount numeric(18,2); v_shipping numeric(18,2);
begin
  if actor is null or private.current_user_role() not in ('admin','warehouse_staff') then raise exception 'UNAUTHORIZED'; end if;
  if jsonb_array_length(coalesce(p_payload->'items','[]'))=0 then raise exception 'EMPTY_VOUCHER'; end if;
  v_discount:=coalesce((p_payload->>'discount_amount')::numeric,0); v_shipping:=coalesce((p_payload->>'shipping_amount')::numeric,0);
  insert into public.inbound_vouchers(voucher_code,warehouse_id,supplier_id,voucher_date,note,discount_amount,shipping_amount,created_by)
  values(public.next_document_code('PNK'),(p_payload->>'warehouse_id')::uuid,(p_payload->>'supplier_id')::uuid,
    coalesce((p_payload->>'voucher_date')::date,current_date),p_payload->>'note',v_discount,v_shipping,actor) returning id into v_id;
  for item in select * from jsonb_array_elements(p_payload->'items') loop
    insert into public.inbound_items(voucher_id,product_id,quantity,requested_quantity,actual_received_quantity,unit_price,note)
    values(v_id,(item->>'product_id')::uuid,(item->>'actual_quantity')::numeric,(item->>'requested_quantity')::numeric,
      (item->>'actual_quantity')::numeric,(item->>'unit_price')::numeric,item->>'note');
  end loop;
  select coalesce(sum(line_total),0) into v_subtotal from public.inbound_items where voucher_id=v_id;
  if v_discount<0 or v_shipping<0 or v_discount>v_subtotal+v_shipping then raise exception 'INVALID_TOTALS'; end if;
  update public.inbound_vouchers set subtotal=v_subtotal,total_amount=v_subtotal+v_shipping-v_discount where id=v_id;
  return jsonb_build_object('id',v_id);
end $$;

create or replace function public.create_outbound_draft_v2(p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; actor uuid:=auth.uid(); item jsonb; v_subtotal numeric(18,2); v_discount numeric(18,2); order_customer uuid;
begin
  if actor is null or private.current_user_role() not in ('admin','warehouse_staff','sales_staff') then raise exception 'UNAUTHORIZED'; end if;
  if jsonb_array_length(coalesce(p_payload->'items','[]'))=0 then raise exception 'EMPTY_VOUCHER'; end if;
  v_discount:=coalesce((p_payload->>'discount_amount')::numeric,0);
  if p_payload->>'sales_order_id' is not null then
    select customer_id into order_customer from public.sales_orders where id=(p_payload->>'sales_order_id')::uuid and status in ('confirmed','partially_fulfilled');
    if order_customer is null or order_customer<>(p_payload->>'customer_id')::uuid then raise exception 'INVALID_SALES_ORDER'; end if;
  end if;
  insert into public.outbound_vouchers(voucher_code,warehouse_id,customer_id,sales_order_id,recipient_name,recipient_department,
    delivery_address,dispatch_reason,destination,voucher_date,note,discount_amount,created_by)
  values(public.next_document_code('PXK'),(p_payload->>'warehouse_id')::uuid,(p_payload->>'customer_id')::uuid,
    nullif(p_payload->>'sales_order_id','')::uuid,p_payload->>'recipient_name',p_payload->>'recipient_department',
    p_payload->>'delivery_address',p_payload->>'dispatch_reason',p_payload->>'destination',
    coalesce((p_payload->>'voucher_date')::date,current_date),p_payload->>'note',v_discount,actor) returning id into v_id;
  for item in select * from jsonb_array_elements(p_payload->'items') loop
    insert into public.outbound_items(voucher_id,sales_order_item_id,product_id,quantity,requested_quantity,actual_quantity,unit_price)
    values(v_id,nullif(item->>'sales_order_item_id','')::uuid,(item->>'product_id')::uuid,(item->>'actual_quantity')::numeric,
      (item->>'requested_quantity')::numeric,(item->>'actual_quantity')::numeric,(item->>'unit_price')::numeric);
  end loop;
  select coalesce(sum(line_total),0) into v_subtotal from public.outbound_items where voucher_id=v_id;
  if v_discount<0 or v_discount>v_subtotal then raise exception 'INVALID_DISCOUNT'; end if;
  update public.outbound_vouchers set subtotal=v_subtotal,total_amount=v_subtotal-v_discount where id=v_id;
  return jsonb_build_object('id',v_id);
end $$;

-- Compatibility wrappers for existing Flutter clients.
create or replace function public.create_inbound_draft(p_warehouse_id uuid,p_supplier_id uuid,p_note text,p_items jsonb)
returns jsonb language sql security definer set search_path='' as $$
  select public.create_inbound_draft_v2(jsonb_build_object(
    'warehouse_id',p_warehouse_id,'supplier_id',p_supplier_id,'note',p_note,
    'items',(select coalesce(jsonb_agg(item || jsonb_build_object(
      'requested_quantity',item->'quantity','actual_quantity',item->'quantity'
    )),'[]'::jsonb) from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) item)
  ))
$$;

create or replace function public.create_outbound_draft(p_warehouse_id uuid,p_customer_id uuid,p_note text,p_discount_amount numeric,p_items jsonb)
returns jsonb language sql security definer set search_path='' as $$
  select public.create_outbound_draft_v2(jsonb_build_object(
    'warehouse_id',p_warehouse_id,'customer_id',p_customer_id,'note',p_note,'discount_amount',p_discount_amount,
    'items',(select coalesce(jsonb_agg(item || jsonb_build_object(
      'requested_quantity',item->'quantity','actual_quantity',item->'quantity'
    )),'[]'::jsonb) from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) item)
  ))
$$;

create or replace function public.confirm_inbound_voucher(p_voucher_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.inbound_vouchers%rowtype; r record; new_balance numeric(18,3); actor uuid:=auth.uid();
begin
  if actor is null or private.current_user_role() not in ('admin','warehouse_staff') then raise exception 'UNAUTHORIZED'; end if;
  select * into v from public.inbound_vouchers where id=p_voucher_id for update;
  if not found then raise exception 'VOUCHER_NOT_FOUND'; end if;
  if v.status<>'draft' then raise exception 'ALREADY_CONFIRMED'; end if;
  if not exists(select 1 from public.inbound_items where voucher_id=v.id and actual_received_quantity>0) then raise exception 'EMPTY_RECEIPT'; end if;
  update public.inbound_items i set unit_snapshot=p.unit,product_snapshot=jsonb_build_object('id',p.id,'sku',p.sku,'name',p.name,
    'material',p.material,'layer_count',p.layer_count,'length',p.dimension_length,'width',p.dimension_width,'height',p.dimension_height,
    'dimension_unit',p.dimension_unit,'unit',p.unit,'specification',p.packaging_specification)
  from public.products p where i.voucher_id=v.id and p.id=i.product_id;
  for r in select product_id,sum(actual_received_quantity) qty from public.inbound_items where voucher_id=v.id group by product_id order by product_id loop
    insert into public.inventory_balances(warehouse_id,product_id,quantity) values(v.warehouse_id,r.product_id,0) on conflict do nothing;
    select quantity into new_balance from public.inventory_balances where warehouse_id=v.warehouse_id and product_id=r.product_id for update;
    new_balance:=new_balance+r.qty;
    update public.inventory_balances set quantity=new_balance,updated_at=now() where warehouse_id=v.warehouse_id and product_id=r.product_id;
    insert into public.stock_movements(warehouse_id,product_id,movement_type,reference_type,reference_id,quantity_change,balance_after,created_by)
    values(v.warehouse_id,r.product_id,'IN','inbound_voucher',v.id,r.qty,new_balance,actor);
  end loop;
  update public.inbound_vouchers set status='confirmed',received_by=actor,received_at=now(),confirmed_by=actor,confirmed_at=now(),
    company_snapshot=private.company_snapshot(),supplier_snapshot=(select to_jsonb(s) from public.suppliers s where s.id=v.supplier_id),updated_at=now() where id=v.id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(actor,'confirm','inbound_voucher',v.id);
end $$;

create or replace function public.confirm_outbound_voucher(p_voucher_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.outbound_vouchers%rowtype; r record; current_balance numeric(18,3); actor uuid:=auth.uid();
begin
  if actor is null or private.current_user_role() not in ('admin','warehouse_staff') then raise exception 'UNAUTHORIZED'; end if;
  select * into v from public.outbound_vouchers where id=p_voucher_id for update;
  if not found then raise exception 'VOUCHER_NOT_FOUND'; end if;
  if v.status<>'draft' then raise exception 'ALREADY_CONFIRMED'; end if;
  if not exists(select 1 from public.outbound_items where voucher_id=v.id and actual_quantity>0) then raise exception 'EMPTY_DISPATCH'; end if;
  if exists(select 1 from public.outbound_items where voucher_id=v.id and (actual_quantity<=0 or actual_quantity>requested_quantity)) then raise exception 'INVALID_ACTUAL_QUANTITY'; end if;
  if exists(select 1 from public.outbound_items oi join public.sales_order_items si on si.id=oi.sales_order_item_id
    where oi.voucher_id=v.id and oi.actual_quantity>si.ordered_quantity-si.fulfilled_quantity) then raise exception 'ORDER_QUANTITY_EXCEEDED'; end if;
  update public.outbound_items i set unit_snapshot=p.unit,product_snapshot=jsonb_build_object('id',p.id,'sku',p.sku,'name',p.name,
    'material',p.material,'layer_count',p.layer_count,'length',p.dimension_length,'width',p.dimension_width,'height',p.dimension_height,
    'dimension_unit',p.dimension_unit,'unit',p.unit,'specification',p.packaging_specification)
  from public.products p where i.voucher_id=v.id and p.id=i.product_id;
  for r in select product_id,sum(actual_quantity) qty from public.outbound_items where voucher_id=v.id group by product_id order by product_id loop
    select quantity into current_balance from public.inventory_balances where warehouse_id=v.warehouse_id and product_id=r.product_id for update;
    if not found or current_balance<r.qty then raise exception 'INSUFFICIENT_STOCK:%',r.product_id; end if;
    update public.inventory_balances set quantity=current_balance-r.qty,updated_at=now() where warehouse_id=v.warehouse_id and product_id=r.product_id;
    insert into public.stock_movements(warehouse_id,product_id,movement_type,reference_type,reference_id,quantity_change,balance_after,created_by)
    values(v.warehouse_id,r.product_id,'OUT','outbound_voucher',v.id,-r.qty,current_balance-r.qty,actor);
  end loop;
  update public.sales_order_items si set fulfilled_quantity=si.fulfilled_quantity+x.qty
  from (select sales_order_item_id,sum(actual_quantity) qty from public.outbound_items where voucher_id=v.id and sales_order_item_id is not null group by sales_order_item_id) x
  where si.id=x.sales_order_item_id;
  if v.sales_order_id is not null then
    update public.sales_orders s set status=case
      when not exists(select 1 from public.sales_order_items i where i.sales_order_id=s.id and i.fulfilled_quantity<i.ordered_quantity) then 'fulfilled'::public.sales_order_status
      else 'partially_fulfilled'::public.sales_order_status end,updated_at=now() where s.id=v.sales_order_id;
  end if;
  update public.outbound_vouchers set status='confirmed',confirmed_by=actor,confirmed_at=now(),
    company_snapshot=private.company_snapshot(),customer_snapshot=(select to_jsonb(c) from public.customers c where c.id=v.customer_id),updated_at=now() where id=v.id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(actor,'confirm','outbound_voucher',v.id,jsonb_build_object('sales_order_id',v.sales_order_id));
end $$;

create or replace function public.finalize_invoice(p_invoice_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare inv public.invoices%rowtype; actor uuid:=auth.uid(); calculated numeric(18,2);
begin
  if actor is null or private.current_user_role() not in ('admin','sales_staff','accountant') then raise exception 'UNAUTHORIZED'; end if;
  select * into inv from public.invoices where id=p_invoice_id for update;
  if not found then raise exception 'INVOICE_NOT_FOUND'; end if;
  if inv.status<>'draft' then raise exception 'INVOICE_NOT_DRAFT'; end if;
  if inv.outbound_voucher_id is not null and exists(select 1 from public.invoices i where i.outbound_voucher_id=inv.outbound_voucher_id and i.status='finalized' and i.id<>inv.id) then raise exception 'OUTBOUND_ALREADY_INVOICED'; end if;
  update public.invoice_items ii set product_name_snapshot=coalesce(ii.product_name_snapshot,p.name,ii.description),
    specification_snapshot=coalesce(ii.specification_snapshot,p.packaging_specification),unit_snapshot=coalesce(ii.unit_snapshot,p.unit)
  from public.products p where ii.invoice_id=inv.id and p.id=ii.product_id;
  select coalesce(sum(line_total-discount_amount),0) into calculated from public.invoice_items where invoice_id=inv.id;
  if inv.discount_amount>calculated then raise exception 'INVALID_DISCOUNT'; end if;
  update public.invoices set subtotal=calculated,total_amount=calculated-discount_amount,status='finalized',finalized_at=now(),
    company_snapshot=private.company_snapshot(),customer_snapshot=(select to_jsonb(c) from public.customers c where c.id=inv.customer_id),updated_at=now() where id=inv.id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(actor,'finalize','invoice',inv.id);
end $$;

create or replace view public.sales_order_fulfillment_view with (security_invoker=true) as
select s.id,s.order_code,s.customer_id,s.order_date,s.expected_delivery_date,s.status,s.total_amount,
  coalesce(sum(i.ordered_quantity),0) ordered_quantity,coalesce(sum(i.fulfilled_quantity),0) fulfilled_quantity,
  coalesce(sum(i.ordered_quantity-i.fulfilled_quantity),0) outstanding_quantity
from public.sales_orders s left join public.sales_order_items i on i.sales_order_id=s.id group by s.id;

create or replace view public.customer_debt_view with (security_invoker=true) as
select c.id customer_id,c.code,c.name,coalesce(x.invoiced_amount,0) invoiced_amount,
  coalesce(x.paid_amount,0) paid_amount,coalesce(x.invoiced_amount,0)-coalesce(x.paid_amount,0) outstanding_amount
from public.customers c left join (
  select i.customer_id,sum(i.total_amount) invoiced_amount,
    sum(coalesce((select sum(p.amount) from public.payments p where p.invoice_id=i.id and p.reversed_at is null),0)) paid_amount
  from public.invoices i where i.status='finalized' group by i.customer_id
) x on x.customer_id=c.id;

revoke all on function public.create_sales_order_draft(uuid,date,text,text,numeric,jsonb),public.confirm_sales_order(uuid),
  public.create_inbound_draft_v2(jsonb),public.create_outbound_draft_v2(jsonb) from public,anon;
grant execute on function public.create_sales_order_draft(uuid,date,text,text,numeric,jsonb),public.confirm_sales_order(uuid),
  public.create_inbound_draft_v2(jsonb),public.create_outbound_draft_v2(jsonb) to authenticated;

commit;
