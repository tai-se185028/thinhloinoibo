import { createContext, useContext, useEffect, useState } from "react";
import { NavLink, Navigate, Route, Routes } from "react-router-dom";
import {
  BarChart3,
  Box,
  ChevronsUpDown,
  CheckCircle2,
  Eye,
  EyeOff,
  ClipboardList,
  Gauge,
  KeyRound,
  LogOut,
  Menu,
  Pencil,
  Plus,
  Receipt,
  Search,
  ShieldCheck,
  Settings,
  Trash2,
  Truck,
  UserRound,
  Users,
  Warehouse,
} from "lucide-react";
import { supabase, configured, message } from "@/lib/supabase";
import { cn } from "cn";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Checkbox } from "@/components/ui/checkbox";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Textarea } from "@/components/ui/textarea";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { Toaster } from "@/components/ui/sonner";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { toast } from "sonner";
import { z } from "zod";
import {
  downloadInvoicePdf,
  downloadOutboundPdf,
  previewInvoicePdf,
  previewOutboundPdf,
} from "@/features/documents/pdf";
import { issueInvoiceForOutbound } from "@/services/invoice-service";
import { sendPaidInvoiceEmail } from "@/services/email-service";
import {
  formatCurrency as cash,
  formatDate as dt,
  formatIntegerInput,
  formatVehiclePlate,
  isValidVehiclePlate,
} from "@/lib/formatters";
import { statusLabels as st } from "@/config/statuses";
const C = createContext(),
  useD = () => useContext(C);
const required = z.string().trim().min(1, "không được để trống"),
  phone = z
    .string()
    .trim()
    .regex(/^(\+84|0)\d{9}$/, "không đúng định dạng số điện thoại Việt Nam"),
  email = z
    .string()
    .trim()
    .email("không đúng định dạng email")
    .or(z.literal(""));
const optionalTaxCode = z
    .string()
    .trim()
    .refine(
      (value) => value === "" || /^\d{10}(\d{3})?$/.test(value),
      "phải gồm 10 hoặc 13 chữ số",
    ),
  personName = z
    .string()
    .trim()
    .min(2, "phải có ít nhất 2 ký tự")
    .max(150, "không được vượt quá 150 ký tự")
    .regex(/^[\p{L}\d\s.&'()/-]+$/u, "chứa ký tự không hợp lệ"),
  numberText = (label, { integer = false, positive = false } = {}) =>
    z
      .string()
      .trim()
      .min(1, `${label} không được để trống`)
      .transform((value) => value.replaceAll(",", ""))
      .refine((value) => /^\d+(\.\d+)?$/.test(value), `${label} phải là số`)
      .refine(
        (value) => !integer || Number.isInteger(Number(value)),
        `${label} phải là số nguyên`,
      )
      .refine(
        (value) => (positive ? Number(value) > 0 : Number(value) >= 0),
        `${label} ${positive ? "phải lớn hơn 0" : "không được âm"}`,
      )
      .transform(Number);
const optionalNumberText = (label, { integer = false } = {}) =>
  z
    .string()
    .trim()
    .transform((value) => value.replaceAll(",", ""))
    .refine(
      (value) => value === "" || /^\d+(\.\d+)?$/.test(value),
      `${label} phải là số`,
    )
    .refine(
      (value) => value === "" || !integer || Number.isInteger(Number(value)),
      `${label} phải là số nguyên`,
    )
    .transform((value) => (value === "" ? 0 : Number(value)));
const optionalDimension = z
  .string()
  .trim()
  .refine((value) => value === "" || /^\d+(\.\d+)?$/.test(value), "phải là số")
  .refine((value) => value === "" || Number(value) > 0, "phải lớn hơn 0")
  .transform((value) => (value === "" ? null : Number(value)));
const fieldNames = {
  identifier: "Tên đăng nhập hoặc email",
  password: "Mật khẩu",
  name: "Tên",
  sku: "SKU",
  unit: "Đơn vị",
  stock: "Số lượng nhập",
  buy: "Giá nhập",
  sell: "Giá bán",
  min: "Tồn tối thiểu",
  dimension: "Kích thước",
  length: "Chiều dài",
  width: "Chiều rộng",
  height: "Chiều cao",
  phone: "Điện thoại",
  email: "Email",
  tax: "Mã số thuế",
  tax_code: "Mã số thuế",
  business_name: "Tên doanh nghiệp",
  representative_name: "Người đại diện",
  website: "Website",
  bank_account_number: "Số tài khoản",
  oldPassword: "Mật khẩu hiện tại",
  newPassword: "Mật khẩu mới",
  confirmPassword: "Xác nhận mật khẩu",
};
function validateFields(schema, values, setErrors) {
  const result = schema.safeParse(values);
  if (result.success) {
    setErrors({});
    return result.data;
  }
  const errors = {};
  for (const issue of result.error.issues) {
    const key = String(issue.path[0] || "form");
    errors[key] ??= issue.message;
  }
  setErrors(errors);
  const first = Object.entries(errors)[0];
  toast.error(`${fieldNames[first[0]] || first[0]}: ${first[1]}`);
  return null;
}
function valid(schema, value) {
  const r = schema.safeParse(value);
  if (!r.success) {
    const detail = r.error.issues
      .map((i) => `${i.path.join(".")}: ${i.message}`)
      .join("; ");
    toast.error(detail);
    throw new Error(detail);
  }
  return r.data;
}
function validLines(lines) {
  if (!lines.length) throw new Error("Vui lòng thêm ít nhất một sản phẩm.");
  if (lines.some((x) => !x.product_id))
    throw new Error("Vui lòng chọn sản phẩm.");
  if (lines.some((x) => !Number.isInteger(+x.quantity) || +x.quantity <= 0))
    throw new Error("Số lượng phải là số nguyên lớn hơn 0.");
  if (lines.some((x) => !Number.isFinite(+x.unit_price) || +x.unit_price < 0))
    throw new Error("Đơn giá phải là số không âm.");
}
function App() {
  const [s, setS] = useState();
  useEffect(() => {
    if (!configured) return setS(null);
    supabase.auth.getSession().then((x) => setS(x.data.session));
    const { x } = {
      x: supabase.auth.onAuthStateChange((_, v) => setS(v)).data,
    };
    return () => x.subscription.unsubscribe();
  }, []);
  if (!configured)
    return (
      <Center t="Chưa cấu hình Supabase" d="Tạo .env.local từ .env.example." />
    );
  if (s === undefined) return <Load />;
  if (!s) return <Login />;
  return (
    <Provider session={s}>
      <Shell />
    </Provider>
  );
}
function Center({ t, d }) {
  return (
    <main className="grid min-h-screen place-items-center bg-muted p-4">
      <Card className="max-w-md">
        <CardHeader>
          <CardTitle>{t}</CardTitle>
          <CardDescription>{d}</CardDescription>
        </CardHeader>
      </Card>
    </main>
  );
}
function Load() {
  return (
    <div className="space-y-4 p-8">
      <Skeleton className="h-12 w-64" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}
function GoogleIcon(props) {
  return (
    <svg viewBox="0 0 24 24" className="size-5 shrink-0" {...props}>
      <path
        fill="#4285F4"
        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
      />
      <path
        fill="#34A853"
        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
      />
      <path
        fill="#FBBC05"
        d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
      />
      <path
        fill="#EA4335"
        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
      />
    </svg>
  );
}

function Login() {
  const [id, setId] = useState(""),
    [pw, setPw] = useState(""),
    [showPassword, setShowPassword] = useState(false),
    [busy, setBusy] = useState(false),
    [errors, setErrors] = useState({});
  async function go(e) {
    e.preventDefault();
    const values = validateFields(
      z.object({
        identifier: z
          .string()
          .trim()
          .min(1, "không được để trống")
          .refine(
            (value) =>
              value.includes("@")
                ? z.string().email().safeParse(value).success
                : /^[A-Za-z0-9_]{3,30}$/.test(value),
            "phải là email hợp lệ hoặc tên đăng nhập từ 3–30 ký tự",
          ),
        password: z.string().min(8, "phải có ít nhất 8 ký tự"),
      }),
      { identifier: id, password: pw },
      setErrors,
    );
    if (!values) return;
    setBusy(true);
    try {
      if (values.identifier.includes("@")) {
        const { error } = await supabase.auth.signInWithPassword({
          email: values.identifier,
          password: values.password,
        });
        if (error) throw error;
      } else {
        const { data, error } = await supabase.functions.invoke(
          "login-with-username",
          {
            body: {
              username: values.identifier.toLowerCase(),
              password: values.password,
            },
          },
        );
        if (error) throw error;
        if (!data?.access_token || !data?.refresh_token)
          throw new Error(
            data?.message || "Thông tin đăng nhập không chính xác.",
          );
        const r = await supabase.auth.setSession({
          access_token: data.access_token,
          refresh_token: data.refresh_token,
        });
        if (r.error) throw r.error;
      }
    } catch (e) {
      toast.error(message(e));
    } finally {
      setBusy(false);
    }
  }
  async function google() {
    setBusy(true);
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo: location.origin,
          queryParams: { prompt: "select_account" },
        },
      });
      if (error) throw error;
    } catch (error) {
      toast.error(message(error));
      setBusy(false);
    }
  }
  return (
    <main className="min-h-screen bg-slate-50/60 lg:grid lg:grid-cols-[minmax(460px,1fr)_minmax(540px,1.15fr)]">
      <section className="relative hidden overflow-hidden bg-slate-950 p-12 text-white lg:flex lg:flex-col lg:justify-between shadow-2xl">
        <div className="absolute -left-28 top-1/4 size-96 rounded-full bg-blue-600/15 blur-[120px]" />
        <div className="absolute -right-20 bottom-16 size-80 rounded-full bg-indigo-500/15 blur-[100px]" />
        <div className="absolute inset-0 bg-[linear-gradient(to_right,#1e293b0a_1px,transparent_1px),linear-gradient(to_bottom,#1e293b0a_1px,transparent_1px)] bg-[size:4rem_4rem]" />
        
        <div className="relative flex items-center gap-3.5">
          <div className="grid size-11 place-items-center rounded-xl bg-gradient-to-tr from-blue-600 to-indigo-500 text-sm font-black text-white shadow-lg shadow-blue-500/30 ring-1 ring-white/20">
            TL
          </div>
          <div>
            <p className="text-lg font-bold tracking-tight text-white">Thịnh Lợi</p>
            <p className="text-xs text-slate-400">Quản lý kho hàng & nội bộ</p>
          </div>
        </div>

        <div className="relative my-auto max-w-lg py-12">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-blue-500/30 bg-blue-500/10 px-3.5 py-1 text-xs font-medium text-blue-300 backdrop-blur-sm">
            <span className="relative flex size-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-blue-400 opacity-75"></span>
              <span className="relative inline-flex size-2 rounded-full bg-blue-400"></span>
            </span>
            Hệ thống quản trị nội bộ
          </div>

          <h1 className="text-4xl font-extrabold leading-[1.15] tracking-tight text-white xl:text-5xl">
            Quản lý vận hành
            <span className="mt-1 block bg-gradient-to-r from-blue-400 via-sky-300 to-teal-300 bg-clip-text text-transparent">
              đơn giản và chính xác.
            </span>
          </h1>

          <p className="mt-5 max-w-md text-sm leading-relaxed text-slate-300/90">
            Theo dõi sản phẩm, tồn kho, phiếu xuất và hóa đơn trên một hệ thống
            tập trung, chuẩn hóa quy trình.
          </p>

          <div className="mt-9 grid gap-3 text-sm">
            {[
              "Dữ liệu kho được cập nhật theo thời gian thực",
              "Phân quyền an toàn, minh bạch cho từng nhân viên",
              "Chứng từ và hóa đơn chuẩn hóa, dễ dàng xuất PDF",
            ].map((item) => (
              <div
                className="flex items-center gap-3 rounded-xl border border-white/5 bg-white/[0.03] p-3 backdrop-blur-sm transition-colors hover:border-white/10 hover:bg-white/[0.05]"
                key={item}
              >
                <div className="grid size-6 shrink-0 place-items-center rounded-md bg-blue-500/20 text-blue-400 ring-1 ring-blue-500/30">
                  <CheckCircle2 className="size-3.5" />
                </div>
                <span className="font-medium text-slate-200">{item}</span>
              </div>
            ))}
          </div>
        </div>

        <p className="relative text-xs text-slate-500">
          © {new Date().getFullYear()} Công ty TNHH Thịnh Lợi • Dành riêng cho nhân viên nội bộ
        </p>
      </section>

      <section className="flex min-h-screen items-center justify-center p-4 sm:p-8 lg:p-12">
        <div className="w-full max-w-[440px] rounded-3xl border border-slate-200/80 bg-white p-7 sm:p-10 shadow-xl shadow-slate-200/50">
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <div className="grid size-10 place-items-center rounded-xl bg-gradient-to-tr from-blue-600 to-indigo-500 text-sm font-black text-white shadow-md shadow-blue-500/20">
              TL
            </div>
            <div>
              <p className="font-bold text-slate-900">Thịnh Lợi</p>
              <p className="text-xs text-muted-foreground">Quản lý kho hàng & nội bộ</p>
            </div>
          </div>

          <div className="mb-7">
            <div className="mb-4 inline-flex size-12 items-center justify-center rounded-2xl bg-blue-50 text-blue-600 ring-8 ring-blue-50/50">
              <ShieldCheck className="size-6" />
            </div>
            <h2 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">
              Chào mừng trở lại
            </h2>
            <p className="mt-1.5 text-sm text-slate-500">
              Đăng nhập bằng tài khoản nhân viên đã được cấp quyền.
            </p>
          </div>

          <form onSubmit={go} className="space-y-4" noValidate>
            <F l="Tên đăng nhập hoặc email" required error={errors.identifier}>
              <Input
                className="h-11 rounded-xl border-slate-200 text-slate-900 shadow-sm transition-colors focus-visible:border-blue-500 focus-visible:ring-2 focus-visible:ring-blue-500/20 placeholder:text-slate-400"
                autoFocus
                autoComplete="username"
                placeholder="Nhập tên đăng nhập hoặc email"
                value={id}
                onChange={(e) => setId(e.target.value)}
                aria-invalid={Boolean(errors.identifier)}
              />
            </F>
            <F l="Mật khẩu" required error={errors.password}>
              <div className="relative">
                <Input
                  className="h-11 rounded-xl border-slate-200 pr-11 text-slate-900 shadow-sm transition-colors focus-visible:border-blue-500 focus-visible:ring-2 focus-visible:ring-blue-500/20 placeholder:text-slate-400"
                  type={showPassword ? "text" : "password"}
                  autoComplete="current-password"
                  placeholder="Nhập mật khẩu"
                  value={pw}
                  onChange={(e) => setPw(e.target.value)}
                  aria-invalid={Boolean(errors.password)}
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="absolute right-1 top-1 size-9 text-slate-400 hover:text-slate-700"
                  onClick={() => setShowPassword((value) => !value)}
                  aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                >
                  {showPassword ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
                </Button>
              </div>
            </F>
            <Button
              className="mt-2 h-11 w-full rounded-xl bg-slate-900 font-semibold text-white shadow-md shadow-slate-900/10 transition-all hover:bg-slate-800 hover:shadow-lg hover:shadow-slate-900/15 active:scale-[0.99] disabled:opacity-60"
              disabled={busy}
            >
              {busy ? "Đang đăng nhập…" : "Đăng nhập"}
            </Button>
          </form>

          <div className="relative my-6 text-center text-xs">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-slate-200" />
            </div>
            <span className="relative bg-white px-3 font-medium text-slate-400">
              hoặc tiếp tục với
            </span>
          </div>

          <Button
            type="button"
            variant="outline"
            className="h-11 w-full gap-3 rounded-xl border-slate-200 bg-white font-medium text-slate-700 shadow-sm transition-all hover:bg-slate-50 hover:border-slate-300 hover:text-slate-900 active:scale-[0.99]"
            disabled={busy}
            onClick={google}
          >
            <GoogleIcon />
            <span>Tiếp tục với Google</span>
          </Button>

          <div className="mt-8 flex items-center justify-center gap-2 rounded-xl border border-slate-100 bg-slate-50/80 py-2.5 px-3 text-xs text-slate-500">
            <ShieldCheck className="size-4 text-emerald-600 shrink-0" />
            <span>Chỉ tài khoản nhân viên đang hoạt động mới có thể truy cập</span>
          </div>
        </div>
      </section>
      <Toaster richColors />
    </main>
  );
}
function Provider({ session, children }) {
  const [d, setD] = useState({}),
    [loading, setL] = useState(true);
  async function load() {
    setL(true);
    const q = await Promise.all(
      [
        "product_stock_view",
        "customers",
        "suppliers",
        "inbound_vouchers",
        "outbound_vouchers",
        "invoices",
        "sales_orders",
        "stock_movements",
        "business_settings",
        "profiles",
      ].map((t, i) => {
        let x = supabase
          .from(t)
          .select(
            i === 3
              ? "*, inbound_items(*)"
              : i === 4
                ? "*, outbound_items(*)"
                : i === 5
                  ? "*, invoice_items(*)"
                  : i === 6
                    ? "*, sales_order_items(*)"
                    : i === 7
                      ? "*, products(name,sku)"
                      : "*",
          );
        if (i === 9) x = x.eq("id", session.user.id);
        return x;
      }),
    );
    const bad = q.find((x) => x.error);
    if (bad) toast.error(message(bad.error));
    setD({
      products: q[0].data || [],
      customers: q[1].data || [],
      suppliers: q[2].data || [],
      ins: q[3].data || [],
      outs: q[4].data || [],
      invoices: q[5].data || [],
      orders: q[6].data || [],
      moves: q[7].data || [],
      settings: q[8].data?.[0] || {},
      profile: q[9].data?.[0],
    });
    setL(false);
  }
  useEffect(() => {
    load();
  }, []);
  async function run(fn, ok) {
    try {
      await fn();
      toast.success(ok);
      await load();
      return true;
    } catch (e) {
      toast.error(message(e));
      await load();
      return false;
    }
  }
  return (
    <C.Provider value={{ ...d, session, loading, load, run }}>
      {children}
      <Toaster richColors />
    </C.Provider>
  );
}
const nav = [
  ["/dashboard", "Tổng quan", Gauge],
  ["/products", "Sản phẩm", Box],
  ["/inventory", "Tồn kho", Warehouse],
  ["/outbound", "Phiếu xuất", Truck],
  ["/invoices", "Hóa đơn", Receipt],
  ["/partners", "Đối tác", Users],
];
function N() {
  const d = useD(),
    [profileOpen, setProfileOpen] = useState(false);
  const displayName = d.profile?.full_name || "Nhân viên",
    initials = displayName
      .split(" ")
      .slice(-2)
      .map((part) => part[0])
      .join("")
      .toUpperCase();
  return (
    <div className="flex h-full flex-col border-r bg-background px-3 py-5 text-foreground">
      <div className="mb-8 flex items-center gap-3 px-2">
        <div className="grid size-10 place-items-center rounded-xl bg-primary text-sm font-black text-primary-foreground shadow-sm">
          TL
        </div>
        <div>
          <h2 className="text-base font-bold tracking-tight">Thịnh Lợi</h2>
          <p className="text-[11px] text-muted-foreground">Quản lý kho hàng</p>
        </div>
      </div>
      <p className="mb-2 px-3 text-[10px] font-semibold uppercase tracking-[0.16em] text-muted-foreground">
        Điều hướng
      </p>
      <nav className="space-y-1">
        {nav.map(([p, l, I]) => (
          <NavLink
            to={p}
            key={p}
            className={({ isActive }) =>
              cn(
                "group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-muted-foreground transition-colors",
                isActive
                  ? "bg-primary/10 text-primary"
                  : "hover:bg-muted hover:text-foreground",
              )
            }
          >
            <I className="size-[18px] stroke-[1.8]" />
            {l}
          </NavLink>
        ))}
      </nav>
      <div className="mt-auto border-t pt-3">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              className="h-auto w-full justify-start gap-3 rounded-xl px-2 py-2 hover:bg-muted"
            >
              <Avatar className="size-9 border">
                <AvatarFallback className="bg-primary/10 text-xs font-bold text-primary">
                  {initials || "NV"}
                </AvatarFallback>
              </Avatar>
              <span className="min-w-0 flex-1 text-left">
                <span className="block truncate text-sm font-semibold">
                  {displayName}
                </span>
                <span className="block truncate text-[10px] font-normal text-muted-foreground">
                  {d.profile?.role || d.session.user.email}
                </span>
              </span>
              <ChevronsUpDown className="size-4 text-muted-foreground" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent side="top" align="start" className="w-56">
            <DropdownMenuLabel>Tài khoản</DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => setProfileOpen(true)}>
              <UserRound /> Thông tin cá nhân
            </DropdownMenuItem>
            <DropdownMenuItem asChild>
              <NavLink to="/settings">
                <Settings /> Cài đặt doanh nghiệp
              </NavLink>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              className="text-destructive focus:text-destructive"
              onSelect={() => supabase.auth.signOut()}
            >
              <LogOut /> Đăng xuất
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      <Dialog open={profileOpen} onOpenChange={setProfileOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Thông tin cá nhân</DialogTitle>
          </DialogHeader>
          <div className="flex items-center gap-4 rounded-xl bg-muted/60 p-4">
            <Avatar className="size-14 border bg-background">
              <AvatarFallback className="text-base font-bold">
                {initials || "NV"}
              </AvatarFallback>
            </Avatar>
            <div className="min-w-0">
              <p className="font-semibold">{displayName}</p>
              <p className="truncate text-sm text-muted-foreground">
                {d.session.user.email}
              </p>
            </div>
          </div>
          <div className="grid gap-3 text-sm">
            <div className="flex justify-between border-b pb-3">
              <span className="text-muted-foreground">Tên đăng nhập</span>
              <span className="font-medium">{d.profile?.username || "—"}</span>
            </div>
            <div className="flex justify-between border-b pb-3">
              <span className="text-muted-foreground">Vai trò</span>
              <span className="font-medium">{d.profile?.role || "—"}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Trạng thái</span>
              <Badge variant="outline" className="text-emerald-700">
                Đang hoạt động
              </Badge>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
function Shell() {
  const d = useD();
  return (
    <div className="min-h-screen bg-muted/30 md:grid md:grid-cols-[256px_1fr]">
      <aside className="fixed inset-y-0 hidden w-64 md:block">
        <N />
      </aside>
      <main className="md:col-start-2">
        <div className="border-b bg-background px-4 py-3 md:hidden">
          <div className="flex items-center gap-3">
            <div className="grid size-9 place-items-center rounded-xl bg-primary text-xs font-black text-primary-foreground">
              TL
            </div>
            <div>
              <p className="text-sm font-bold">Thịnh Lợi</p>
              <p className="text-[10px] text-muted-foreground">
                Quản lý kho hàng
              </p>
            </div>
          </div>
        </div>
        <div className="p-4 pb-28 md:p-8">
          {d.loading ? (
            <Load />
          ) : (
            <Routes>
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/products" element={<Products />} />
              <Route path="/inventory" element={<Inventory />} />
              <Route path="/sales-orders" element={<Orders />} />
              <Route path="/outbound" element={<Docs />} />
              <Route path="/invoices" element={<Invoices />} />
              <Route path="/partners" element={<Partners />} />
              <Route path="/reports" element={<Reports />} />
              <Route path="/settings" element={<Prefs />} />
              <Route path="/profile" element={<Profile />} />
              <Route path="*" element={<Navigate to="/dashboard" />} />
            </Routes>
          )}
        </div>
      </main>
      <MobileNav />
    </div>
  );
}
function MobileNav() {
  const [moreOpen, setMoreOpen] = useState(false);
  const tabs = [
    ["/products", "Sản phẩm", Box],
    ["/outbound", "Phiếu xuất", Truck],
    ["/invoices", "Hóa đơn", Receipt],
    ["/profile", "Cá nhân", UserRound],
  ];
  const item = ([path, label, Icon]) => (
    <NavLink
      key={path}
      to={path}
      className={({ isActive }) =>
        cn(
          "flex min-w-0 flex-1 flex-col items-center gap-1 py-2 text-[10px] font-medium text-muted-foreground",
          isActive && "text-primary",
        )
      }
    >
      <Icon className="size-5 stroke-[1.8]" />
      <span className="truncate">{label}</span>
    </NavLink>
  );
  return (
    <>
      <nav className="fixed inset-x-0 bottom-0 z-40 border-t bg-background/95 px-2 pb-[max(6px,env(safe-area-inset-bottom))] backdrop-blur md:hidden">
        <div className="mx-auto flex max-w-lg items-end justify-around">
          {item(tabs[0])}
          {item(tabs[1])}
          <button
            type="button"
            className="-mt-5 flex w-16 flex-col items-center gap-1 text-[10px] font-medium"
            onClick={() => setMoreOpen(true)}
          >
            <span className="grid size-12 place-items-center rounded-2xl bg-primary text-primary-foreground shadow-lg shadow-primary/25">
              <Plus className="size-6" />
            </span>
            <span>Tác vụ</span>
          </button>
          {item(tabs[2])}
          {item(tabs[3])}
        </div>
      </nav>
      <Sheet open={moreOpen} onOpenChange={setMoreOpen}>
        <SheetContent side="bottom" className="rounded-t-3xl px-5 pb-8 pt-5">
          <div className="mx-auto mb-5 h-1.5 w-12 rounded-full bg-muted" />
          <h2 className="text-lg font-bold">Tác vụ khác</h2>
          <p className="mb-5 text-sm text-muted-foreground">
            Truy cập nhanh các chức năng quản lý.
          </p>
          <div className="grid grid-cols-2 gap-3">
            {[
              ["/dashboard", "Tổng quan", Gauge],
              ["/inventory", "Tồn kho", Warehouse],
              ["/partners", "Đối tác", Users],
              ["/settings", "Cài đặt", Settings],
            ].map(([path, label, Icon]) => (
              <Button
                key={path}
                variant="outline"
                className="h-20 flex-col rounded-2xl"
                asChild
              >
                <NavLink to={path} onClick={() => setMoreOpen(false)}>
                  <Icon className="size-5" />
                  {label}
                </NavLink>
              </Button>
            ))}
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
function P({ t, d, a, children }) {
  return (
    <div className="space-y-6">
      <header className="flex justify-between gap-3">
        <div>
          <h1 className="text-3xl font-bold">{t}</h1>
          <p className="text-sm text-muted-foreground">{d}</p>
        </div>
        {a}
      </header>
      {children}
    </div>
  );
}
function F({ l, children, required = false, error }) {
  return (
    <div
      className={cn(
        "grid gap-2",
        error && "[&_input]:border-destructive [&_input]:ring-destructive/20",
      )}
    >
      <Label>
        {l}
        {required && <span className="ml-1 text-destructive">*</span>}
      </Label>
      {children}
      {error && (
        <p className="text-xs font-medium text-destructive" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
function formatQuantity(value) {
  return formatIntegerInput(value);
}
function FormattedQuantityInput({ defaultValue, name, error, min = 0 }) {
  const [value, setValue] = useState(() => formatQuantity(defaultValue));
  return (
    <Input
      name={name}
      type="text"
      inputMode="numeric"
      value={value}
      onChange={(event) => setValue(formatQuantity(event.target.value))}
      aria-invalid={Boolean(error)}
      data-min={min}
    />
  );
}
function FormattedMoneyInput({ defaultValue, name, error }) {
  const [value, setValue] = useState(() => formatQuantity(defaultValue));
  return (
    <Input
      name={name}
      type="text"
      inputMode="numeric"
      value={value}
      onChange={(event) => setValue(formatQuantity(event.target.value))}
      aria-invalid={Boolean(error)}
      placeholder="0"
    />
  );
}
function Status({ v }) {
  const c =
    {
      draft: "border-amber-200 bg-amber-100 text-amber-800",
      unpaid: "border-rose-200 bg-rose-100 text-rose-700",
      partial: "border-blue-200 bg-blue-100 text-blue-700",
      paid: "border-emerald-200 bg-emerald-100 text-emerald-700",
      finalized: "border-violet-200 bg-violet-100 text-violet-700",
      confirmed: "border-emerald-200 bg-emerald-100 text-emerald-700",
    }[v] || "";
  return (
    <Badge variant="outline" className={c}>
      {st[v] || v}
    </Badge>
  );
}
function Empty() {
  return (
    <div className="py-12 text-center text-sm text-muted-foreground">
      Chưa có dữ liệu.
    </div>
  );
}
function Modal({ open, setOpen, title, save, children }) {
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="max-h-[90vh] overflow-auto max-sm:inset-0 max-sm:h-dvh max-sm:max-h-none max-sm:w-screen max-sm:max-w-none max-sm:translate-x-0 max-sm:translate-y-0 max-sm:rounded-none sm:max-w-3xl">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>
        <form onSubmit={save} className="space-y-5" noValidate>
          {children}
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
            >
              Hủy
            </Button>
            <Button>Lưu</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
function Dashboard() {
  const d = useD(),
    low = d.products.filter((p) => +p.stock_quantity <= +p.minimum_stock),
    rev = d.invoices.reduce(
      (a, x) => a + (x.status === "finalized" ? +x.total_amount : 0),
      0,
    );
  return (
    <P
      t={`Xin chào, ${d.profile?.full_name || "bạn"}`}
      d={new Date().toLocaleDateString("vi-VN", { dateStyle: "full" })}
    >
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ["Sản phẩm", d.products.length],
          ["Tồn kho", d.products.reduce((a, x) => a + +x.stock_quantity, 0)],
          ["Doanh thu", cash(rev)],
          ["Sắp hết", low.length],
        ].map((x) => (
          <Card key={x[0]}>
            <CardHeader>
              <CardDescription>{x[0]}</CardDescription>
              <CardTitle>{x[1]}</CardTitle>
            </CardHeader>
          </Card>
        ))}
      </div>
      <List
        title="Cảnh báo tồn kho"
        rows={low.map((x) => [x.name, x.sku, `${x.stock_quantity} ${x.unit}`])}
      />
    </P>
  );
}
function List({ title, rows }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {rows.length ? (
          rows.map((r, i) => (
            <div
              className="flex justify-between border-b py-3 last:border-0"
              key={i}
            >
              <div>
                <b className="text-sm">{r[0]}</b>
                <p className="text-xs text-muted-foreground">{r[1]}</p>
              </div>
              <b>{r[2]}</b>
            </div>
          ))
        ) : (
          <Empty />
        )}
      </CardContent>
    </Card>
  );
}
function Products() {
  const d = useD(),
    [q, setQ] = useState(""),
    [open, setOpen] = useState(false),
    [e, setE] = useState({}),
    [errors, setErrors] = useState({}),
    list = d.products.filter((x) =>
      (x.name + x.sku).toLowerCase().includes(q.toLowerCase()),
    );
  function edit(x = {}) {
    setE(x);
    setErrors({});
    setOpen(true);
  }
  async function save(ev) {
    ev.preventDefault();
    const f = new FormData(ev.currentTarget),
      raw = validateFields(
        z.object({
          name: personName,
          unit: required.max(30, "không được vượt quá 30 ký tự"),
          stock: numberText("Số lượng nhập", {
            integer: true,
            positive: !e.id,
          }),
          buy: optionalNumberText("Giá nhập"),
          sell: optionalNumberText("Giá bán"),
          min: optionalNumberText("Tồn tối thiểu", { integer: true }),
          length: optionalDimension,
          width: optionalDimension,
          height: optionalDimension,
        }),
        Object.fromEntries(f),
        setErrors,
      );
    if (!raw) return;
    const p = {
      sku: e.sku || `SP-${Date.now().toString().slice(-8)}`,
      name: raw.name,
      material: e.material || "",
      unit: raw.unit,
      purchase_price: raw.buy,
      selling_price: raw.sell,
      minimum_stock: raw.min,
      dimension_length: raw.length,
      dimension_width: raw.width,
      dimension_height: raw.height,
      dimension_unit: e.dimension_unit || "cm",
      category_id: e.category_id || null,
      layer_count: e.layer_count || null,
      description: e.description || "",
      packaging_specification: f.get("note"),
    };
    const saved = await d.run(async () => {
      const { error } = await supabase.rpc("receive_product", {
        p_product: p,
        p_quantity: raw.stock,
        p_product_id: e.id || null,
      });
      if (error) throw error;
    }, "Đã lưu sản phẩm.");
    if (saved) setOpen(false);
  }
  return (
    <P
      t="Sản phẩm"
      d={`${d.products.length} mặt hàng`}
      a={
        <Button onClick={() => edit()}>
          <Plus />
          Nhập sản phẩm
        </Button>
      }
    >
      <div className="relative max-w-md">
        <Search className="absolute left-3 top-3 size-4" />
        <Input
          className="pl-9"
          value={q}
          onChange={(x) => setQ(x.target.value)}
        />
      </div>
      <Card className="hidden md:block">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Sản phẩm</TableHead>
              <TableHead>Tồn</TableHead>
              <TableHead>Giá nhập</TableHead>
              <TableHead>Giá bán</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {list.map((x) => (
              <TableRow key={x.id}>
                <TableCell>
                  <b>{x.name}</b>
                  <small className="block text-muted-foreground">{x.sku}</small>
                </TableCell>
                <TableCell>
                  {x.stock_quantity} {x.unit}
                </TableCell>
                <TableCell>{cash(x.purchase_price)}</TableCell>
                <TableCell>{cash(x.selling_price)}</TableCell>
                <TableCell>
                  <Button variant="ghost" onClick={() => edit(x)}>
                    Sửa / nhập thêm
                  </Button>
                  <Button
                    variant="ghost"
                    className="text-destructive"
                    onClick={() =>
                      d.run(async () => {
                        const { error } = await supabase
                          .from("products")
                          .update({ is_active: false })
                          .eq("id", x.id);
                        if (error) throw error;
                      }, "Đã ngừng sử dụng.")
                    }
                  >
                    <Trash2 />
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Card>
      <div className="grid gap-3 md:hidden">
        {list.map((x) => (
          <Card key={x.id} className="overflow-hidden">
            <CardContent className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <h3 className="truncate font-semibold">{x.name}</h3>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    {x.sku}
                  </p>
                </div>
                <Badge
                  variant="outline"
                  className={
                    Number(x.stock_quantity) <= Number(x.minimum_stock)
                      ? "border-amber-200 bg-amber-50 text-amber-700"
                      : "border-emerald-200 bg-emerald-50 text-emerald-700"
                  }
                >
                  {formatQuantity(x.stock_quantity)} {x.unit}
                </Badge>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-3 rounded-xl bg-muted/60 p-3 text-xs">
                <div>
                  <p className="text-muted-foreground">Giá nhập</p>
                  <p className="mt-1 font-semibold">{cash(x.purchase_price)}</p>
                </div>
                <div>
                  <p className="text-muted-foreground">Giá bán</p>
                  <p className="mt-1 font-semibold">{cash(x.selling_price)}</p>
                </div>
              </div>
              <div className="mt-3 flex justify-end gap-2">
                <Button variant="outline" size="sm" onClick={() => edit(x)}>
                  Sửa / nhập thêm
                </Button>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  className="text-destructive"
                  onClick={() =>
                    d.run(async () => {
                      const { error } = await supabase
                        .from("products")
                        .update({ is_active: false })
                        .eq("id", x.id);
                      if (error) throw error;
                    }, "Đã ngừng sử dụng.")
                  }
                >
                  <Trash2 />
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
        {!list.length && <Empty />}
      </div>
      <Modal
        open={open}
        setOpen={setOpen}
        title="Nhập / sửa sản phẩm"
        save={save}
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <F
              l="Kích thước (Dài × Rộng × Cao)"
              error={
                errors.dimension ||
                errors.length ||
                errors.width ||
                errors.height
              }
            >
              <div className="grid grid-cols-[1fr_auto_1fr_auto_1fr] items-center gap-2">
                <Input
                  name="length"
                  type="number"
                  inputMode="decimal"
                  min="0.01"
                  step="0.01"
                  placeholder="Dài"
                  defaultValue={e.dimension_length ?? ""}
                  aria-label="Chiều dài"
                />
                <span className="font-semibold text-muted-foreground">×</span>
                <Input
                  name="width"
                  type="number"
                  inputMode="decimal"
                  min="0.01"
                  step="0.01"
                  placeholder="Rộng"
                  defaultValue={e.dimension_width ?? ""}
                  aria-label="Chiều rộng"
                />
                <span className="font-semibold text-muted-foreground">×</span>
                <Input
                  name="height"
                  type="number"
                  inputMode="decimal"
                  min="0.01"
                  step="0.01"
                  placeholder="Cao"
                  defaultValue={e.dimension_height ?? ""}
                  aria-label="Chiều cao"
                />
              </div>
            </F>
          </div>
          {[
            ["Tên", "name", e.name, true, "text"],
            ["Đơn vị", "unit", e.unit || "cái", true, "text"],
            ["Số lượng nhập", "stock", e.id ? 0 : 1, true, "number"],
            ["Giá nhập", "buy", e.purchase_price ?? "", false, "number"],
            ["Giá bán", "sell", e.selling_price ?? "", false, "number"],
            ["Tồn tối thiểu", "min", e.minimum_stock ?? "", false, "number"],
            ["Ghi chú", "note", e.packaging_specification, false, "text"],
          ].map(([l, n, v, isRequired, type]) => (
            <F key={n} l={l} required={isRequired} error={errors[n]}>
              {n === "stock" || n === "min" ? (
                <FormattedQuantityInput
                  name={n}
                  defaultValue={v}
                  error={errors[n]}
                  min={n === "stock" && !e.id ? 1 : 0}
                />
              ) : n === "buy" || n === "sell" ? (
                <FormattedMoneyInput
                  name={n}
                  defaultValue={v}
                  error={errors[n]}
                />
              ) : (
                <Input
                  name={n}
                  type={type}
                  inputMode={type === "number" ? "decimal" : undefined}
                  min={type === "number" ? 0 : undefined}
                  step={type === "number" ? "0.01" : undefined}
                  defaultValue={v ?? ""}
                  aria-invalid={Boolean(errors[n])}
                />
              )}
            </F>
          ))}
        </div>
      </Modal>
    </P>
  );
}
function Inventory() {
  const d = useD();
  return (
    <P t="Tồn kho" d="Số dư và lịch sử nhập xuất">
      <Tabs defaultValue="b">
        <TabsList>
          <TabsTrigger value="b">Số dư</TabsTrigger>
          <TabsTrigger value="m">Biến động</TabsTrigger>
        </TabsList>
        <TabsContent value="b">
          <List
            title="Tồn kho"
            rows={d.products.map((x) => [
              x.name,
              x.sku,
              `${x.stock_quantity} ${x.unit}`,
            ])}
          />
        </TabsContent>
        <TabsContent value="m">
          <List
            title="Biến động"
            rows={d.moves.map((x) => [
              x.products?.name,
              dt(x.created_at),
              x.quantity_change,
            ])}
          />
        </TabsContent>
      </Tabs>
    </P>
  );
}
function Lines({ v, setV, price = "selling_price", showManualCode = false }) {
  const d = useD();
  return (
    <div className="space-y-2">
      <Button
        type="button"
        variant="outline"
        onClick={() => {
          const p = d.products[0];
          p &&
            setV([
              ...v,
              {
                product_id: p.id,
                quantity: 1,
                unit_price: +p[price],
                manual_code: "",
              },
            ]);
        }}
      >
        <Plus />
        Thêm sản phẩm
      </Button>
      {v.map((x, i) => (
        <div
          className={cn(
            "grid gap-2",
            showManualCode
              ? "grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_40px] sm:grid-cols-[minmax(130px,1fr)_100px_80px_110px_40px]"
              : "grid-cols-[minmax(130px,1fr)_80px_110px_40px]",
          )}
          key={i}
        >
          <Select
            value={x.product_id}
            onValueChange={(id) => {
              const p = d.products.find((y) => y.id === id);
              setV(
                v.map((y, n) =>
                  n === i ? { ...y, product_id: id, unit_price: +p[price] } : y,
                ),
              );
            }}
          >
            <SelectTrigger
              className={
                showManualCode ? "col-span-4 sm:col-span-1" : undefined
              }
            >
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {d.products.map((p) => (
                <SelectItem value={p.id} key={p.id}>
                  {p.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {showManualCode && (
            <Input
              value={x.manual_code || ""}
              maxLength={50}
              placeholder="Mã số"
              aria-label="Mã số tùy chọn"
              onChange={(event) =>
                setV(
                  v.map((item, index) =>
                    index === i
                      ? { ...item, manual_code: event.target.value }
                      : item,
                  ),
                )
              }
            />
          )}
          <Input
            type="text"
            inputMode="numeric"
            placeholder="Số lượng"
            value={formatQuantity(x.quantity)}
            onChange={(e) =>
              setV(
                v.map((y, n) =>
                  n === i
                    ? {
                        ...y,
                        quantity:
                          Number(e.target.value.replaceAll(",", "")) || "",
                      }
                    : y,
                ),
              )
            }
          />
          <Input
            type="text"
            inputMode="numeric"
            placeholder="Đơn giá"
            value={formatQuantity(x.unit_price)}
            onChange={(e) =>
              setV(
                v.map((y, n) =>
                  n === i
                    ? {
                        ...y,
                        unit_price:
                          Number(e.target.value.replaceAll(",", "")) || "",
                      }
                    : y,
                ),
              )
            }
          />
          <Button
            type="button"
            size="icon"
            variant="ghost"
            onClick={() => setV(v.filter((_, n) => n !== i))}
          >
            <Trash2 />
          </Button>
        </div>
      ))}
    </div>
  );
}
function PlateEditDialog({ open, onClose, setOpen, target, voucher }) {
  const d = useD(),
    [plate, setPlate] = useState(""),
    [err, setErr] = useState(""),
    [saving, setSaving] = useState(false);

  const effectiveTarget =
    target ||
    (voucher
      ? {
          voucherId: voucher.id,
          plate: voucher.vehicle_plate || "",
          code: voucher.voucher_code,
        }
      : null);

  const handleClose = () => {
    if (onClose) onClose();
    if (setOpen) setOpen(false);
  };

  useEffect(() => {
    if (open && effectiveTarget) {
      setPlate(effectiveTarget.plate || "");
      setErr("");
    }
  }, [open, effectiveTarget]);

  async function handleSave(ev) {
    ev.preventDefault();
    const raw = plate.trim();
    if (raw && !isValidVehiclePlate(raw)) {
      setErr("Biển số không đúng định dạng, ví dụ: 51C - 111.11");
      return;
    }
    setErr("");
    const normalized = raw ? formatVehiclePlate(raw) : null;

    setSaving(true);
    const ok = await d.run(async () => {
      // 1. Thử gọi RPC update_outbound_vehicle_plate (vượt qua RLS, hỗ trợ mọi trạng thái)
      let rpcOk = false;
      try {
        const rpcRes = await supabase.rpc("update_outbound_vehicle_plate", {
          p_voucher_id: effectiveTarget?.voucherId || null,
          p_vehicle_plate: normalized,
          p_invoice_id: effectiveTarget?.invoiceId || null,
        });
        if (!rpcRes.error) {
          rpcOk = true;
        } else {
          console.warn("RPC failed, trying direct update:", rpcRes.error);
        }
      } catch (e) {
        console.warn("RPC error:", e);
      }

      if (rpcOk) return;

      // 2. Fallback cập nhật trực tiếp qua Supabase client
      let rowsUpdated = 0;
      if (effectiveTarget?.voucherId) {
        const directRes = await supabase
          .from("outbound_vouchers")
          .update({ vehicle_plate: normalized })
          .eq("id", effectiveTarget.voucherId)
          .select("id");
        if (directRes.error) throw directRes.error;
        if (directRes.data?.length) rowsUpdated += directRes.data.length;
      }

      if (effectiveTarget?.invoiceId) {
        try {
          const invRes = await supabase
            .from("invoices")
            .update({ vehicle_plate: normalized })
            .eq("id", effectiveTarget.invoiceId)
            .select("id");
          if (invRes.data?.length) rowsUpdated += invRes.data.length;
        } catch {
          // Bỏ qua nếu bảng invoices chưa có cột vehicle_plate
        }
      }

      if (rowsUpdated === 0) {
        throw new Error(
          "Cơ sở dữ liệu đang khóa cập nhật chứng từ này do chưa phân quyền hoặc chứng từ đã khóa. Vui lòng chạy file migration SQL trên Supabase SQL Editor để mở quyền cho mọi trạng thái."
        );
      }
    }, "Đã cập nhật biển số xe thành công.");
    setSaving(false);
    if (ok) handleClose();
  }

  return (
    <Dialog open={open} onOpenChange={(val) => !val && handleClose()}>
      <DialogContent className="sm:max-w-md">
        <form onSubmit={handleSave} className="space-y-4">
          <DialogHeader>
            <DialogTitle>
              Cập nhật biển số xe giao hàng
              {effectiveTarget?.code ? ` (${effectiveTarget.code})` : ""}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Label htmlFor="plate-input">Biển số xe</Label>
            <Input
              id="plate-input"
              value={plate}
              onChange={(e) => {
                setErr("");
                setPlate(e.target.value.toUpperCase());
              }}
              placeholder="Ví dụ: 51C - 111.11"
              maxLength={20}
              autoFocus
            />
            {err && <p className="text-xs text-destructive">{err}</p>}
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              disabled={saving}
              onClick={handleClose}
            >
              Hủy
            </Button>
            <Button type="submit" disabled={saving}>
              {saving ? "Đang lưu…" : "Lưu"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function TxForm({ open, setOpen, kind }) {
  const d = useD(),
    [partner, setPartner] = useState(""),
    [lines, setLines] = useState([]),
    [confirm, setConfirm] = useState(false),
    [vehiclePlate, setVehiclePlate] = useState(""),
    [vehicleError, setVehicleError] = useState("");
  const people = kind === "in" ? d.suppliers : d.customers;

  useEffect(() => {
    if (open) {
      setPartner(people[0]?.id || "");
      setLines([
        { product_id: "", quantity: 1, unit_price: 0, manual_code: "" },
      ]);
      setConfirm(false);
      setVehiclePlate("");
      setVehicleError("");
    }
  }, [open]);

  async function save(e) {
    e.preventDefault();
    const rawPlate = vehiclePlate.trim();
    if (kind === "out" && rawPlate !== "" && !isValidVehiclePlate(rawPlate)) {
      setVehicleError("Biển số không đúng định dạng, ví dụ: 51C - 111.11");
      return;
    }
    setVehicleError("");
    const normalizedPlate = rawPlate ? formatVehiclePlate(rawPlate) : "";
    const saved = await d.run(
      async () => {
        const partnerId = partner || people[0]?.id;
        if (!partnerId)
          throw new Error(
            `Vui lòng thêm và chọn ${kind === "in" ? "nhà cung cấp" : "khách hàng"}.`,
          );
        validLines(lines);
        const wh = await supabase
          .from("warehouses")
          .select("id")
          .eq("is_active", true)
          .limit(1)
          .maybeSingle();
        if (wh.error) throw wh.error;
        if (!wh.data) throw new Error("Chưa có kho đang hoạt động.");
        const payload = {
          voucher_date: new Date().toISOString().slice(0, 10),
          warehouse_id: wh.data.id,
          [kind === "in" ? "supplier_id" : "customer_id"]: partnerId,
          note: "",
          discount_amount: 0,
          ...(kind === "out" && normalizedPlate
            ? { vehicle_plate: normalizedPlate }
            : {}),
          items: lines.map((x) => ({
            ...x,
            requested_quantity: x.quantity,
            actual_quantity: x.quantity,
          })),
        };
        const r = await supabase.rpc(
          kind === "in"
            ? "create_inbound_draft_v2"
            : "create_outbound_draft_v2",
          { p_payload: payload },
        );
        if (r.error) throw r.error;
        if (kind === "out") {
          for (const item of lines) {
            const manualCode = item.manual_code?.trim();
            if (!manualCode) continue;
            const updatedItem = await supabase
              .from("outbound_items")
              .update({ manual_code: manualCode })
              .eq("voucher_id", r.data.id)
              .eq("product_id", item.product_id);
            if (updatedItem.error) throw updatedItem.error;
          }
          if (normalizedPlate) {
            const updatedVoucher = await supabase
              .from("outbound_vouchers")
              .update({ vehicle_plate: normalizedPlate })
              .eq("id", r.data.id)
              .eq("status", "draft")
              .select("id, vehicle_plate")
              .maybeSingle();
            if (updatedVoucher.error) throw updatedVoucher.error;
            if (!updatedVoucher.data)
              throw new Error("Không thể lưu biển số xe vào phiếu xuất nháp.");
          }
        }
        if (confirm) {
          const c = await supabase.rpc(
            kind === "in"
              ? "confirm_inbound_voucher"
              : "confirm_outbound_voucher",
            { p_voucher_id: r.data.id },
          );
          if (c.error) throw c.error;
          if (kind === "out") {
            await issueInvoiceForOutbound(r.data.id, d);
          }
        }
      },
      confirm
        ? kind === "out"
          ? "Đã xác nhận phiếu xuất và phát hành hóa đơn."
          : "Đã xác nhận và cập nhật tồn kho."
        : "Đã lưu bản nháp.",
    );
    if (saved) setOpen(false);
  }
  return (
    <Modal
      open={open}
      setOpen={setOpen}
      title={kind === "in" ? "Phiếu nhập kho" : "Phiếu xuất kho"}
      save={save}
    >
      {people.length ? (
        <F l={kind === "in" ? "Nhà cung cấp" : "Khách hàng"} required>
          <Select value={partner || people[0].id} onValueChange={setPartner}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {people.map((x) => (
                <SelectItem key={x.id} value={x.id}>
                  {x.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </F>
      ) : (
        <p className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
          Chưa có đối tác. Hãy thêm đối tác trước khi lập phiếu.
        </p>
      )}
      {kind === "out" && (
        <F l="Biển số xe giao hàng" error={vehicleError}>
          <Input
            value={vehiclePlate}
            onChange={(event) => {
              setVehiclePlate(event.target.value.toUpperCase());
              if (vehicleError) setVehicleError("");
            }}
            placeholder="Ví dụ: 51C - 111.11"
            maxLength={20}
            autoCapitalize="characters"
            aria-invalid={Boolean(vehicleError)}
          />
        </F>
      )}
      <Lines
        v={lines}
        setV={setLines}
        price={kind === "in" ? "purchase_price" : "selling_price"}
        showManualCode={kind === "out"}
      />
      <div className="flex items-center gap-2">
        <Checkbox checked={confirm} onCheckedChange={setConfirm} />
        <Label>Xác nhận ngay</Label>
      </div>
    </Modal>
  );
}
function Docs() {
  const d = useD(),
    [open, setOpen] = useState(false),
    [plateTarget, setPlateTarget] = useState(null);
  const invoicedIds = new Set(
    d.invoices.map((invoice) => invoice.outbound_voucher_id).filter(Boolean),
  );
  return (
    <P
      t="Phiếu xuất kho"
      d="Lập, xác nhận và in phiếu xuất"
      a={
        <Button onClick={() => setOpen(true)}>
          <Plus />
          Lập phiếu
        </Button>
      }
    >
      <div className="grid gap-4 lg:grid-cols-2">
        {d.outs.map((x) => (
          <Card key={x.id}>
            <CardHeader>
              <div className="flex justify-between">
                <CardTitle>{x.voucher_code}</CardTitle>
                <Status v={x.status} />
              </div>
              <CardDescription>
                {d.customers.find((c) => c.id === x.customer_id)?.name ||
                  "Khách hàng không còn tồn tại"}{" "}
                · {dt(x.voucher_date)}
              </CardDescription>
              {x.vehicle_plate ? (
                <div className="flex items-center justify-between rounded-md bg-muted/60 px-2.5 py-1 text-sm font-semibold">
                  <div className="flex items-center gap-2">
                    <Truck className="size-4 text-primary" />
                    <span>Biển số xe: {formatVehiclePlate(x.vehicle_plate)}</span>
                  </div>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-6 px-1.5 text-xs text-muted-foreground hover:text-foreground"
                    title="Sửa biển số xe"
                    onClick={() =>
                      setPlateTarget({
                        voucherId: x.id,
                        plate: x.vehicle_plate || "",
                        code: x.voucher_code,
                      })
                    }
                  >
                    <Pencil className="size-3" />
                  </Button>
                </div>
              ) : (
                <div className="flex items-center justify-between text-xs text-muted-foreground">
                  <span className="italic">Chưa có biển số xe</span>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-6 px-1.5 text-xs text-primary"
                    onClick={() =>
                      setPlateTarget({
                        voucherId: x.id,
                        plate: "",
                        code: x.voucher_code,
                      })
                    }
                  >
                    <Plus className="mr-1 size-3" /> Thêm biển số
                  </Button>
                </div>
              )}
            </CardHeader>
            <CardContent className="text-lg font-bold">
              {cash(x.total_amount)}
            </CardContent>
            <CardFooter className="justify-end gap-2">
              {x.status === "draft" && (
                <>
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button variant="destructive">
                        <Trash2 />
                        Xóa nháp
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>
                          Xóa phiếu xuất nháp?
                        </AlertDialogTitle>
                        <AlertDialogDescription>
                          Phiếu {x.voucher_code} và toàn bộ sản phẩm trong phiếu
                          sẽ bị xóa. Thao tác này không thể hoàn tác.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Hủy</AlertDialogCancel>
                        <AlertDialogAction
                          variant="destructive"
                          onClick={() =>
                            d.run(async () => {
                              const { data, error } = await supabase
                                .from("outbound_vouchers")
                                .delete()
                                .eq("id", x.id)
                                .eq("status", "draft")
                                .select("id");
                              if (error) throw error;
                              if (!data?.length)
                                throw new Error(
                                  "Chỉ có thể xóa phiếu xuất đang ở trạng thái bản nháp.",
                                );
                            }, "Đã xóa phiếu xuất nháp.")
                          }
                        >
                          Xóa phiếu
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                  <Button
                    onClick={() =>
                      d.run(async () => {
                        const { error } = await supabase.rpc(
                          "confirm_outbound_voucher",
                          { p_voucher_id: x.id },
                        );
                        if (error) throw error;
                        await issueInvoiceForOutbound(x.id, d);
                      }, "Đã xác nhận phiếu xuất và phát hành hóa đơn.")
                    }
                  >
                    Xác nhận & tạo hóa đơn
                  </Button>
                </>
              )}
              {x.status === "confirmed" && !invoicedIds.has(x.id) && (
                <Button
                  onClick={() =>
                    d.run(
                      () => issueInvoiceForOutbound(x.id, d),
                      "Đã phát hành hóa đơn từ phiếu xuất.",
                    )
                  }
                >
                  Tạo hóa đơn
                </Button>
              )}
              {invoicedIds.has(x.id) && (
                <Button variant="outline" asChild>
                  <NavLink to="/invoices">Mở hóa đơn</NavLink>
                </Button>
              )}
              <Button
                variant="secondary"
                onClick={() => previewOutboundPdf(x, d)}
              >
                Xem trước
              </Button>
              <Button
                variant="outline"
                onClick={() => downloadOutboundPdf(x, d)}
              >
                In / Xuất PDF
              </Button>
            </CardFooter>
          </Card>
        ))}
      </div>
      {!d.outs.length && <Empty />}
      <TxForm open={open} setOpen={setOpen} kind="out" />
      <PlateEditDialog
        open={Boolean(plateTarget)}
        onClose={() => setPlateTarget(null)}
        target={plateTarget}
      />
    </P>
  );
}
function Orders() {
  const d = useD(),
    [open, setOpen] = useState(false),
    [lines, setLines] = useState([]),
    [customer, setCustomer] = useState("");
  async function save(e) {
    e.preventDefault();
    await d.run(async () => {
      const customerId = customer || d.customers[0]?.id;
      if (!customerId) throw new Error("Vui lòng thêm và chọn khách hàng.");
      validLines(lines);
      const { error } = await supabase.rpc("create_sales_order_draft", {
        p_customer_id: customerId,
        p_expected_delivery_date: null,
        p_delivery_address: "",
        p_note: "",
        p_discount_amount: 0,
        p_items: lines,
      });
      if (error) throw error;
    }, "Đã tạo đơn.");
    setOpen(false);
  }
  return (
    <P
      t="Đơn bán hàng"
      d="Theo dõi tiến độ giao"
      a={
        <Button onClick={() => setOpen(true)}>
          <Plus />
          Tạo đơn
        </Button>
      }
    >
      <div className="grid gap-4 lg:grid-cols-2">
        {d.orders.map((o) => {
          const all = o.sales_order_items.reduce(
              (a, x) => a + +x.ordered_quantity,
              0,
            ),
            done = o.sales_order_items.reduce(
              (a, x) => a + +x.fulfilled_quantity,
              0,
            );
          return (
            <Card key={o.id}>
              <CardHeader>
                <div className="flex justify-between">
                  <CardTitle>{o.order_code}</CardTitle>
                  <Status v={o.status} />
                </div>
                <CardDescription>
                  {d.customers.find((x) => x.id === o.customer_id)?.name}
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Progress value={all ? (done / all) * 100 : 0} />
                <p className="mt-2 text-xs">
                  Đã xuất {done}/{all}
                </p>
              </CardContent>
              <CardFooter className="justify-end gap-2">
                {o.status === "draft" && (
                  <>
                    <Button
                      variant="destructive"
                      onClick={() =>
                        d.run(async () => {
                          const { error } = await supabase.rpc(
                            "delete_sales_order_draft",
                            { p_sales_order_id: o.id },
                          );
                          if (error) throw error;
                        }, "Đã xóa đơn.")
                      }
                    >
                      Xóa
                    </Button>
                    <Button
                      onClick={() =>
                        d.run(async () => {
                          const { error } = await supabase.rpc(
                            "confirm_sales_order",
                            { p_sales_order_id: o.id },
                          );
                          if (error) throw error;
                        }, "Đã xác nhận.")
                      }
                    >
                      Xác nhận
                    </Button>
                  </>
                )}
              </CardFooter>
            </Card>
          );
        })}
      </div>
      <Modal open={open} setOpen={setOpen} title="Tạo đơn bán hàng" save={save}>
        <F l="Khách hàng" required>
          <Select
            value={customer || d.customers[0]?.id}
            onValueChange={setCustomer}
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {d.customers.map((x) => (
                <SelectItem key={x.id} value={x.id}>
                  {x.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </F>
        <Lines v={lines} setV={setLines} />
      </Modal>
    </P>
  );
}
function Invoices() {
  const d = useD(),
    [open, setOpen] = useState(false),
    [plateTarget, setPlateTarget] = useState(null),
    [lines, setLines] = useState([]),
    [customer, setCustomer] = useState("");
  async function save(e) {
    e.preventDefault();
    await d.run(async () => {
      const id = customer || d.customers[0]?.id;
      if (!id) throw new Error("Vui lòng thêm và chọn khách hàng.");
      validLines(lines);
      const { error } = await supabase.rpc("create_invoice_draft", {
        p_customer_id: id,
        p_outbound_voucher_id: null,
        p_discount_amount: 0,
        p_items: lines.map((x) => ({
          ...x,
          description: d.products.find((p) => p.id === x.product_id)?.name,
        })),
      });
      if (error) throw error;
    }, "Đã tạo hóa đơn.");
    setOpen(false);
  }
  return (
    <P
      t="Hóa đơn"
      d="Phát hành và theo dõi thanh toán"
      a={
        <Button onClick={() => setOpen(true)}>
          <Plus />
          Tạo hóa đơn
        </Button>
      }
    >
      <div className="grid gap-4 lg:grid-cols-2">
        {d.invoices.map((x) => {
          const linkedVoucher = d.outs.find(
            (voucher) => voucher.id === x.outbound_voucher_id,
          );
          const currentPlate = linkedVoucher?.vehicle_plate || x.vehicle_plate;
          return (
            <Card key={x.id}>
              <CardHeader>
                <div className="flex justify-between gap-3">
                  <CardTitle>{x.invoice_code}</CardTitle>
                  <div className="flex flex-wrap gap-2">
                    <Status v={x.status} />
                    <Status v={x.payment_status} />
                  </div>
                </div>
                <CardDescription>
                  {d.customers.find((c) => c.id === x.customer_id)?.name ||
                    "Khách hàng không còn tồn tại"}{" "}
                  · {dt(x.invoice_date)}
                </CardDescription>
                {currentPlate ? (
                  <div className="flex items-center justify-between rounded-md bg-muted/60 px-2.5 py-1 text-sm font-semibold">
                    <div className="flex items-center gap-2">
                      <Truck className="size-4 text-primary" />
                      <span>
                        Biển số xe:{" "}
                        {formatVehiclePlate(currentPlate)}
                      </span>
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-6 px-1.5 text-xs text-muted-foreground hover:text-foreground"
                      title="Sửa biển số xe"
                      onClick={() =>
                        setPlateTarget({
                          voucherId: linkedVoucher?.id || x.outbound_voucher_id || null,
                          invoiceId: x.id,
                          plate: currentPlate,
                          code: x.invoice_code,
                        })
                      }
                    >
                      <Pencil className="size-3" />
                    </Button>
                  </div>
                ) : (
                  <div className="flex items-center justify-between text-xs text-muted-foreground">
                    <span className="italic">Chưa có biển số xe</span>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-6 px-1.5 text-xs text-primary"
                      onClick={() =>
                        setPlateTarget({
                          voucherId: linkedVoucher?.id || x.outbound_voucher_id || null,
                          invoiceId: x.id,
                          plate: "",
                          code: x.invoice_code,
                        })
                      }
                    >
                      <Plus className="mr-1 size-3" /> Thêm biển số
                    </Button>
                  </div>
                )}
              </CardHeader>
            <CardContent className="text-xl font-bold">
              {cash(x.total_amount)}
            </CardContent>
            <CardFooter className="flex-wrap justify-end gap-2">
              {x.status === "draft" && (
                <>
                  <Button
                    variant="destructive"
                    onClick={() =>
                      d.run(async () => {
                        const { error } = await supabase
                          .from("invoices")
                          .delete()
                          .eq("id", x.id)
                          .eq("status", "draft");
                        if (error) throw error;
                      }, "Đã xóa hóa đơn nháp.")
                    }
                  >
                    Xóa nháp
                  </Button>
                  <Button
                    onClick={() =>
                      d.run(async () => {
                        const { error } = await supabase.rpc(
                          "finalize_invoice",
                          { p_invoice_id: x.id },
                        );
                        if (error) throw error;
                      }, "Đã phát hành hóa đơn.")
                    }
                  >
                    Phát hành
                  </Button>
                </>
              )}
              {x.status === "finalized" && x.payment_status !== "paid" && (
                <Button
                  onClick={() =>
                    d.run(async () => {
                      const { error } = await supabase.rpc(
                        "mark_invoice_paid",
                        { p_invoice_id: x.id },
                      );
                      if (error) throw error;

                      // Tự động gửi email kèm file PDF hóa đơn tới Gmail quản lý
                      const managerEmail = d.settings?.email?.trim();
                      if (managerEmail) {
                        toast.info(
                          `Đang gửi hóa đơn PDF tới Gmail quản lý (${managerEmail})…`
                        );
                        sendPaidInvoiceEmail(x, d)
                          .then((res) => {
                            if (res.success) {
                              toast.success(
                                `Đã gửi hóa đơn PDF thành công tới ${managerEmail}`
                              );
                            } else {
                              toast.error(
                                `Chưa gửi được email: ${res.error || "Vui lòng kiểm tra lại cấu hình Gmail trên Vercel."}`
                              );
                            }
                          })
                          .catch((err) => {
                            console.warn("Lỗi gửi email:", err);
                            toast.error(`Lỗi gửi email: ${err.message}`);
                          });
                      } else {
                        toast.warning(
                          "Chưa cấu hình Email trong Cài đặt doanh nghiệp để nhận hóa đơn."
                        );
                      }
                    }, "Đã cập nhật trạng thái đã thanh toán.")
                  }
                >
                  Đánh dấu đã thanh toán
                </Button>
              )}
              <Button
                variant="secondary"
                onClick={() => previewInvoicePdf(x, d)}
              >
                Xem trước
              </Button>
              <Button
                variant="outline"
                onClick={() => downloadInvoicePdf(x, d)}
              >
                In / Xuất PDF
              </Button>
            </CardFooter>
          </Card>
          );
        })}
      </div>
      <Modal
        open={open}
        setOpen={setOpen}
        title="Tạo hóa đơn nội bộ"
        save={save}
      >
        {d.customers.length ? (
          <F l="Khách hàng" required>
            <Select
              value={customer || d.customers[0].id}
              onValueChange={setCustomer}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {d.customers.map((x) => (
                  <SelectItem key={x.id} value={x.id}>
                    {x.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </F>
        ) : (
          <p className="text-sm text-destructive">Chưa có khách hàng.</p>
        )}
        <Lines v={lines} setV={setLines} />
      </Modal>
      <PlateEditDialog
        open={Boolean(plateTarget)}
        onClose={() => setPlateTarget(null)}
        target={plateTarget}
      />
    </P>
  );
}
function Partners() {
  const d = useD(),
    [open, setOpen] = useState(false),
    [type, setType] = useState("customers"),
    [e, setE] = useState({}),
    [errors, setErrors] = useState({});
  async function save(ev) {
    ev.preventDefault();
    const f = new FormData(ev.currentTarget),
      raw = validateFields(
        z.object({
          name: personName,
          phone,
          email,
          address: z.string().trim().max(255, "không được vượt quá 255 ký tự"),
          tax: optionalTaxCode,
        }),
        Object.fromEntries(f),
        setErrors,
      );
    if (!raw) return;
    const row = {
      ...e,
      code: e.code || `DT-${Date.now()}`,
      name: raw.name,
      phone: raw.phone,
      email: raw.email,
      address: raw.address,
      tax_code: raw.tax,
    };
    await d.run(async () => {
      const { error } = await supabase.from(type).upsert(row);
      if (error) throw error;
    }, "Đã lưu đối tác.");
    setOpen(false);
  }
  return (
    <P
      t="Đối tác"
      d="Khách hàng và nhà cung cấp"
      a={
        <Button
          onClick={() => {
            setE({});
            setErrors({});
            setOpen(true);
          }}
        >
          <Plus />
          Thêm
        </Button>
      }
    >
      <Tabs value={type} onValueChange={setType}>
        <TabsList>
          <TabsTrigger value="customers">Khách hàng</TabsTrigger>
          <TabsTrigger value="suppliers">Nhà cung cấp</TabsTrigger>
        </TabsList>
        <TabsContent value={type}>
          <div className="grid gap-4 md:grid-cols-2">
            {d[type].map((x) => (
              <Card key={x.id}>
                <CardHeader>
                  <CardTitle>{x.name}</CardTitle>
                  <CardDescription>
                    {x.phone || "—"} · {x.email || "—"}
                  </CardDescription>
                </CardHeader>
                <CardContent className="text-sm">
                  {x.address || "Chưa có địa chỉ"}
                </CardContent>
                <CardFooter className="justify-end gap-2">
                  <Button
                    variant="outline"
                    onClick={() => {
                      setE(x);
                      setErrors({});
                      setOpen(true);
                    }}
                  >
                    Chỉnh sửa
                  </Button>
                  <Button
                    variant="destructive"
                    onClick={() =>
                      d.run(async () => {
                        const { error } = await supabase
                          .from(type)
                          .delete()
                          .eq("id", x.id);
                        if (error) throw error;
                      }, "Đã xóa đối tác.")
                    }
                  >
                    Xóa
                  </Button>
                </CardFooter>
              </Card>
            ))}
          </div>
        </TabsContent>
      </Tabs>
      <Modal open={open} setOpen={setOpen} title="Đối tác" save={save}>
        {[
          ["Tên", "name", true, "text"],
          ["Điện thoại", "phone", true, "tel"],
          ["Email", "email", false, "email"],
          ["Địa chỉ", "address", false, "text"],
          ["Mã số thuế", "tax", false, "text"],
        ].map(([l, n, isRequired, inputType]) => (
          <F l={l} key={n} required={isRequired} error={errors[n]}>
            <Input
              name={n}
              type={inputType}
              inputMode={n === "phone" || n === "tax" ? "numeric" : undefined}
              defaultValue={n === "tax" ? e.tax_code : e[n]}
              aria-invalid={Boolean(errors[n])}
            />
          </F>
        ))}
      </Modal>
    </P>
  );
}
function Reports() {
  const d = useD(),
    rev = d.invoices.reduce(
      (a, x) => a + (x.status === "finalized" ? +x.total_amount : 0),
      0,
    );
  return (
    <P t="Báo cáo" d="Tổng hợp kinh doanh">
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader>
            <CardDescription>Doanh thu</CardDescription>
            <CardTitle>{cash(rev)}</CardTitle>
          </CardHeader>
        </Card>
        <Card>
          <CardHeader>
            <CardDescription>Giá trị tồn</CardDescription>
            <CardTitle>
              {cash(
                d.products.reduce(
                  (a, x) => a + +x.stock_quantity * +x.purchase_price,
                  0,
                ),
              )}
            </CardTitle>
          </CardHeader>
        </Card>
        <Card>
          <CardHeader>
            <CardDescription>Đơn hàng</CardDescription>
            <CardTitle>{d.orders.length}</CardTitle>
          </CardHeader>
        </Card>
      </div>
    </P>
  );
}
function Profile() {
  const d = useD(),
    displayName = d.profile?.full_name || "Nhân viên",
    initials = displayName
      .split(" ")
      .slice(-2)
      .map((part) => part[0])
      .join("")
      .toUpperCase();
  return (
    <P t="Thông tin cá nhân" d="Tài khoản đang đăng nhập">
      <Card className="overflow-hidden">
        <div className="h-24 bg-gradient-to-r from-slate-950 to-slate-800" />
        <CardContent className="relative px-5 pb-5">
          <Avatar className="-mt-10 size-20 border-4 border-background shadow-sm">
            <AvatarFallback className="bg-primary text-lg font-bold text-primary-foreground">
              {initials || "NV"}
            </AvatarFallback>
          </Avatar>
          <h2 className="mt-3 text-xl font-bold">{displayName}</h2>
          <p className="text-sm text-muted-foreground">
            {d.session.user.email}
          </p>
          <div className="mt-6 grid gap-4 text-sm">
            <div className="flex items-center justify-between border-b pb-4">
              <span className="text-muted-foreground">Tên đăng nhập</span>
              <span className="font-medium">{d.profile?.username || "—"}</span>
            </div>
            <div className="flex items-center justify-between border-b pb-4">
              <span className="text-muted-foreground">Vai trò</span>
              <span className="font-medium">{d.profile?.role || "—"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Trạng thái</span>
              <Badge
                variant="outline"
                className="border-emerald-200 bg-emerald-50 text-emerald-700"
              >
                Đang hoạt động
              </Badge>
            </div>
          </div>
        </CardContent>
      </Card>
      <div className="grid gap-3">
        <Button variant="outline" className="h-12 justify-start" asChild>
          <NavLink to="/settings">
            <Settings /> Cài đặt doanh nghiệp
          </NavLink>
        </Button>
        <Button
          variant="destructive"
          className="h-12 justify-start"
          onClick={() => supabase.auth.signOut()}
        >
          <LogOut /> Đăng xuất
        </Button>
      </div>
    </P>
  );
}
function ChangePasswordCard() {
  const d = useD(),
    [oldPassword, setOldPassword] = useState(""),
    [newPassword, setNewPassword] = useState(""),
    [confirmPassword, setConfirmPassword] = useState(""),
    [showOld, setShowOld] = useState(false),
    [showNew, setShowNew] = useState(false),
    [showConfirm, setShowConfirm] = useState(false),
    [errors, setErrors] = useState({}),
    [loading, setLoading] = useState(false);

  async function handleChangePassword(e) {
    e.preventDefault();
    const val = validateFields(
      z
        .object({
          oldPassword: z.string().min(1, "không được để trống"),
          newPassword: z.string().min(8, "mật khẩu mới phải có ít nhất 8 ký tự"),
          confirmPassword: z.string().min(1, "không được để trống"),
        })
        .refine((data) => data.newPassword === data.confirmPassword, {
          message: "Mật khẩu xác nhận không khớp",
          path: ["confirmPassword"],
        })
        .refine((data) => data.oldPassword !== data.newPassword, {
          message: "Mật khẩu mới không được trùng với mật khẩu hiện tại",
          path: ["newPassword"],
        }),
      { oldPassword, newPassword, confirmPassword },
      setErrors,
    );
    if (!val) return;

    setLoading(true);
    await d.run(async () => {
      const email = d.session?.user?.email;
      if (email) {
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email,
          password: val.oldPassword,
        });
        if (signInError) {
          throw new Error("Mật khẩu hiện tại không chính xác.");
        }
      }

      const { error: updateError } = await supabase.auth.updateUser({
        password: val.newPassword,
      });
      if (updateError) throw updateError;

      setOldPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setErrors({});
    }, "Đổi mật khẩu thành công!");
    setLoading(false);
  }

  return (
    <Card className="mt-6 border-slate-200 shadow-sm">
      <CardHeader>
        <div className="flex items-center gap-2.5">
          <div className="grid size-9 place-items-center rounded-xl bg-primary/10 text-primary">
            <KeyRound className="size-5" />
          </div>
          <div>
            <CardTitle className="text-lg">Đổi mật khẩu</CardTitle>
            <CardDescription>
              Cập nhật mật khẩu tài khoản của bạn để tăng cường tính bảo mật.
            </CardDescription>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleChangePassword} className="max-w-xl space-y-4">
          <F l="Mật khẩu hiện tại" required error={errors.oldPassword}>
            <div className="relative">
              <Input
                type={showOld ? "text" : "password"}
                value={oldPassword}
                onChange={(e) => setOldPassword(e.target.value)}
                placeholder="Nhập mật khẩu đang sử dụng"
                className="pr-10"
                aria-invalid={Boolean(errors.oldPassword)}
              />
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="absolute right-1 top-1 size-8 text-muted-foreground hover:text-foreground"
                onClick={() => setShowOld((v) => !v)}
              >
                {showOld ? (
                  <EyeOff className="size-4" />
                ) : (
                  <Eye className="size-4" />
                )}
              </Button>
            </div>
          </F>

          <F l="Mật khẩu mới" required error={errors.newPassword}>
            <div className="relative">
              <Input
                type={showNew ? "text" : "password"}
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                placeholder="Tối thiểu 8 ký tự"
                className="pr-10"
                aria-invalid={Boolean(errors.newPassword)}
              />
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="absolute right-1 top-1 size-8 text-muted-foreground hover:text-foreground"
                onClick={() => setShowNew((v) => !v)}
              >
                {showNew ? (
                  <EyeOff className="size-4" />
                ) : (
                  <Eye className="size-4" />
                )}
              </Button>
            </div>
          </F>

          <F l="Xác nhận mật khẩu mới" required error={errors.confirmPassword}>
            <div className="relative">
              <Input
                type={showConfirm ? "text" : "password"}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="Nhập lại mật khẩu mới"
                className="pr-10"
                aria-invalid={Boolean(errors.confirmPassword)}
              />
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="absolute right-1 top-1 size-8 text-muted-foreground hover:text-foreground"
                onClick={() => setShowConfirm((v) => !v)}
              >
                {showConfirm ? (
                  <EyeOff className="size-4" />
                ) : (
                  <Eye className="size-4" />
                )}
              </Button>
            </div>
          </F>

          <Button type="submit" disabled={loading} className="gap-2">
            <KeyRound className="size-4" />
            {loading ? "Đang cập nhật…" : "Cập nhật mật khẩu"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}

function Prefs() {
  const d = useD(),
    [errors, setErrors] = useState({});
  async function save(e) {
    e.preventDefault();
    const f = validateFields(
      z.object({
        business_name: personName,
        company_short_name: z
          .string()
          .trim()
          .max(50, "không được vượt quá 50 ký tự"),
        tax_code: optionalTaxCode,
        representative_name: z
          .string()
          .trim()
          .refine(
            (value) => value === "" || /^[\p{L}\s.'-]+$/u.test(value),
            "chỉ được chứa chữ và khoảng trắng",
          ),
        phone,
        email: z.string().trim().email("không đúng định dạng email"),
        address: required.max(255, "không được vượt quá 255 ký tự"),
        website: z
          .string()
          .trim()
          .refine(
            (value) => value === "" || /^https?:\/\//.test(value),
            "phải bắt đầu bằng http:// hoặc https://",
          ),
        bank_name: z.string().trim().max(100, "không được vượt quá 100 ký tự"),
        bank_account_number: z
          .string()
          .trim()
          .refine(
            (value) => value === "" || /^\d{6,20}$/.test(value),
            "phải gồm từ 6 đến 20 chữ số",
          ),
      }),
      Object.fromEntries(new FormData(e.currentTarget)),
      setErrors,
    );
    if (!f) return;
    await d.run(async () => {
      const { error } = await supabase
        .from("business_settings")
        .upsert({ ...d.settings, ...f, updated_at: new Date().toISOString() });
      if (error) throw error;
    }, "Đã lưu cài đặt.");
  }
  return (
    <P t="Cài đặt" d="Thông tin doanh nghiệp và tài khoản">
      <Card className="border-slate-200 shadow-sm">
        <CardHeader>
          <CardTitle className="text-lg">Thông tin doanh nghiệp</CardTitle>
          <CardDescription>
            Cấu hình thông tin pháp lý, liên hệ và ngân hàng hiển thị trên chứng
            từ.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={save} className="grid gap-4 md:grid-cols-2">
            {[
              ["Tên doanh nghiệp", "business_name", true, "text"],
              ["Tên viết tắt", "company_short_name", false, "text"],
              ["Mã số thuế", "tax_code", false, "text"],
              ["Người đại diện", "representative_name", false, "text"],
              ["Điện thoại", "phone", true, "tel"],
              ["Email", "email", true, "email"],
              ["Địa chỉ", "address", true, "text"],
              ["Website", "website", false, "url"],
              ["Ngân hàng", "bank_name", false, "text"],
              ["Số tài khoản", "bank_account_number", false, "text"],
            ].map(([l, n, isRequired, inputType]) => (
              <F l={l} key={n} required={isRequired} error={errors[n]}>
                <Input
                  name={n}
                  type={inputType}
                  inputMode={
                    n === "phone" ||
                    n === "tax_code" ||
                    n === "bank_account_number"
                      ? "numeric"
                      : undefined
                  }
                  defaultValue={d.settings[n]}
                  aria-invalid={Boolean(errors[n])}
                />
              </F>
            ))}
            <div className="md:col-span-2">
              <Button>Lưu cài đặt</Button>
            </div>
          </form>
        </CardContent>
      </Card>

      <ChangePasswordCard />
    </P>
  );
}
export default App;
