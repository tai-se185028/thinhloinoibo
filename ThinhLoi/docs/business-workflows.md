# Quy trình nghiệp vụ PackFlow

## Nguyên tắc

- Đơn bán hàng ghi nhận nhu cầu; không làm thay đổi tồn kho.
- Phiếu nháp không làm thay đổi tồn kho.
- Chỉ RPC xác nhận nhập/xuất mới khóa dòng tồn kho và tạo `stock_movements`.
- Số lượng yêu cầu và số lượng thực nhận/thực xuất được lưu riêng.
- Phiếu xuất liên kết đơn hàng cập nhật `fulfilled_quantity`; một đơn có thể xuất nhiều lần.
- Hóa đơn nội bộ ghi nhận nghĩa vụ tài chính, không thay đổi tồn kho.
- Thanh toán chỉ áp dụng cho hóa đơn đã phát hành và không được vượt dư nợ.
- Khi xác nhận/phát hành, thông tin công ty, đối tác và sản phẩm được đóng băng bằng snapshot.

## Trạng thái

- Đơn bán hàng: `draft -> confirmed -> partially_fulfilled -> fulfilled`; có thể `cancelled` khi chưa hoàn tất.
- Phiếu kho: `draft -> confirmed`; bản nháp không sinh chuyển động kho.
- Hóa đơn: `draft -> finalized`; trạng thái thanh toán độc lập `unpaid/partial/paid`.

## Phân quyền

- Quản trị: cấu hình công ty và toàn bộ dữ liệu.
- Kho: sản phẩm, nhà cung cấp, nhập/xuất và tồn kho.
- Bán hàng: khách hàng, đơn bán hàng, phiếu xuất nháp, hóa đơn nháp.
- Kế toán: phát hành hóa đơn và thanh toán.

