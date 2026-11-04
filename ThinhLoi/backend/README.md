# PackFlow Backend – Supabase

Hướng dẫn Google Cloud, callback, liên kết identity và kiểm thử: [GOOGLE_OAUTH.md](GOOGLE_OAUTH.md). Google provider hiện chưa bật; cần cấu hình Client ID/Secret thật trong Supabase Dashboard.

## Xác thực nhân viên

Supabase Auth xác minh mật khẩu; project không tự băm hoặc lưu mật khẩu. Username là định danh nội bộ trong `public.profiles`; Edge Function `login-with-username` ánh xạ an toàn sang Auth user. Số điện thoại Việt Nam được chuẩn hóa E.164 (`+84...`) và dùng phone/password native.

Nhân viên mới mặc định `is_active = false`. RLS nghiệp vụ chỉ cho hồ sơ active có role hợp lệ. Không đưa secret/service-role key vào Flutter hoặc Git.

```powershell
cd backend
npx supabase login
npx supabase link --project-ref mmukxhbucfectvhfbame
npx supabase db push
npx supabase functions deploy login-with-username --no-verify-jwt
```

Bật Google provider và cấu hình callback trong frontend README. Nếu chưa có SMS provider, phục hồi tài khoản chỉ có phone cần quản trị viên hỗ trợ.

Backend không có Node.js server riêng. Node/npm chỉ được dùng để chạy Supabase CLI. Database, phân quyền và nghiệp vụ quan trọng chạy trên Supabase PostgreSQL, RLS và RPC.

## Cấu trúc

```text
backend/
├── package.json                 # Supabase CLI development dependency
├── package-lock.json
└── supabase/
    ├── config.toml              # Được tạo bởi supabase init
    ├── migrations/
    │   ├── 202611040001_packflow_core.sql
    │   └── 202611040002_packflow_workflows.sql
    ├── tests/
    │   └── inventory_workflows.sql
    └── seed.sql
```

## 1. Yêu cầu

- Node.js 20 trở lên.
- npm.
- Docker Desktop chỉ cần khi chạy Supabase local.
- Tài khoản có quyền truy cập Supabase project.

Kiểm tra:

```powershell
node --version
npm --version
```

Nếu Node thấp hơn phiên bản 20, hãy nâng cấp Node trước khi cài CLI.

## 2. Cài Supabase CLI trên Windows

Supabase CLI được cài cục bộ trong backend, không phải global:

```powershell
cd D:\ThinhLoi\backend
npm init -y
npm install supabase --save-dev
npx supabase --version
```

Vì cài bằng npm, mọi lệnh phải bắt đầu bằng `npx supabase`. Lệnh `supabase login` sẽ không hoạt động nếu chưa cài CLI toàn cục bằng Scoop.

## 3. Khởi tạo cấu hình CLI

Project đã có thư mục `supabase` chứa migration. Chạy:

```powershell
cd D:\ThinhLoi\backend
npx supabase init
```

Lệnh này tạo `supabase/config.toml`. Nó không được xóa các migration hiện có. Nếu CLI báo project đã được khởi tạo thì bỏ qua bước này.

## 4. Đăng nhập

```powershell
npx supabase login
```

Trình duyệt sẽ mở để xác thực tài khoản. Có thể đăng nhập bằng Personal Access Token:

```powershell
npx supabase login --token <SUPABASE_PERSONAL_ACCESS_TOKEN>
```

Không commit Personal Access Token vào repository.

### Tích hợp Supabase cho Next.js SSR (tùy chọn)

> Mục này chỉ dùng nếu sau này có thêm frontend Next.js. Flutter frontend hiện tại không sử dụng `@supabase/supabase-js`, `@supabase/ssr`, `page.tsx` hoặc Next.js middleware.
>
> Biến có tiền tố `NEXT_PUBLIC_` và publishable key sẽ xuất hiện ở trình duyệt. Đây không phải secret. Không bao giờ đặt `service_role` key, database password hoặc Personal Access Token vào các biến này.

#### 1. Cài packages

Chạy trong thư mục project Next.js, không chạy trong Flutter frontend:

```powershell
npm install @supabase/supabase-js @supabase/ssr
```

#### 2. Tạo `.env.local`

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://mmukxhbucfectvhfbame.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable__5yyeFnWcnEiq7s0zGHxgg_36R1XadC
```

Đảm bảo `.env.local` nằm trong `.gitignore`. Không đưa file này vào source control.

#### 3. Server Component mẫu

File `app/page.tsx`:

```tsx
import { createClient } from '@/utils/supabase/server'

export default async function Page() {
  const supabase = await createClient()
  const { data: todos, error } = await supabase.from('todos').select()

  if (error) {
    return <p>Không thể tải dữ liệu.</p>
  }

  return (
    <ul>
      {todos?.map((todo) => (
        <li key={todo.id}>{todo.name}</li>
      ))}
    </ul>
  )
}
```

#### 4. Supabase server client

File `utils/supabase/server.ts`:

```ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            )
          } catch {
            // Server Component không thể luôn ghi cookie.
            // Proxy/middleware bên dưới chịu trách nhiệm refresh session.
          }
        },
      },
    },
  )
}
```

#### 5. Supabase browser client

File `utils/supabase/client.ts`:

```ts
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  )
}
```

#### 6. Session refresh helper

File `utils/supabase/middleware.ts`:

```ts
import { createServerClient } from '@supabase/ssr'
import { type NextRequest, NextResponse } from 'next/server'

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          )
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options),
          )
        },
      },
    },
  )

  // Không xóa dòng này: getUser() refresh và xác thực session phía server.
  await supabase.auth.getUser()

  return supabaseResponse
}
```

File `proxy.ts` cho Next.js phiên bản hiện tại:

```ts
import { type NextRequest } from 'next/server'
import { updateSession } from '@/utils/supabase/middleware'

export async function proxy(request: NextRequest) {
  return updateSession(request)
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

#### 7. Agent Skills (tùy chọn)

```powershell
npx skills add supabase/agent-skills
```

Agent Skills chỉ hỗ trợ công cụ AI hiểu workflow Supabase tốt hơn; không phải dependency runtime của PackFlow.

## 5. Liên kết remote project

```powershell
npx supabase link --project-ref mmukxhbucfectvhfbame
```

CLI có thể yêu cầu database password của project. Không đặt password này trong frontend hoặc file được commit.

Kiểm tra trạng thái migration:

```powershell
npx supabase migration list --remote
```

## 6. Deploy migration

Luôn dry-run trước:

```powershell
npx supabase db push --dry-run --remote
```

Nếu kết quả đúng, triển khai:

```powershell
npx supabase db push --remote
```

Không chạy `npx supabase db reset --remote` trên database có dữ liệu vì thao tác đó có thể xóa và dựng lại database.

Nếu remote đã có schema được tạo bằng Dashboard hoặc SQL Editor, hãy pull và đối chiếu trước:

```powershell
npx supabase db pull --remote
npx supabase migration list --remote
```

## 7. Chạy Supabase local

Mở Docker Desktop trước, sau đó:

```powershell
cd D:\ThinhLoi\backend
npx supabase start
npx supabase status
npx supabase db reset
```

Lần chạy đầu có thể mất thời gian vì CLI phải tải Docker images.

Dừng local stack:

```powershell
npx supabase stop
```

## 8. Chạy SQL tests

Sau khi local stack hoạt động:

```powershell
npx supabase test db
```

Hoặc chạy trực tiếp file kiểm tra:

```powershell
psql <LOCAL_DATABASE_URL> -f supabase/tests/inventory_workflows.sql
```

## 9. Tạo admin đầu tiên

1. Tắt public sign-up trong Supabase Dashboard.
2. Vào Authentication → Users và tạo user nội bộ.
3. Copy UUID của user.
4. Chạy trong SQL Editor:

```sql
insert into public.profiles(id, full_name, role, is_active)
values ('<AUTH_USER_UUID>', 'Quản trị hệ thống', 'admin', true);
```

Client không có quyền tự gán role admin.

## 10. Các lệnh thường dùng

```powershell
# Kiểm tra CLI
npx supabase --version

# Đăng nhập và liên kết
npx supabase login
npx supabase link --project-ref mmukxhbucfectvhfbame

# Kiểm tra và deploy migration
npx supabase migration list --remote
npx supabase db push --dry-run --remote
npx supabase db push --remote

# Local development
npx supabase start
npx supabase status
npx supabase db reset
npx supabase stop
```

## Bảo mật

- Không đưa `service_role` key vào Flutter.
- Không commit database password, Personal Access Token hoặc access token.
- Frontend chỉ sử dụng Supabase publishable key.
- Tồn kho và xác nhận chứng từ phải đi qua RPC được bảo vệ.
- RLS phải được bật trên toàn bộ bảng nghiệp vụ.
