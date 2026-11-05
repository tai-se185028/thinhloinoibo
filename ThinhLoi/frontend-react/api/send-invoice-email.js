import nodemailer from "nodemailer";

export default async function handler(req, res) {
  // CORS configuration
  res.setHeader("Access-Control-Allow-Credentials", "true");
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,OPTIONS,PATCH,DELETE,POST,PUT");
  res.setHeader(
    "Access-Control-Allow-Headers",
    "X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization"
  );

  if (req.method === "OPTIONS") {
    res.status(200).end();
    return;
  }

  if (req.method !== "POST") {
    return res.status(405).json({ message: "Method Not Allowed" });
  }

  try {
    const {
      invoice_code,
      manager_email,
      customer_name,
      total_amount,
      payment_date,
      pdf_base64,
    } = req.body || {};

    const gmailUser = process.env.GMAIL_USER;
    const gmailPass = process.env.GMAIL_APP_PASSWORD || process.env.GMAIL_PASS;

    if (!gmailUser || !gmailPass) {
      return res.status(500).json({
        message:
          "Chưa cấu hình biến môi trường GMAIL_USER và GMAIL_APP_PASSWORD trên Vercel.",
      });
    }

    if (!manager_email) {
      return res.status(400).json({
        message: "Thiếu email quản lý để nhận hóa đơn.",
      });
    }

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: gmailUser,
        pass: gmailPass,
      },
    });

    const formattedAmount =
      new Intl.NumberFormat("vi-VN").format(Number(total_amount) || 0) + " ₫";
    const formattedDate = payment_date || new Date().toLocaleDateString("vi-VN");

    const htmlContent = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">
        <div style="text-align: center; border-bottom: 2px solid #2563eb; padding-bottom: 16px; margin-bottom: 20px;">
          <h2 style="color: #1e293b; margin: 0 0 6px 0;">THÔNG BÁO THANH TOÁN THÀNH CÔNG</h2>
          <p style="color: #64748b; margin: 0; font-size: 14px;">Hệ thống Quản lý Nội bộ Thịnh Lợi</p>
        </div>

        <p style="font-size: 15px; color: #334155;">Kính gửi <strong>Quản lý</strong>,</p>
        <p style="font-size: 15px; color: #334155; line-height: 1.6;">
          Hóa đơn <strong>${invoice_code}</strong> vừa được xác nhận thanh toán thành công trên hệ thống. Dưới đây là thông tin chi tiết:
        </p>

        <div style="background-color: #f8fafc; border-radius: 8px; padding: 16px; margin: 20px 0; border: 1px solid #e2e8f0;">
          <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
            <tr>
              <td style="padding: 6px 0; color: #64748b; width: 140px;">Mã hóa đơn:</td>
              <td style="padding: 6px 0; color: #0f172a; font-weight: bold;">${invoice_code}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;">Khách hàng:</td>
              <td style="padding: 6px 0; color: #0f172a; font-weight: 600;">${customer_name || "—"}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;">Số tiền:</td>
              <td style="padding: 6px 0; color: #16a34a; font-weight: bold; font-size: 16px;">${formattedAmount}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;">Trạng thái:</td>
              <td style="padding: 6px 0; color: #16a34a; font-weight: 600;">Đã thanh toán</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;">Ngày thanh toán:</td>
              <td style="padding: 6px 0; color: #0f172a;">${formattedDate}</td>
            </tr>
          </table>
        </div>

        <p style="font-size: 14px; color: #475569; line-height: 1.5;">
          📎 <em>File hóa đơn PDF chi tiết đã được đính kèm theo thư này để lưu trữ và kiểm tra.</em>
        </p>

        <div style="margin-top: 30px; padding-top: 16px; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8; text-align: center;">
          Email tự động được gửi từ Hệ thống Quản lý Thịnh Lợi.
        </div>
      </div>
    `;

    const attachments = [];
    if (pdf_base64) {
      attachments.push({
        filename: `${invoice_code}.pdf`,
        content: Buffer.from(pdf_base64, "base64"),
        contentType: "application/pdf",
      });
    }

    const mailOptions = {
      from: `"Thịnh Lợi Quản Lý Kho" <${gmailUser}>`,
      to: manager_email,
      subject: `[Thịnh Lợi] Hóa đơn ${invoice_code} đã thanh toán thành công - ${formattedAmount}`,
      html: htmlContent,
      attachments,
    };

    const info = await transporter.sendMail(mailOptions);

    return res.status(200).json({
      success: true,
      messageId: info.messageId,
      sentTo: manager_email,
    });
  } catch (error) {
    console.error("Lỗi gửi email:", error);
    return res.status(500).json({
      message: error.message || "Lỗi khi gửi email",
    });
  }
}

