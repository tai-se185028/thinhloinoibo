# PackFlow – Quản lý kho bao bì

Google OAuth và liên kết tài khoản nhân viên: xem [hướng dẫn cấu hình](../backend/GOOGLE_OAUTH.md). Web và Android đã có luồng OAuth; Google provider còn cần được bật/cấu hình trên Supabase trước khi đăng nhập thực tế.

## Đăng nhập nhân viên

Ứng dụng hỗ trợ username, số điện thoại Việt Nam và Google. Chạy web bằng script để `.env.local` được truyền qua `--dart-define`:

```powershell
cd frontend
.\scripts\run_web.ps1
```

`.env.local` chỉ nằm local và đã được Git ignore. Dùng `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` (các alias `NEXT_PUBLIC_` hiện tại cũng được hỗ trợ). Sau khi sửa env, phải dừng Flutter và chạy lại script; hot reload không nạp lại compile-time define.

Supabase Auth redirect URLs:

- Web: `http://localhost:3000`
- Mobile: `vn.packflow.app://login-callback/`

Ứng dụng Flutter nội bộ dùng Supabase Auth, PostgreSQL, RLS, RPC và Storage. UI hiện có được giữ nguyên; dữ liệu production đi qua repository Supabase, còn `AppStore.seeded()` chỉ dành cho test hoặc demo không cấu hình.

## Chạy ứng dụng

### Đường dẫn tác vụ

| Tác vụ | Path (sau `http://localhost:3000`) |
| --- | --- |
| Đăng nhập | `/login` |
| Tổng quan | `/dashboard` |
| Sản phẩm | `/products` |
| Thêm / xem / sửa sản phẩm | `/products/new`, `/products/:id`, `/products/:id/edit` |
| Tồn kho | `/inventory` |
| Nhập kho | `/inbound`, `/inbound/new`, `/inbound/:id` |
| Xuất kho | `/outbound`, `/outbound/new`, `/outbound/:id` |
| Hóa đơn | `/invoices`, `/invoices/new`, `/invoices/:id` |
| Đối tác | `/partners` |
| Báo cáo | `/reports` |
| Cài đặt / liên kết Google | `/settings` |

`:id` là ID dữ liệu thực tế. `/` tự chuyển tới đăng nhập hoặc tổng quan.
URL chi tiết có thể mở trực tiếp; chưa đăng nhập thì chuyển tới `/login`, sau khi xác thực sẽ quay về tác vụ đã yêu cầu. Khi tải lại, dữ liệu được nạp trước khi tìm ID. URL/ID không tồn tại có màn hình thông báo riêng.

Flutter Web dùng path URL (không có `/#/`). Dev server Flutter hỗ trợ đường dẫn này. Khi deploy hosting production, cấu hình SPA fallback: mọi URL không trỏ tới file tĩnh phải trả `index.html` (Nginx: `try_files $uri $uri/ /index.html;`).
OAuth Google luôn quay về `${origin}/`; giữ callback root trong Supabase allow-list, không cần thêm từng tác vụ.

### Run/Debug trong VS Code

Mở thư mục `D:\ThinhLoi` hoặc `D:\ThinhLoi\frontend`, chọn cấu hình
`PackFlow Web (local env, port 3000)` trong Run and Debug rồi nhấn F5.
Cấu hình này đọc `frontend/.env.local` khi biên dịch và dùng cổng 3000.
Dừng phiên chạy cũ trước khi chạy lại, kể cả phiên ở cổng ngẫu nhiên.
File env không được thêm vào assets hay source code.

Nếu chạy trực tiếp từ thư mục `frontend`, dùng:

```powershell
flutter run -d chrome --web-port=3000 --dart-define-from-file=.env.local
```

### 1. Yêu cầu

- Flutter stable 3.35 trở lên.
- Android Studio/Android SDK nếu chạy Android.
- Chrome nếu chạy Flutter Web.
- Supabase CLI và Docker chỉ cần khi chạy database local hoặc deploy migration.

Kiểm tra môi trường:

```powershell
flutter doctor
```

### 2. Cài dependencies

```powershell
cd D:\ThinhLoi\frontend
flutter pub get
```

### 3. Cấu hình biến môi trường

Script chạy đọc cấu hình từ biến PowerShell hoặc `frontend/.env.local` (được Git bỏ qua). Biến PowerShell có độ ưu tiên cao hơn. Có thể tạo file local từ `.env.example` rồi điền:

```dotenv
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key
```

Tên `NEXT_PUBLIC_SUPABASE_URL` và `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` trong file local cũng được hỗ trợ và chuyển sang tên Flutter. File này chỉ được script đọc trên máy, không nằm trong Flutter assets.

Hoặc thiết lập biến cho phiên PowerShell hiện tại:

```powershell
$env:SUPABASE_URL = "https://your-project-ref.supabase.co"
$env:SUPABASE_PUBLISHABLE_KEY = "sb_publishable_your_key"
```

Các biến mất khi đóng cửa sổ PowerShell. Scripts trong `scripts/` truyền chúng vào Flutter bằng `--dart-define`. Chỉ dùng publishable key; tuyệt đối không đưa `service_role`, database password hoặc access token vào frontend.

### 4. Chạy Flutter Web cổng 3000

```powershell
.\scripts\run_web.ps1
```

Mở <http://localhost:3000>.

Nếu đang chạy ứng dụng bằng `flutter run` trực tiếp và thấy “Chưa cấu hình Supabase”, dừng phiên cũ bằng `Ctrl+C`, rồi chạy lại script trên. Thay đổi `dart-define` cần khởi động lại ứng dụng.

Kiểm tra cấu hình mà không in key hoặc khởi chạy Flutter:

```powershell
.\scripts\run_web.ps1 -CheckConfiguration
```

Chạy bằng web-server thay vì tự mở Chrome:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000 `
  "--dart-define=SUPABASE_URL=$env:SUPABASE_URL" `
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY"
```

### 5. Chạy Android

Kiểm tra thiết bị:

```powershell
flutter devices
.\scripts\run_android.ps1
```

### 6. Ghi đè env cho CI/release

```powershell
flutter run -d chrome --web-port 3000 `
  --dart-define=SUPABASE_URL=https://mmukxhbucfectvhfbame.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

### 7. Build

```powershell
flutter build web
flutter build apk --release
```

Kết quả nằm tại `build/web` và `build/app/outputs/flutter-apk/app-release.apk`.

## Database và migration

Migration backend nằm trong `../backend/supabase/migrations`, tạo schema, constraint, index, RLS, private Storage buckets và các RPC:

- `create_inbound_draft`, `confirm_inbound_voucher`
- `create_outbound_draft`, `confirm_outbound_voucher`
- `create_invoice_draft`, `finalize_invoice`
- `record_invoice_payment`, `dashboard_summary`

Xác nhận nhập/xuất khóa voucher và tồn kho theo thứ tự product UUID. Tiền và tồn kho được tính lại tại PostgreSQL. Flutter không được ghi trực tiếp `inventory_balances`, `stock_movements` hoặc `payments`.

Máy hiện tại chưa có Supabase CLI/Docker nên migration chưa được đẩy lên remote. Sau khi cài CLI:

```powershell
cd D:\ThinhLoi\backend
supabase login
supabase link --project-ref mmukxhbucfectvhfbame
supabase migration list --remote
supabase db push --dry-run --remote
supabase db push --remote
```

Không chạy `db reset --remote` trên project có dữ liệu. Nếu remote đã có schema, chạy `supabase db pull --remote` và đối chiếu trước khi push.

## Tạo admin đầu tiên

1. Tắt public sign-up trong Supabase Auth.
2. Tạo user qua Dashboard → Authentication → Users.
3. Chạy trong SQL Editor:

```sql
insert into public.profiles(id, full_name, role, is_active)
values ('<AUTH_USER_UUID>', 'Quản trị hệ thống', 'admin', true);
```

Client không có policy tự gán hoặc thay đổi role.

## Storage

Các bucket `product-images`, `invoice-documents`, `purchase-documents`, `company-assets` đều private. Đường dẫn upload phải bắt đầu bằng UUID người dùng, ví dụ `<auth.uid()>/products/<uuid>.jpg`. Client dùng signed URL 5 phút.

## Kiểm tra

```powershell
flutter analyze
flutter test
```

Khi có Supabase local và Docker:

```powershell
supabase start
supabase db reset
psql <connection-string-local> -f supabase/tests/inventory_workflows.sql
```

## Cấu trúc tích hợp

- `.env.example`: chỉ là mẫu, không chứa key thật.
- `scripts/run_web.ps1`, `scripts/run_android.ps1`: đọc biến PowerShell hoặc `.env.local` qua helper `supabase_config.ps1`, rồi truyền `dart-define`.
- `lib/core/supabase_config.dart`: đọc và kiểm tra cấu hình compile-time từ `dart-define`.
- `lib/data/repositories/supabase_repositories.dart`: repository typed và lỗi tiếng Việt.
- `lib/data/app_store.dart`: shared state, remote refresh và mock mode cho test.
- `../backend/supabase/migrations`: schema, RLS và giao dịch.
- `../backend/supabase/seed.sql`: seed development không chứa user/mật khẩu.

## Việc cần xác nhận trên remote

- Chưa chạy integration test remote vì không có Supabase CLI/Docker và quyền quản trị database.
- Phải dry-run/đối chiếu migration nếu remote đã có bảng.
- UI chuyên dụng cho category, payment và file picker cần mở rộng; repository/schema đã sẵn sàng.
- Cần thêm font Unicode có giấy phép vào assets để PDF tiếng Việt hiển thị ổn định trên mọi thiết bị.


powershell -ExecutionPolicy Bypass -File .\scripts\run_web.ps1
