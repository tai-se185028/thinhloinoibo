# Kết quả kiểm thử logic nghiệp vụ

Ngày cập nhật: 04/11/2026.

## Kiểm thử tự động đã chạy

- `flutter analyze`: đạt, không có issue.
- `flutter test`: đạt 22/22 test.
- `flutter build web --release`: đạt.
- `npx supabase db push --remote --dry-run`: đạt, chỉ phát hiện migration `202611040006_erp_workflows.sql`.
- PostgreSQL rollback-only: `backend/supabase/tests/erp_workflows.sql`.
- RLS người dùng Google: `backend/supabase/tests/google_employee_access.sql`.

Hai SQL test rollback-only chưa được thực thi vì máy hiện không có Docker/Podman. Migration production chưa được áp dụng: Supabase CLI yêu cầu xác nhận riêng trước khi chạy với `--yes` và xác nhận không có thay đổi nào được thực hiện.

## Ma trận kỳ vọng

| Kịch bản | Bảo vệ |
|---|---|
| Nhập 2.000 | RPC xác nhận tăng balance và ghi movement một lần |
| Đặt 1.200, xuất 1.030 | actual quantity trừ kho; đơn còn 170 |
| Xuất tiếp 170 | tổng fulfilled đạt ordered; đơn `fulfilled` |
| Lập hóa đơn | không ghi stock movement |
| Thanh toán một phần | tổng payment quyết định `partial` và dư nợ |
| Đổi giá/địa chỉ | snapshot của chứng từ đã chốt không đổi |
| Xuất quá tồn/đơn | RPC rollback toàn bộ |
| Xác nhận hai lần | trạng thái và unique movement từ chối lần hai |
| Hai người cùng xuất | khóa balance `FOR UPDATE` ngăn oversell |
| Người chưa cấp quyền | restrictive RLS và kiểm tra role trong RPC từ chối |

Không chạy kịch bản ghi dữ liệu lên production. Kết quả thực thi cụ thể chỉ được đánh dấu đạt sau khi lệnh kiểm thử hoàn tất trong môi trường local/disposable.

