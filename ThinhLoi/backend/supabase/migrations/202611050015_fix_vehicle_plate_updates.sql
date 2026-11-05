begin;

-- The earlier migration may already have run in production. Recreate the RPC in
-- a new migration so plate changes work for locked/confirmed documents too.
-- Keep the operation behind a narrow security-definer function: granting a
-- general UPDATE policy would also allow callers to alter accounting fields.
alter table public.invoices
  add column if not exists vehicle_plate text;

alter table public.outbound_vouchers
  add column if not exists vehicle_plate text;

drop policy if exists outbound_update_vehicle_plate on public.outbound_vouchers;
drop policy if exists invoices_update_vehicle_plate on public.invoices;

create or replace function public.update_outbound_vehicle_plate(
  p_voucher_id uuid,
  p_vehicle_plate text,
  p_invoice_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  v_plate text := nullif(trim(p_vehicle_plate), '');
  v_voucher_id uuid := p_voucher_id;
  v_invoice_id uuid := p_invoice_id;
begin
  if actor is null
     or private.current_user_role() not in (
       'admin', 'warehouse_staff', 'sales_staff', 'accountant'
     ) then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  if v_voucher_id is null and v_invoice_id is null then
    raise exception 'DOCUMENT_REQUIRED' using errcode = '22023';
  end if;

  if v_plate is not null and char_length(v_plate) not between 4 and 20 then
    raise exception 'INVALID_VEHICLE_PLATE' using errcode = '22023';
  end if;

  -- Resolve either side of the relationship first so an update from an invoice
  -- and an update from a voucher produce the same result.
  if v_invoice_id is not null then
    select i.outbound_voucher_id
      into v_voucher_id
      from public.invoices i
     where i.id = v_invoice_id;

    if not found then
      raise exception 'INVOICE_NOT_FOUND' using errcode = 'P0002';
    end if;
  elsif v_voucher_id is not null then
    if not exists (
      select 1 from public.outbound_vouchers v where v.id = v_voucher_id
    ) then
      raise exception 'OUTBOUND_VOUCHER_NOT_FOUND' using errcode = 'P0002';
    end if;
  end if;

  if v_voucher_id is not null then
    update public.outbound_vouchers
       set vehicle_plate = v_plate,
           updated_at = now()
     where id = v_voucher_id;

    update public.invoices
       set vehicle_plate = v_plate,
           updated_at = now()
     where outbound_voucher_id = v_voucher_id;
  end if;

  -- Standalone invoices do not have a voucher to update.
  if v_invoice_id is not null then
    update public.invoices
       set vehicle_plate = v_plate,
           updated_at = now()
     where id = v_invoice_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'vehicle_plate', v_plate,
    'voucher_id', v_voucher_id,
    'invoice_id', v_invoice_id
  );
end
$$;

revoke all on function public.update_outbound_vehicle_plate(uuid, text, uuid)
  from public, anon;
grant execute on function public.update_outbound_vehicle_plate(uuid, text, uuid)
  to authenticated;

commit;
