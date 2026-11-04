# Quan hệ dữ liệu

```text
business_settings ──snapshot──> sales_orders / vouchers / invoices
customers ──< sales_orders ──< sales_order_items >── products
customers ──< outbound_vouchers ──< outbound_items >── products
suppliers ──< inbound_vouchers ──< inbound_items >── products
warehouses ──< inventory_balances >── products
warehouses ──< stock_movements >── products
sales_order_items ──< outbound_items
outbound_vouchers ──< invoices ──< invoice_items
invoices ──< payments
business_documents ──(document_type, reference_id)──> nghiệp vụ nguồn
```

`inventory_balances` là số dư hiện tại theo kho/sản phẩm. `stock_movements` là sổ bất biến có khóa duy nhất theo chứng từ và sản phẩm. Các thao tác vật lý chạy trong RPC có khóa `FOR UPDATE` để chống xuất âm khi đồng thời.

Migration mở rộng: `backend/supabase/migrations/202611040006_erp_workflows.sql`. Migration chỉ thêm bảng/cột/index/RPC/view; không xóa hoặc đổi ID dữ liệu hiện hữu.

