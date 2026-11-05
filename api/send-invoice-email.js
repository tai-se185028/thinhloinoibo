import tls from "node:tls";

function sendSmtpEmail({ user, pass, to, subject, html, attachments }) {
  return new Promise((resolve, reject) => {
    const cleanPass = (pass || "").replace(/\s+/g, "");
    const boundary = "----=_Part_" + Date.now() + "_" + Math.random().toString(36).substring(2);

    let mime = "";
    mime += `From: "Thịnh Lợi Quản Lý Kho" <${user}>\r\n`;
    mime += `To: <${to}>\r\n`;
    mime += `Subject: =?UTF-8?B?${Buffer.from(subject, "utf-8").toString("base64")}?=\r\n`;
    mime += `MIME-Version: 1.0\r\n`;
    mime += `Content-Type: multipart/mixed; boundary="${boundary}"\r\n\r\n`;

    // HTML body
    mime += `--${boundary}\r\n`;
    mime += `Content-Type: text/html; charset=UTF-8\r\n`;
    mime += `Content-Transfer-Encoding: base64\r\n\r\n`;
    mime += Buffer.from(html, "utf-8").toString("base64") + "\r\n\r\n";

    // Attachments
    if (attachments && attachments.length > 0) {
      for (const att of attachments) {
        mime += `--${boundary}\r\n`;
        mime += `Content-Type: ${att.contentType || "application/octet-stream"}; name="=?UTF-8?B?${Buffer.from(att.filename, "utf-8").toString("base64")}?="\r\n`;
        mime += `Content-Disposition: attachment; filename="=?UTF-8?B?${Buffer.from(att.filename, "utf-8").toString("base64")}?="\r\n`;
        mime += `Content-Transfer-Encoding: base64\r\n\r\n`;
        const rawBase64 =
          typeof att.content === "string"
            ? att.content
            : Buffer.from(att.content).toString("base64");
        const chunked = rawBase64.match(/.{1,76}/g)?.join("\r\n") || rawBase64;
        mime += chunked + "\r\n\r\n";
      }
    }
    mime += `--${boundary}--\r\n`;

    const socket = tls.connect(
      {
        host: "smtp.gmail.com",
        port: 465,
        rejectUnauthorized: true,
      },
      () => {}
    );

    let step = 0;
    let buffer = "";

    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error("Timeout khi kết nối tới Gmail SMTP (smtp.gmail.com:465)"));
    }, 20000);

    socket.on("data", (chunk) => {
      buffer += chunk.toString();
      const lines = buffer.split("\r\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line) continue;
        const code = parseInt(line.substring(0, 3), 10);
        const isLastLine = line.charAt(3) === " ";

        if (!isLastLine) continue;

        if (code >= 400) {
          clearTimeout(timeout);
          socket.write("QUIT\r\n");
          socket.end();
          return reject(new Error(`Gmail SMTP trả lời lỗi (${code}): ${line.substring(4)}`));
        }

        if (step === 0 && code === 220) {
          step = 1;
          socket.write("EHLO localhost\r\n");
        } else if (step === 1 && code === 250) {
          step = 2;
          socket.write("AUTH LOGIN\r\n");
        } else if (step === 2 && code === 334) {
          step = 3;
          socket.write(Buffer.from(user).toString("base64") + "\r\n");
        } else if (step === 3 && code === 334) {
          step = 4;
          socket.write(Buffer.from(cleanPass).toString("base64") + "\r\n");
        } else if (step === 4 && code === 235) {
          step = 5;
          socket.write(`MAIL FROM:<${user}>\r\n`);
        } else if (step === 5 && code === 250) {
          step = 6;
          socket.write(`RCPT TO:<${to}>\r\n`);
        } else if (step === 6 && code === 250) {
          step = 7;
          socket.write("DATA\r\n");
        } else if (step === 7 && code === 354) {
          step = 8;
          socket.write(mime + "\r\n.\r\n");
        } else if (step === 8 && code === 250) {
          clearTimeout(timeout);
          socket.write("QUIT\r\n");
          socket.end();
          return resolve({ success: true, messageId: line });
        }
      }
    });

    socket.on("error", (err) => {
      clearTimeout(timeout);
      reject(err);
    });
  });
}

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

    const gmailUser = (process.env.GMAIL_USER || "").trim();
    const rawPass = (process.env.GMAIL_APP_PASSWORD || process.env.GMAIL_PASS || "").trim();
    const gmailPass = rawPass.replace(/\s+/g, "");

    if (!gmailUser || !gmailPass) {
      return res.status(500).json({
        message:
          "Chưa tìm thấy biến môi trường GMAIL_USER hoặc GMAIL_APP_PASSWORD trên Vercel. Bạn cần Redeploy lại ứng dụng sau khi thêm biến môi trường.",
      });
    }

    if (!manager_email) {
      return res.status(400).json({
        message: "Thiếu email quản lý để nhận hóa đơn.",
      });
    }

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
        content: pdf_base64,
        contentType: "application/pdf",
      });
    }

    const result = await sendSmtpEmail({
      user: gmailUser,
      pass: gmailPass,
      to: manager_email,
      subject: `[Thịnh Lợi] Hóa đơn ${invoice_code} đã thanh toán thành công - ${formattedAmount}`,
      html: htmlContent,
      attachments,
    });

    return res.status(200).json({
      success: true,
      sentTo: manager_email,
      info: result,
    });
  } catch (error) {
    console.error("Lỗi gửi email:", error);
    return res.status(500).json({
      message: error.message || "Lỗi khi gửi email",
    });
  }
}

