# Thịnh Lợi

```text
D:\ThinhLoi
├── frontend\   Flutter Web/Android
├── frontend-react\   React Web
└── backend\    Supabase PostgreSQL, RLS, RPC, Storage migrations
```

## Chạy frontend cổng 3000

```powershell
cd D:\ThinhLoi\frontend
flutter pub get
.\scripts\run_web.ps1
```

Scripts đọc biến môi trường PowerShell hoặc `frontend/.env.local` và truyền cấu hình bằng `--dart-define`. File env được Git bỏ qua và không được đóng gói vào Web assets.

## Backend

Xem [backend/README.md](backend/README.md) để triển khai migration và tạo admin đầu tiên.

## Chạy React Web

```powershell
cd D:\ThinhLoi\frontend-react
Copy-Item .env.example .env.local
npm install
npm run dev
```
