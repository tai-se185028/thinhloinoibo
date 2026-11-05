import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL;
const key =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
  import.meta.env.VITE_SUPABASE_ANON_KEY;
export const configured = Boolean(url && key);
export const supabase = configured
  ? createClient(url, key, {
      auth: { persistSession: true, detectSessionInUrl: true },
    })
  : null;

export function message(error) {
  const value = error?.message || String(error || "");
  const code = String(error?.code || error?.status || "").toLowerCase();
  const normalized = value.toLowerCase();
  const known = {
    INSUFFICIENT_STOCK: "Tồn kho không đủ để xác nhận phiếu xuất.",
    ALREADY_CONFIRMED: "Chứng từ đã được xác nhận trước đó.",
    EMPTY_VOUCHER: "Phiếu phải có ít nhất một sản phẩm.",
    EMPTY_DISPATCH:
      "Phiếu xuất phải có ít nhất một sản phẩm có số lượng thực xuất.",
    INVALID_ACTUAL_QUANTITY:
      "Số lượng thực xuất phải lớn hơn 0 và không vượt số lượng yêu cầu.",
    INVALID_DISCOUNT: "Giảm giá không hợp lệ hoặc vượt quá giá trị hàng hóa.",
    INVALID_SALES_ORDER:
      "Đơn bán hàng không hợp lệ hoặc không thuộc khách hàng đã chọn.",
    ORDER_QUANTITY_EXCEEDED:
      "Số lượng xuất vượt quá số lượng còn lại của đơn hàng.",
    OUTBOUND_ALREADY_INVOICED: "Phiếu xuất này đã được lập hóa đơn.",
    INVOICE_NOT_DRAFT: "Chỉ hóa đơn nháp mới có thể phát hành.",
    SALES_ORDER_NOT_DRAFT: "Chỉ có thể xóa đơn bán hàng nháp.",
    INVALID_QUANTITY: "Số lượng nhập không hợp lệ.",
    PRODUCT_NAME_AND_SKU_REQUIRED: "Tên hoặc mã sản phẩm không hợp lệ.",
    PRODUCT_NOT_FOUND:
      "Không tìm thấy sản phẩm hoặc sản phẩm đã ngừng sử dụng.",
    UNAUTHORIZED: "Bạn không có quyền thực hiện thao tác này.",
  };
  for (const [code, text] of Object.entries(known))
    if (value.includes(code)) return text;
  const authErrors = {
    invalid_credentials: "Tên đăng nhập, email hoặc mật khẩu không đúng.",
    email_not_confirmed: "Email chưa được xác nhận. Vui lòng kiểm tra hộp thư.",
    user_not_found: "Không tìm thấy tài khoản này.",
    user_banned: "Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.",
    weak_password: "Mật khẩu chưa đủ mạnh. Mật khẩu phải có ít nhất 8 ký tự.",
    email_exists: "Email này đã được sử dụng bởi tài khoản khác.",
    identity_already_exists:
      "Tài khoản Google đã được liên kết với người dùng khác.",
    provider_disabled: "Đăng nhập Google chưa được cấu hình.",
    over_email_send_rate_limit:
      "Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau.",
    session_not_found: "Phiên đăng nhập không tồn tại. Vui lòng đăng nhập lại.",
    refresh_token_not_found:
      "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.",
    bad_jwt: "Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.",
    jwt_expired: "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.",
    validation_failed: "Thông tin nhập chưa hợp lệ. Vui lòng kiểm tra lại.",
  };
  if (authErrors[code]) return authErrors[code];
  if (normalized.includes("invalid login credentials"))
    return authErrors.invalid_credentials;
  if (normalized.includes("email not confirmed"))
    return authErrors.email_not_confirmed;
  if (
    normalized.includes("failed to fetch") ||
    normalized.includes("network") ||
    normalized.includes("connection") ||
    code === "fetch_error"
  )
    return "Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.";
  if (normalized.includes("edge function") || normalized.includes("non-2xx"))
    return "Không thể xử lý yêu cầu đăng nhập lúc này. Vui lòng kiểm tra thông tin và thử lại.";
  if (normalized.includes("timeout"))
    return "Yêu cầu mất quá nhiều thời gian. Vui lòng thử lại.";
  if (error?.code === "42501")
    return "Bạn không có quyền thực hiện thao tác này.";
  if (error?.code === "23502")
    return "Vui lòng nhập đầy đủ các trường bắt buộc.";
  if (error?.code === "23503")
    return "Không thể thay đổi dữ liệu đang được sử dụng.";
  if (error?.code === "23505") return "Mã dữ liệu đã tồn tại.";
  if (error?.code === "22P02") return "Dữ liệu nhập không đúng định dạng.";
  if (/[À-ỹ]/u.test(value)) return value;
  return "Đã xảy ra lỗi khi xử lý yêu cầu. Vui lòng thử lại hoặc liên hệ quản trị viên.";
}
