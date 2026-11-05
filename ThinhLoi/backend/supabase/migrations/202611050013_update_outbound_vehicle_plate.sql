begin;

-- 1. Thêm cột vehicle_plate vào bảng invoices (nếu chưa có)
alter table public.invoices
  add column if not exists vehicle_plate text;

-- 2. Thêm cột vehicle_plate vào bảng outbound_vouchers (nếu chưa có)
alter table public.outbound_vouchers
  add column if not exists vehicle_plate text;

-- 3. Cho phép cập nhật vehicle_plate trên outbound_vouchers cho MỌI status (kể cả confirmed)
drop policy if exists outbound_update_vehicle_plate on public.outbound_vouchers;
create policy outbound_update_vehicle_plate on public.outbound_vouchers
  for update to authenticated
  using (
    private.current_user_role() in ('admin','warehouse_staff','sales_staff','accountant')
  )
  with check (
    private.current_user_role() in ('admin','warehouse_staff','sales_staff','accountant')
  );

-- 4. Cho phép cập nhật vehicle_plate trên invoices cho MỌI status (kể cả finalized, paid)
drop policy if exists invoices_update_vehicle_plate on public.invoices;
create policy invoices_update_vehicle_plate on public.invoices
  for update to authenticated
  using (
    private.current_user_role() in ('admin','warehouse_staff','sales_staff','accountant')
  )
  with check (
    private.current_user_role() in ('admin','warehouse_staff','sales_staff','accountant')
  );

-- 5. RPC function update_outbound_vehicle_plate (Security Definer - vượt qua mọi rào cản RLS, hỗ trợ tất cả các status)
create or replace function public.update_outbound_vehicle_plate(
  p_voucher_id uuid,
  p_vehicle_plate text,
  p_invoice_id uuid default null
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid := auth.uid();
  v_plate text;
begin
  if actor is null or private.current_user_role() not in ('admin','warehouse_staff','sales_staff','accountant') then
    raise exception 'UNAUTHORIZED';
  end if;

  v_plate := nullif(trim(p_vehicle_plate), '');

  -- Cập nhật phiếu xuất kho nếu có voucher_id
  if p_voucher_id is not null then
    update public.outbound_vouchers
    set vehicle_plate = v_plate,
        updated_at = now()
    where id = p_voucher_id;

    -- Đồng bộ luôn sang hóa đơn liên kết nếu có
    update public.invoices
    set vehicle_plate = v_plate,
        updated_at = now()
    where outbound_voucher_id = p_voucher_id;
  end if;

  -- Cập nhật hóa đơn nếu có invoice_id
  if p_invoice_id is not null then
    update public.invoices
    set vehicle_plate = v_plate,
        updated_at = now()
    where id = p_invoice_id;

    -- Nếu hóa đơn có liên kết phiếu xuất kho thì đồng bộ luôn sang phiếu xuất kho
    update public.outbound_vouchers
    set vehicle_plate = v_plate,
        updated_at = now()
    where id = (select outbound_voucher_id from public.invoices where id = p_invoice_id);
  end if;

  return jsonb_build_object('success', true, 'vehicle_plate', v_plate);
end $$;

revoke all on function public.update_outbound_vehicle_plate(uuid, text, uuid) from public, anon;
grant execute on function public.update_outbound_vehicle_plate(uuid, text, uuid) to authenticated;

commit;
