# Google OAuth cho PackFlow

## Trạng thái và phạm vi

Đã triển khai OAuth PKCE bằng `supabase_flutter` (lockfile: 2.18.3), nút Google, liên kết identity, kiểm tra nhân viên và RLS/RPC. Project hiện hỗ trợ Web và Android; chưa có thư mục iOS. Không thêm nền tảng iOS vào project này.

Kiểm tra endpoint Auth settings ngày 04/11/2026 cho thấy `external.google = false`. Chưa kiểm thử đăng nhập Google end-to-end, callback Android trên thiết bị, hoặc origin production. Cần chủ project cấu hình Google Cloud và Supabase trước khi nghiệm thu thực tế.

## Hai callback khác nhau

| Luồng | URL của project hiện tại | Cấu hình ở đâu |
| --- | --- | --- |
| Google → Supabase | `https://mmukxhbucfectvhfbame.supabase.co/auth/v1/callback` | Google Auth Platform → Clients → Web client → Authorized redirect URIs; đối chiếu URL được hiển thị trong Supabase Google provider |
| Supabase → Web local | `http://localhost:3000/` | Supabase Authentication → URL Configuration → Redirect URLs |
| Supabase → Android | `vn.packflow.app://login-callback/` | Cùng danh sách Redirect URLs; đã đăng ký scheme/host trong AndroidManifest |
| Supabase → Web production | Chưa có domain được cung cấp | Thêm URL HTTPS thực tế sau khi có hosting; không dùng wildcard rộng trong production |

## Cấu hình Google Cloud

1. Mở [Google Cloud Console](https://console.cloud.google.com/), chọn Google Cloud project do doanh nghiệp quản lý. Không dùng Supabase project ref thay cho Google Cloud project ID.
2. Vào **Google Auth Platform → Branding**, nhập tên PackFlow, email hỗ trợ và thông tin website thực tế theo yêu cầu Google.
3. Trong **Audience**, chọn Internal nếu tổ chức Google Workspace phù hợp và toàn bộ nhân viên thuộc tổ chức đó. Nếu dùng tài khoản Gmail hoặc tổ chức khác, chọn External. Khi đang Testing, thêm đúng email nhân viên vào Test users. Audience của Google không thay thế quyền nhân viên của PackFlow.
4. Trong **Data Access**, chỉ cấu hình `openid`, email và profile. Không yêu cầu Drive, Gmail hoặc quyền offline bổ sung.
5. Trong **Clients → Create client**, chọn **Web application**. Luồng hiện tại dùng trình duyệt và Supabase callback cho cả Web/Android, nên không cần native Android client/SHA certificate cho luồng này. Native Google Sign-In sẽ cần cấu hình riêng nếu triển khai sau này.
6. Thêm Authorized redirect URI ở bảng trên, đối chiếu với callback lấy trực tiếp từ Google provider của project Supabase. Không đặt scheme Android làm Google callback.
7. Sao chép Client ID và Client Secret vào Supabase Dashboard, không thêm vào `.env.local` của frontend, Git, README hoặc chat.

## Cấu hình Supabase

1. Mở project **thinhloinoibo** (`mmukxhbucfectvhfbame`) → Authentication → Sign In / Providers → Google.
2. Bật provider, nhập Client ID/Client Secret thật từ Google, giữ xác minh nonce mặc định, lưu thay đổi.
3. Authentication → URL Configuration: Site URL dùng URL ứng dụng thực tế; môi trường local hiện là `http://localhost:3000/`. Khi triển khai, thay Site URL bằng origin HTTPS production và giữ redirect development cần thiết riêng trong allow-list.
4. Thêm chính xác các URL ứng dụng trong bảng. Code dùng origin/path hiện tại, loại query/fragment khỏi redirect web. Chạy web cổng 3000 thay vì cổng IDE ngẫu nhiên.
5. Authentication → Sign In / Providers → cấu hình chung: bật **Allow manual linking**. Không dùng `config push` toàn bộ file local tối giản để tránh ghi đè cấu hình remote khác.
6. Với Google account mới, Supabase có thể tạo `auth.users`; ứng dụng không tạo `profiles` hay cấp role từ email/metadata. Không có profile active đồng nghĩa bị từ chối toàn bộ dữ liệu nghiệp vụ. Có thể tắt signup theo chính sách tổ chức; khi đó tài khoản Google chưa tồn tại có thể bị Auth từ chối trước màn hình kiểm tra nhân viên.

## Liên kết nhân viên đang có tài khoản

Đăng nhập username/phone trước → Thêm → Cài đặt → **Liên kết tài khoản Google**. SDK gọi `linkIdentity`; callback phải giữ nguyên Auth user ID. ID chờ liên kết được lưu local tối đa 10 phút (không lưu thêm token) để kiểm tra sau web redirect/cold start. Chỉ xác nhận thành công khi Auth trả identity Google trên user hiện tại. Không sao chép profile hoặc lịch sử giao dịch.

Supabase có thể tự liên kết identity cùng email đã xác minh theo cơ chế của Auth. Ứng dụng không tự ghép người dùng bằng email. Với username có email nội bộ hoặc phone, dùng liên kết thủ công từ phiên đăng nhập đã được cấp quyền. Nếu Google đã thuộc user khác, thông báo xung đột và nhờ quản trị viên xử lý; không tự merge/delete user.

## Phiên đăng nhập và dữ liệu

Một `AuthController` xử lý sự kiện Auth; SDK quản lý PKCE, callback, lưu phiên và refresh. Kiểm tra profile theo `auth.uid()`, bốn role hợp lệ và `is_active`. Kiểm tra lại khi có sự kiện phiên, app resume và mỗi 30 giây. RLS áp dụng ngay ở request database sau khi nhân viên bị khóa; UI có thể cập nhật trễ tối đa chu kỳ kiểm tra khi foreground.

Đăng xuất xóa cache nghiệp vụ; response cũ đang chờ bị loại bỏ. Navigator nghiệp vụ và dialog bị hủy khi mất quyền/đổi user. Lỗi mạng chuyển sang màn hình thử lại và giữ phiên; không xóa user hoặc profile. Có nút hủy khi người dùng đóng cửa sổ OAuth; ứng dụng không xem việc mở browser là đăng nhập thành công.

Android dùng external browser và custom scheme; Flutter deep-link router tắt để SDK nhận callback một lần. Đây là custom scheme, không phải verified app link. Không dùng WebView nhúng. Khi bổ sung iOS sau này, đăng ký `CFBundleURLTypes` cho `vn.packflow.app`, dùng cùng callback và kiểm thử cold/warm start trên iOS trước khi công bố hỗ trợ.

## Kiểm thử

```powershell
cd D:\ThinhLoi\frontend
flutter pub get
flutter analyze
flutter test
.\scripts\run_web.ps1
```

Migration `202611040005_google_employee_access.sql` bổ sung policy restrictive cho dữ liệu và storage, bỏ role mặc định, cấm client sửa profile và sửa NULL guard trong 7 RPC. SQL test dưới đây tạo fixture trong transaction và kết thúc bằng rollback:

```powershell
cd D:\ThinhLoi\backend
npx supabase db query --file supabase/tests/google_employee_access.sql
```

Lệnh trên dùng Supabase local (cần Docker và stack local). Các assertion đã được chạy thành công trong transaction rollback trên project linked vì máy hiện không có Docker.

Tự động: profile hợp lệ/thiếu/khóa/role sai, lỗi mạng và retry, response cũ sau logout, bấm Google lặp, hủy, lỗi provider, liên kết cùng ID/sai ID, xóa cache; SQL kiểm tra tài khoản lạ không đọc products/balances/invoices/profiles, không gọi RPC, không tự tăng quyền, nhân viên bị khóa mất quyền ngay và bucket riêng tư.

Cần kiểm thử thủ công sau cấu hình provider: Google được cấp quyền vào Dashboard; tài khoản lạ vào màn hình từ chối; nhân viên disabled; hủy consent; callback sai/đúng; refresh Web và mở lại ứng dụng; liên kết Google từ username/phone giữ cùng UUID; identity đã thuộc user khác; đăng nhập lại bằng Google đã liên kết; Android mở từ trạng thái tắt/background/foreground. Không ghi OAuth code/token vào báo cáo hoặc log.

Nguồn: [Supabase Google](https://supabase.com/docs/guides/auth/social-sign-in/auth-google), [Identity linking](https://supabase.com/docs/guides/auth/auth-identity-linking), [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls).
