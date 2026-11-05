import { getInvoicePdfBase64 } from "@/features/documents/pdf";
import { supabase } from "@/lib/supabase";

async function withTimeout(promise, milliseconds, message) {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(message)), milliseconds);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

export async function sendPaidInvoiceEmail(invoice, data) {
  const managerEmail = data.settings?.email?.trim();
  if (!managerEmail) {
    return {
      success: false,
      error: "Chưa cấu hình Email trong Cài đặt doanh nghiệp.",
    };
  }

  const customer =
    data.customers.find((c) => c.id === invoice.customer_id) || {};
  const customerName = customer.name || "";

  let pdfBase64 = null;
  try {
    pdfBase64 = await withTimeout(
      getInvoicePdfBase64(invoice, data),
      30000,
      "Tạo PDF quá thời gian chờ. Vui lòng thử lại.",
    );
  } catch (err) {
    return {
      success: false,
      error: `Không thể tạo PDF đính kèm: ${err.message}`,
    };
  }

  const payload = {
    invoice_id: invoice.id,
    invoice_code: invoice.invoice_code,
    manager_email: managerEmail,
    customer_name: customerName,
    total_amount: invoice.total_amount,
    payment_date: new Date().toLocaleDateString("vi-VN"),
    pdf_base64: pdfBase64,
  };

  // Gửi trực tiếp qua Vercel API của dự án React (/api/send-invoice-email)
  try {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session)
      return { success: false, error: "Vui lòng đăng nhập lại để gửi email." };
    const res = await fetch("/api/send-invoice-email", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${session.access_token}`,
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(45000),
    });
    const json = await res.json().catch(() => ({}));
    if (res.status === 404) {
      return {
        success: false,
        error: import.meta.env.DEV
          ? "API gửi email local chưa chạy. Hãy khởi động lại npm run dev trong thư mục frontend-react."
          : "Chưa triển khai API gửi email trên Vercel. Kiểm tra Root Directory trỏ tới frontend-react và deploy cả thư mục api, sau đó Redeploy.",
      };
    }
    if (res.ok && json.success) {
      return { success: true, data: json };
    }
    return {
      success: false,
      error:
        json.message ||
        `Lỗi phản hồi từ máy chủ (${res.status}): Vui lòng kiểm tra lại cấu hình Gmail trên Vercel.`,
    };
  } catch (err) {
    return {
      success: false,
      error:
        err.name === "TimeoutError" || err.name === "AbortError"
          ? "Máy chủ gửi email quá thời gian chờ. Vui lòng kiểm tra hộp thư trước khi gửi lại."
          : `Không thể kết nối API gửi mail: ${err.message}`,
    };
  }
}
