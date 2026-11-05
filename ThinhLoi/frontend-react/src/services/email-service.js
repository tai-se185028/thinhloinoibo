import { supabase } from "@/lib/supabase";
import { getInvoicePdfBase64 } from "@/features/documents/pdf";

export async function sendPaidInvoiceEmail(invoice, data) {
  const managerEmail = data.settings?.email?.trim();
  if (!managerEmail) {
    return {
      success: false,
      reason: "missing_email",
      error: "Chưa cấu hình Email trong Cài đặt doanh nghiệp.",
    };
  }

  const customer =
    data.customers.find((c) => c.id === invoice.customer_id) || {};
  const customerName = customer.name || "";

  let pdfBase64 = null;
  try {
    pdfBase64 = await getInvoicePdfBase64(invoice, data);
  } catch (err) {
    console.error("Không thể xuất file PDF hóa đơn để đính kèm email:", err);
  }

  const payload = {
    invoice_code: invoice.invoice_code,
    manager_email: managerEmail,
    customer_name: customerName,
    total_amount: invoice.total_amount,
    payment_date: new Date().toLocaleDateString("vi-VN"),
    pdf_base64: pdfBase64,
  };

  // 1. Thử gọi API Vercel Serverless /api/send-invoice-email
  try {
    const res = await fetch("/api/send-invoice-email", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const json = await res.json().catch(() => ({}));
    if (res.ok && json.success) {
      return { success: true, via: "vercel", data: json };
    }
    if (json.message) {
      return { success: false, error: json.message, via: "vercel" };
    }
    if (res.status === 404) {
      console.warn("/api/send-invoice-email trả về 404");
    }
  } catch (err) {
    console.warn("Lỗi khi kết nối tới /api/send-invoice-email:", err);
  }

  // 2. Thử gọi Supabase Edge Function send-invoice-paid-email
  try {
    const { data: edgeRes, error: edgeErr } = await supabase.functions.invoke(
      "send-invoice-paid-email",
      { body: payload }
    );
    if (!edgeErr && edgeRes?.success) {
      return { success: true, via: "supabase", data: edgeRes };
    }
    if (edgeErr?.message) {
      return { success: false, error: edgeErr.message, via: "supabase" };
    }
  } catch (err) {
    console.warn("Lỗi khi gọi Supabase Edge Function:", err);
  }

  return {
    success: false,
    reason: "service_not_configured",
    error:
      "Vercel chưa cập nhật biến môi trường GMAIL_USER và GMAIL_APP_PASSWORD. Bạn cần Redeploy trên Vercel.",
  };
}
