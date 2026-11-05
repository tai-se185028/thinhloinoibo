import { Buffer } from "node:buffer";
import process from "node:process";
import nodemailer from "npm:nodemailer@6.9.16";
import { createClient } from "npm:@supabase/supabase-js@2";

const escapeHtml = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );

async function handler(req, res) {
  if (req.method !== "POST")
    return res.status(405).json({ message: "Phương thức không được hỗ trợ." });
  try {
    const token = req.headers.authorization?.match(/^Bearer (.+)$/i)?.[1];
    if (!token)
      return res
        .status(401)
        .json({ message: "Vui lòng đăng nhập để gửi email." });
    const url = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL;
    const key =
      process.env.SUPABASE_ANON_KEY ||
      process.env.VITE_SUPABASE_PUBLISHABLE_KEY;
    if (!url || !key)
      throw new Error("Chưa cấu hình kết nối Supabase cho máy chủ gửi email.");
    const db = createClient(url, key, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false },
    });
    const { data: auth, error: authError } = await db.auth.getUser(token);
    if (authError || !auth.user)
      return res
        .status(401)
        .json({ message: "Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại." });
    const { invoice_id, pdf_base64 } = req.body || {};
    if (!/^[0-9a-f-]{36}$/i.test(invoice_id || ""))
      return res.status(400).json({ message: "Mã hóa đơn không hợp lệ." });
    const [invoiceResult, settingsResult] = await Promise.all([
      db
        .from("invoices")
        .select(
          "id,invoice_code,customer_id,total_amount,status,payment_status",
        )
        .eq("id", invoice_id)
        .single(),
      db
        .from("business_settings")
        .select("email,business_name")
        .limit(1)
        .single(),
    ]);
    if (invoiceResult.error)
      return res
        .status(403)
        .json({ message: "Không thể truy cập hóa đơn này." });
    const invoice = invoiceResult.data;
    if (invoice.status !== "finalized" || invoice.payment_status !== "paid")
      return res
        .status(400)
        .json({
          message:
            "Hóa đơn phải được phát hành và thanh toán trước khi gửi thông báo.",
        });
    const recipient = settingsResult.data?.email?.trim();
    if (
      settingsResult.error ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient || "")
    )
      return res
        .status(400)
        .json({
          message:
            "Vui lòng cấu hình email hợp lệ trong thông tin doanh nghiệp.",
        });
    const user = process.env.GMAIL_USER?.trim();
    const pass = (process.env.GMAIL_APP_PASSWORD || "").replace(/\s/g, "");
    if (!user || !pass)
      throw new Error("Máy chủ chưa cấu hình tài khoản Gmail gửi thông báo.");
    if (
      pdf_base64 &&
      (typeof pdf_base64 !== "string" ||
        pdf_base64.length > 4_000_000 ||
        !pdf_base64.startsWith("JVBERi0"))
    )
      return res
        .status(400)
        .json({
          message: "Tệp PDF không hợp lệ hoặc vượt quá dung lượng cho phép.",
        });
    const { data: customer } = await db
      .from("customers")
      .select("name")
      .eq("id", invoice.customer_id)
      .maybeSingle();
    const amount =
      new Intl.NumberFormat("en-US").format(Number(invoice.total_amount)) +
      " ₫";
    const date = new Date().toLocaleString("vi-VN", {
      timeZone: "Asia/Ho_Chi_Minh",
    });
    const transport = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: { user, pass },
      connectionTimeout: 15000,
      socketTimeout: 20000,
    });
    await transport.sendMail({
      from: { name: "Thịnh Lợi", address: user },
      to: recipient,
      subject: `[Thịnh Lợi] Hóa đơn ${invoice.invoice_code} đã thanh toán`,
      text: `Hóa đơn: ${invoice.invoice_code}\nKhách hàng: ${customer?.name || ""}\nTổng tiền: ${amount}\nTrạng thái: Đã thanh toán\nThời gian gửi: ${date}`,
      html: `<h2>THÔNG BÁO HÓA ĐƠN ĐÃ THANH TOÁN</h2><p>Hóa đơn: <strong>${escapeHtml(invoice.invoice_code)}</strong></p><p>Khách hàng: ${escapeHtml(customer?.name)}</p><p>Tổng tiền: <strong>${escapeHtml(amount)}</strong></p><p>Trạng thái: Đã thanh toán</p><p>Thời gian gửi: ${escapeHtml(date)}</p>`,
      attachments: pdf_base64
        ? [
            {
              filename: `${invoice.invoice_code}.pdf`,
              content: Buffer.from(pdf_base64, "base64"),
              contentType: "application/pdf",
            },
          ]
        : [],
    });
    return res.status(200).json({ success: true, sentTo: recipient });
  } catch (error) {
    const message =
      error.code === "EAUTH"
        ? "Gmail từ chối đăng nhập. Vui lòng kiểm tra mật khẩu ứng dụng trên máy chủ."
        : error.code === "ETIMEDOUT" || error.code === "ESOCKET"
          ? "Không thể kết nối Gmail. Vui lòng thử gửi lại email."
          : "Chưa gửi được email. Vui lòng kiểm tra cấu hình máy chủ và thử lại.";
    return res.status(500).json({ message });
  }
}



const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  let status = 200;
  let result;
  try {
    await handler({ method: request.method, headers: { authorization: request.headers.get("authorization") }, body: request.method === "POST" ? await request.json() : {} }, {
      status(code) { status = code; return this; },
      json(value) { result = value; return this; },
    });
  } catch {
    status = 400;
    result = { message: "Yêu cầu gửi email không hợp lệ." };
  }
  return new Response(JSON.stringify(result), { status, headers: { ...cors, "Content-Type": "application/json" } });
});

