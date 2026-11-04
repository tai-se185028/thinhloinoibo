# Mẫu chứng từ

## Phiếu xuất kho

- A4 dọc, đen trắng, lề in 28–32 pt.
- Tiêu đề `PHIẾU XUẤT KHO`, số phiếu và ngày chứng từ.
- Khối công ty và người nhận lấy từ dữ liệu đã lưu/snapshot.
- Bảng gồm STT, mô tả/quy cách, SKU, đơn vị, số lượng yêu cầu, thực xuất, đơn giá, thành tiền.
- `MultiPage` tự ngắt trang và lặp header; font Noto Sans hỗ trợ tiếng Việt.
- Ký nhận: Người nhận hàng, Người lập phiếu, Thủ kho, Người duyệt.

## Hóa đơn nội bộ

Tiêu đề phải ghi rõ `HÓA ĐƠN BÁN HÀNG (NỘI BỘ)` và không được mô tả là hóa đơn thuế điện tử. Giá, tên hàng, đơn vị và thông tin đối tác của bản đã phát hành phải lấy từ snapshot.

## Lưu trữ

Tệp nằm trong bucket riêng tư. `business_documents` lưu loại, mã, ngày, đường dẫn, MIME, phiên bản và người tạo. Không sử dụng URL công khai lâu dài; chỉ cấp signed URL ngắn hạn.

