begin;

alter table public.outbound_vouchers
  add column if not exists vehicle_plate text;

do $$ begin
  alter table public.outbound_vouchers
    add constraint outbound_vouchers_vehicle_plate_length_check
    check (vehicle_plate is null or char_length(trim(vehicle_plate)) between 4 and 20);
exception when duplicate_object then null; end $$;

commit;
