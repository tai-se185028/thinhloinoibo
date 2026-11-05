import { supabase } from "@/lib/supabase";
import { getInvoicePdfBase64 } from "@/features/documents/pdf";

export async function sendPaidInvoiceEmail(invoice, data) {
  const managerEmail = data.settings?.email?.trim();
  if (!managerEmail) {
    return { success: false, reason: "missing_email" };
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
    if (res.ok) {
      const json = await res.json().catch(() => ({}));
      return { success: true, via: "vercel", data: json };
    }
    const errJson = await res.json().catch(() => ({}));
    if (res.status !== 404) {
      console.warn("Vercel email endpoint returned error:", errJson);
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
    if (edgeErr) {
      console.warn("Supabase Edge Function returned error:", edgeErr);
    }
  } catch (err) {
    console.warn("Lỗi khi gọi Supabase Edge Function:", err);
  }

  return { success: false, reason: "service_not_configured" };
}

