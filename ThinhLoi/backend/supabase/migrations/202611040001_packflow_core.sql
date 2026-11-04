begin;

create extension if not exists pgcrypto;
create type public.app_role as enum ('admin','warehouse_staff','sales_staff','accountant');
create type public.document_status as enum ('draft','confirmed','cancelled');
create type public.invoice_status as enum ('draft','finalized','cancelled');
create type public.payment_status as enum ('unpaid','partial','paid');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (length(trim(full_name)) > 0),
  role public.app_role not null default 'warehouse_staff',
  is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.categories (
  id uuid primary key default gen_random_uuid(), name text not null unique,
  description text, created_at timestamptz not null default now()
);
create table public.products (
  id uuid primary key default gen_random_uuid(), sku text not null unique, name text not null,
  category_id uuid references public.categories(id), dimension_length numeric(12,2),
  dimension_width numeric(12,2), dimension_height numeric(12,2), material text,
  unit text not null, packaging_specification text,
  purchase_price numeric(18,2) not null default 0 check (purchase_price >= 0),
  selling_price numeric(18,2) not null default 0 check (selling_price >= 0),
  minimum_stock numeric(18,3) not null default 0 check (minimum_stock >= 0),
  image_path text, is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.warehouses (
  id uuid primary key default gen_random_uuid(), code text not null unique, name text not null,
  address text, is_active boolean not null default true, created_at timestamptz not null default now()
);
create table public.inventory_balances (
  warehouse_id uuid not null references public.warehouses(id), product_id uuid not null references public.products(id),
  quantity numeric(18,3) not null default 0 check (quantity >= 0), updated_at timestamptz not null default now(),
  primary key (warehouse_id, product_id)
);
create table public.suppliers (
  id uuid primary key default gen_random_uuid(), code text not null unique, name text not null,
  phone text, email text, address text, tax_code text, notes text, created_at timestamptz not null default now()
);
create table public.customers (
  id uuid primary key default gen_random_uuid(), code text not null unique, name text not null,
  phone text, email text, address text, tax_code text, notes text, created_at timestamptz not null default now()
);
create table public.inbound_vouchers (
  id uuid primary key default gen_random_uuid(), voucher_code text not null unique,
  warehouse_id uuid not null references public.warehouses(id), supplier_id uuid not null references public.suppliers(id),
  status public.document_status not null default 'draft', total_amount numeric(18,2) not null default 0 check (total_amount >= 0),
  note text, created_by uuid not null references auth.users(id), confirmed_by uuid references auth.users(id),
  confirmed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.inbound_items (
  id uuid primary key default gen_random_uuid(), voucher_id uuid not null references public.inbound_vouchers(id) on delete cascade,
  product_id uuid not null references public.products(id), quantity numeric(18,3) not null check (quantity > 0),
  unit_price numeric(18,2) not null check (unit_price >= 0), line_total numeric(18,2) generated always as (round(quantity * unit_price, 2)) stored
);
create table public.outbound_vouchers (
  id uuid primary key default gen_random_uuid(), voucher_code text not null unique,
  warehouse_id uuid not null references public.warehouses(id), customer_id uuid not null references public.customers(id),
  status public.document_status not null default 'draft', total_amount numeric(18,2) not null default 0 check (total_amount >= 0),
  discount_amount numeric(18,2) not null default 0 check (discount_amount >= 0), note text,
  created_by uuid not null references auth.users(id), confirmed_by uuid references auth.users(id),
  confirmed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.outbound_items (
  id uuid primary key default gen_random_uuid(), voucher_id uuid not null references public.outbound_vouchers(id) on delete cascade,
  product_id uuid not null references public.products(id), quantity numeric(18,3) not null check (quantity > 0),
  unit_price numeric(18,2) not null check (unit_price >= 0), line_total numeric(18,2) generated always as (round(quantity * unit_price, 2)) stored
);
create table public.stock_movements (
  id uuid primary key default gen_random_uuid(), warehouse_id uuid not null references public.warehouses(id),
  product_id uuid not null references public.products(id), movement_type text not null check (movement_type in ('IN','OUT','REVERSAL')),
  reference_type text not null check (reference_type in ('inbound_voucher','outbound_voucher','reversal')),
  reference_id uuid not null, quantity_change numeric(18,3) not null check (quantity_change <> 0),
  balance_after numeric(18,3) not null check (balance_after >= 0), created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(), unique(reference_type, reference_id, product_id)
);
create table public.invoices (
  id uuid primary key default gen_random_uuid(), invoice_code text not null unique,
  customer_id uuid not null references public.customers(id), outbound_voucher_id uuid references public.outbound_vouchers(id),
  invoice_date date not null default current_date, status public.invoice_status not null default 'draft',
  subtotal numeric(18,2) not null default 0 check (subtotal >= 0), discount_amount numeric(18,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(18,2) not null default 0 check (total_amount >= 0), payment_status public.payment_status not null default 'unpaid',
  note text, created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index one_final_invoice_per_outbound on public.invoices(outbound_voucher_id) where outbound_voucher_id is not null and status = 'finalized';
create table public.invoice_items (
  id uuid primary key default gen_random_uuid(), invoice_id uuid not null references public.invoices(id) on delete cascade,
  product_id uuid references public.products(id), description text not null, quantity numeric(18,3) not null check (quantity > 0),
  unit_price numeric(18,2) not null check (unit_price >= 0), line_total numeric(18,2) generated always as (round(quantity * unit_price, 2)) stored
);
create table public.invoice_attachments (
  id uuid primary key default gen_random_uuid(), invoice_id uuid references public.invoices(id),
  inbound_voucher_id uuid references public.inbound_vouchers(id), storage_path text not null,
  file_name text not null, mime_type text not null, uploaded_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
  check (num_nonnulls(invoice_id, inbound_voucher_id) = 1)
);
create table public.payments (
  id uuid primary key default gen_random_uuid(), invoice_id uuid not null references public.invoices(id),
  amount numeric(18,2) not null check (amount > 0), payment_method text not null,
  payment_date timestamptz not null default now(), reference_number text, note text,
  created_by uuid not null references auth.users(id), created_at timestamptz not null default now()
);
create table public.business_settings (
  id uuid primary key default gen_random_uuid(), business_name text not null, address text, phone text, email text,
  logo_path text, bank_name text, bank_account_number text, bank_account_holder text, updated_at timestamptz not null default now()
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users(id), action text not null,
  entity_type text not null, entity_id uuid, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create index products_category_idx on public.products(category_id);
create index inbound_created_idx on public.inbound_vouchers(created_at desc);
create index outbound_created_idx on public.outbound_vouchers(created_at desc);
create index movements_lookup_idx on public.stock_movements(warehouse_id, product_id, created_at desc);
create index invoices_customer_date_idx on public.invoices(customer_id, invoice_date desc);
create index payments_invoice_idx on public.payments(invoice_id, payment_date);

create schema if not exists private;
create or replace function private.current_user_role() returns public.app_role language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p where p.id = (select auth.uid()) and p.is_active;
$$;
revoke all on function private.current_user_role() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.current_user_role() to authenticated;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.warehouses enable row level security;
alter table public.inventory_balances enable row level security;
alter table public.suppliers enable row level security;
alter table public.customers enable row level security;
alter table public.inbound_vouchers enable row level security;
alter table public.inbound_items enable row level security;
alter table public.outbound_vouchers enable row level security;
alter table public.outbound_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.invoice_attachments enable row level security;
alter table public.payments enable row level security;
alter table public.business_settings enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_read_self on public.profiles for select to authenticated using (id = (select auth.uid()) or private.current_user_role() = 'admin');
create policy authenticated_read_categories on public.categories for select to authenticated using (private.current_user_role() is not null);
create policy category_admin on public.categories for all to authenticated using (private.current_user_role()='admin') with check (private.current_user_role()='admin');
create policy authenticated_read_products on public.products for select to authenticated using (private.current_user_role() is not null);
create policy product_manage on public.products for all to authenticated using (private.current_user_role() in ('admin','warehouse_staff')) with check (private.current_user_role() in ('admin','warehouse_staff'));
create policy authenticated_read_warehouses on public.warehouses for select to authenticated using (private.current_user_role() is not null);
create policy authenticated_read_balances on public.inventory_balances for select to authenticated using (private.current_user_role() is not null);
create policy authenticated_read_suppliers on public.suppliers for select to authenticated using (private.current_user_role() is not null);
create policy supplier_manage on public.suppliers for all to authenticated using (private.current_user_role() in ('admin','warehouse_staff')) with check (private.current_user_role() in ('admin','warehouse_staff'));
create policy authenticated_read_customers on public.customers for select to authenticated using (private.current_user_role() is not null);
create policy customer_manage on public.customers for all to authenticated using (private.current_user_role() in ('admin','sales_staff')) with check (private.current_user_role() in ('admin','sales_staff'));
create policy authenticated_read_inbound on public.inbound_vouchers for select to authenticated using (private.current_user_role() is not null);
create policy inbound_drafts on public.inbound_vouchers for all to authenticated using (status='draft' and private.current_user_role() in ('admin','warehouse_staff')) with check (status='draft' and created_by=(select auth.uid()) and private.current_user_role() in ('admin','warehouse_staff'));
create policy authenticated_read_inbound_items on public.inbound_items for select to authenticated using (private.current_user_role() is not null);
create policy inbound_item_drafts on public.inbound_items for all to authenticated using (exists(select 1 from public.inbound_vouchers v where v.id=voucher_id and v.status='draft')) with check (exists(select 1 from public.inbound_vouchers v where v.id=voucher_id and v.status='draft' and v.created_by=(select auth.uid())));
create policy authenticated_read_outbound on public.outbound_vouchers for select to authenticated using (private.current_user_role() is not null);
create policy outbound_drafts on public.outbound_vouchers for all to authenticated using (status='draft' and private.current_user_role() in ('admin','warehouse_staff','sales_staff')) with check (status='draft' and created_by=(select auth.uid()) and private.current_user_role() in ('admin','warehouse_staff','sales_staff'));
create policy authenticated_read_outbound_items on public.outbound_items for select to authenticated using (private.current_user_role() is not null);
create policy outbound_item_drafts on public.outbound_items for all to authenticated using (exists(select 1 from public.outbound_vouchers v where v.id=voucher_id and v.status='draft')) with check (exists(select 1 from public.outbound_vouchers v where v.id=voucher_id and v.status='draft' and v.created_by=(select auth.uid())));
create policy authenticated_read_movements on public.stock_movements for select to authenticated using (private.current_user_role() is not null);
create policy authenticated_read_invoices on public.invoices for select to authenticated using (private.current_user_role() is not null);
create policy invoice_drafts on public.invoices for all to authenticated using (status='draft' and private.current_user_role() in ('admin','sales_staff','accountant')) with check (status='draft' and created_by=(select auth.uid()));
create policy authenticated_read_invoice_items on public.invoice_items for select to authenticated using (private.current_user_role() is not null);
create policy invoice_item_drafts on public.invoice_items for all to authenticated using (exists(select 1 from public.invoices i where i.id=invoice_id and i.status='draft')) with check (exists(select 1 from public.invoices i where i.id=invoice_id and i.status='draft' and i.created_by=(select auth.uid())));
create policy authenticated_read_attachments on public.invoice_attachments for select to authenticated using (private.current_user_role() is not null);
create policy attachment_write on public.invoice_attachments for insert to authenticated with check (uploaded_by=(select auth.uid()) and private.current_user_role() is not null);
create policy authenticated_read_payments on public.payments for select to authenticated using (private.current_user_role() is not null);
create policy settings_read on public.business_settings for select to authenticated using (private.current_user_role() is not null);
create policy settings_admin on public.business_settings for all to authenticated using (private.current_user_role()='admin') with check (private.current_user_role()='admin');
create policy audit_admin_read on public.audit_logs for select to authenticated using (private.current_user_role()='admin');

create sequence public.document_number_seq start 1000;
create or replace function public.next_document_code(p_prefix text) returns text language plpgsql security definer set search_path='' as $$
begin return p_prefix || '-' || to_char(current_date,'YYYY') || '-' || lpad(nextval('public.document_number_seq')::text,6,'0'); end; $$;
revoke all on function public.next_document_code(text) from public,anon,authenticated;

create or replace function public.confirm_inbound_voucher(p_voucher_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.inbound_vouchers%rowtype; r record; new_balance numeric(18,3); actor uuid := auth.uid();
begin
  if actor is null or private.current_user_role() not in ('admin','warehouse_staff') then raise exception 'UNAUTHORIZED'; end if;
  select * into v from public.inbound_vouchers where id=p_voucher_id for update;
  if not found then raise exception 'VOUCHER_NOT_FOUND'; end if;
  if v.status <> 'draft' then raise exception 'ALREADY_CONFIRMED'; end if;
  if not exists(select 1 from public.inbound_items where voucher_id=v.id) then raise exception 'EMPTY_VOUCHER'; end if;
  update public.inbound_vouchers set total_amount=(select coalesce(sum(line_total),0) from public.inbound_items where voucher_id=v.id) where id=v.id;
  for r in select product_id,sum(quantity) qty from public.inbound_items where voucher_id=v.id group by product_id order by product_id loop
    insert into public.inventory_balances(warehouse_id,product_id,quantity) values(v.warehouse_id,r.product_id,0) on conflict do nothing;
    select quantity into new_balance from public.inventory_balances where warehouse_id=v.warehouse_id and product_id=r.product_id for update;
    new_balance := new_balance + r.qty;
    update public.inventory_balances set quantity=new_balance,updated_at=now() where warehouse_id=v.warehouse_id and product_id=r.product_id;
    insert into public.stock_movements(warehouse_id,product_id,movement_type,reference_type,reference_id,quantity_change,balance_after,created_by) values(v.warehouse_id,r.product_id,'IN','inbound_voucher',v.id,r.qty,new_balance,actor);
  end loop;
  update public.inbound_vouchers set status='confirmed',confirmed_by=actor,confirmed_at=now(),updated_at=now() where id=v.id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(actor,'confirm','inbound_voucher',v.id);
end; $$;

create or replace function public.confirm_outbound_voucher(p_voucher_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.outbound_vouchers%rowtype; r record; current_balance numeric(18,3); actor uuid := auth.uid(); calculated numeric(18,2);
begin
  if actor is null or private.current_user_role() not in ('admin','warehouse_staff') then raise exception 'UNAUTHORIZED'; end if;
  select * into v from public.outbound_vouchers where id=p_voucher_id for update;
  if not found then raise exception 'VOUCHER_NOT_FOUND'; end if;
  if v.status <> 'draft' then raise exception 'ALREADY_CONFIRMED'; end if;
  if not exists(select 1 from public.outbound_items where voucher_id=v.id) then raise exception 'EMPTY_VOUCHER'; end if;
  select coalesce(sum(line_total),0) into calculated from public.outbound_items where voucher_id=v.id;
  if v.discount_amount > calculated then raise exception 'INVALID_DISCOUNT'; end if;
  for r in select product_id,sum(quantity) qty from public.outbound_items where voucher_id=v.id group by product_id order by product_id loop
    select quantity into current_balance from public.inventory_balances where warehouse_id=v.warehouse_id and product_id=r.product_id for update;
    if not found or current_balance < r.qty then raise exception 'INSUFFICIENT_STOCK:%',r.product_id; end if;
    update public.inventory_balances set quantity=current_balance-r.qty,updated_at=now() where warehouse_id=v.warehouse_id and product_id=r.product_id;
    insert into public.stock_movements(warehouse_id,product_id,movement_type,reference_type,reference_id,quantity_change,balance_after,created_by) values(v.warehouse_id,r.product_id,'OUT','outbound_voucher',v.id,-r.qty,current_balance-r.qty,actor);
  end loop;
  update public.outbound_vouchers set total_amount=calculated-discount_amount,status='confirmed',confirmed_by=actor,confirmed_at=now(),updated_at=now() where id=v.id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(actor,'confirm','outbound_voucher',v.id);
end; $$;

revoke all on function public.confirm_inbound_voucher(uuid) from public,anon;
revoke all on function public.confirm_outbound_voucher(uuid) from public,anon;
grant execute on function public.confirm_inbound_voucher(uuid), public.confirm_outbound_voucher(uuid) to authenticated;

create view public.product_stock_view with (security_invoker=true) as
select p.*,c.name category_name,coalesce(sum(b.quantity),0) stock_quantity from public.products p left join public.categories c on c.id=p.category_id left join public.inventory_balances b on b.product_id=p.id group by p.id,c.name;
create view public.inventory_balance_view with (security_invoker=true) as
select b.*,p.sku,p.name product_name,p.unit,p.minimum_stock,w.name warehouse_name from public.inventory_balances b join public.products p on p.id=b.product_id join public.warehouses w on w.id=b.warehouse_id;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
('product-images','product-images',false,5242880,array['image/jpeg','image/png','image/webp']),
('invoice-documents','invoice-documents',false,10485760,array['application/pdf','image/jpeg','image/png']),
('purchase-documents','purchase-documents',false,10485760,array['application/pdf','image/jpeg','image/png']),
('company-assets','company-assets',false,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy private_storage_read on storage.objects for select to authenticated using (bucket_id in ('product-images','invoice-documents','purchase-documents','company-assets') and private.current_user_role() is not null);
create policy private_storage_write on storage.objects for insert to authenticated with check (bucket_id in ('product-images','invoice-documents','purchase-documents','company-assets') and private.current_user_role() in ('admin','warehouse_staff','sales_staff','accountant') and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy private_storage_update on storage.objects for update to authenticated using ((storage.foldername(name))[1]=(select auth.uid())::text or private.current_user_role()='admin') with check ((storage.foldername(name))[1]=(select auth.uid())::text or private.current_user_role()='admin');
create policy private_storage_delete on storage.objects for delete to authenticated using ((storage.foldername(name))[1]=(select auth.uid())::text or private.current_user_role()='admin');

commit;
