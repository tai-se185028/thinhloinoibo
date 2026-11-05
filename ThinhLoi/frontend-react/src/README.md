# Cấu trúc mã nguồn

- `app/`: khởi tạo ứng dụng, router, layout và điều phối các màn hình.
- `components/ui/`: các component giao diện dùng chung từ shadcn/ui.
- `config/`: hằng số và cấu hình hiển thị dùng toàn ứng dụng.
- `features/`: mã theo từng nghiệp vụ; tài liệu/PDF nằm trong `features/documents/`.
- `lib/`: kết nối hạ tầng và hàm tiện ích thuần, không chứa nghiệp vụ màn hình.
- `services/`: thao tác nghiệp vụ với backend/Supabase.

`App.jsx` chỉ là entry point. Không đặt thêm màn hình hoặc nghiệp vụ trực tiếp vào file này.
