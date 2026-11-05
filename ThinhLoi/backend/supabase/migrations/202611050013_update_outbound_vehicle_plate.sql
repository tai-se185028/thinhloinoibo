begin;

-- 1. Thêm cột vehicle_plate vào bảng invoices và outbound_vouchers (nếu chưa có)
alter table public.invoices
  add column if not exists vehicle_plate text;

alter table public.outbound_vouchers
  add column if not exists vehicle_plate text;

-- 2. Cho phép cập nhật trên outbound_vouchers cho MỌI status (kể cả confirmed)
drop policy if exists outbound_update_vehicle_plate on public.outbound_vouchers;
create policy outbound_update_vehicle_plate on public.outbound_vouchers
  for update to authenticated
  using (true)
  with check (true);

-- 3. Cho phép cập nhật trên invoices cho MỌI status (kể cả finalized, paid)
drop policy if exists invoices_update_vehicle_plate on public.invoices;
create policy invoices_update_vehicle_plate on public.invoices
  for update to authenticated
  using (true)
  with check (true);

-- 4. RPC function update_outbound_vehicle_plate (Security Definer - vượt qua mọi rào cản RLS, hỗ trợ tất cả các status)
create or replace function public.update_outbound_vehicle_plate(
  p_voucher_id uuid,
  p_vehicle_plate text,
  p_invoice_id uuid default null
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
  v_plate text;
begin
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

-- 5. Cho phép xóa hóa đơn và chi tiết hóa đơn
drop policy if exists invoices_delete on public.invoices;
create policy invoices_delete on public.invoices
  for delete to authenticated
  using (true);

drop policy if exists invoice_items_delete on public.invoice_items;
create policy invoice_items_delete on public.invoice_items
  for delete to authenticated
  using (true);

-- 6. RPC function delete_invoice (Security Definer - xóa sạch hóa đơn bất kể status)
create or replace function public.delete_invoice(
  p_invoice_id uuid
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
begin
  delete from public.invoice_items where invoice_id = p_invoice_id;
  delete from public.invoices where id = p_invoice_id;
  return jsonb_build_object('success', true, 'invoice_id', p_invoice_id);
end $$;

revoke all on function public.delete_invoice(uuid) from public, anon;
grant execute on function public.delete_invoice(uuid) to authenticated;

commit;
