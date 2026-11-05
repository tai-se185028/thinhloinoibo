begin;

alter table public.outbound_items
  add column if not exists manual_code text;

do $$ begin
  alter table public.outbound_items
    add constraint outbound_items_manual_code_length_check
    check (manual_code is null or char_length(trim(manual_code)) <= 50);
exception when duplicate_object then null; end $$;

commit;
