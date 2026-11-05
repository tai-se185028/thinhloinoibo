begin;

-- Xóa sạch chi tiết và hóa đơn HDNB-2026-001023
delete from public.invoice_items
where invoice_id in (select id from public.invoices where invoice_code = 'HDNB-2026-001023');

delete from public.invoices
where invoice_code = 'HDNB-2026-001023';

commit;

