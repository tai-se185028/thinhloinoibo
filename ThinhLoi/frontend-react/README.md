# Thịnh Lợi React

Ứng dụng web React dùng chung Supabase với frontend Flutter.

```powershell
Copy-Item .env.example .env.local
npm install
npm run dev
```

Điền `VITE_SUPABASE_URL` và `VITE_SUPABASE_PUBLISHABLE_KEY` trong `.env.local`.

Gửi email hóa đơn dùng Vercel Node Function `api/send-invoice-email.js`.
Trên Vercel chọn Root Directory trỏ tới thư mục `frontend-react` (ví dụ `ThinhLoi/frontend-react` nếu repo có thư mục bao ngoài).
Deploy toàn bộ source của thư mục này, gồm `api/`; upload riêng `dist/` sẽ không có API gửi mail.
Đặt `GMAIL_USER`, `GMAIL_APP_PASSWORD`, `VITE_SUPABASE_URL` và `VITE_SUPABASE_PUBLISHABLE_KEY` trong Environment Variables, rồi Redeploy để áp dụng.
Chạy local bằng `npm run dev` cũng có route gửi email. Không đặt mật khẩu Gmail vào biến có tiền tố `VITE_`.

Chức năng: đăng nhập email/Google, dashboard, sản phẩm và nhập thêm, tồn kho, đơn bán hàng, phiếu xuất, hóa đơn/thanh toán, đối tác, báo cáo và cấu hình doanh nghiệp.
