import pdfMake from "pdfmake/build/pdfmake";
import pdfFonts from "pdfmake/build/vfs_fonts";
import { formatVehiclePlate } from "@/lib/formatters";

pdfMake.vfs = pdfFonts.pdfMake?.vfs || pdfFonts;

const amount = (value) =>
  new Intl.NumberFormat("en-US").format(Number(value || 0)) + " ₫";
const quantity = (value) =>
  new Intl.NumberFormat("en-US").format(Number(value || 0));
const productOf = (products, id) =>
  products.find((product) => product.id === id) || {
    name: "Sản phẩm không còn tồn tại",
    sku: "—",
    unit: "",
  };
const centeredCell = (text, bold = false) => ({
  text: String(text ?? ""),
  alignment: "center",
  bold,
  margin: [2, 3, 2, 3],
});
const dimensionOf = (product) => {
  const values = [
    product.dimension_length,
    product.dimension_width,
    product.dimension_height,
  ];
  if (values.some((value) => value == null || value === "")) return "";
  return `${values.join(" × ")} ${product.dimension_unit || "cm"}`;
};

function invoicePdf(invoice, data) {
  const voucher =
    invoice.outbound_voucher_id &&
    data.outs.find((item) => item.id === invoice.outbound_voucher_id);
  if (voucher) return outboundPdf(voucher, data);
  const customer =
    data.customers.find((item) => item.id === invoice.customer_id) || {};
  const company = data.settings || {};
  const rows = invoice.invoice_items.map((item, index) => {
    const product = productOf(data.products, item.product_id);
    return [
      index + 1,
      [product.name, dimensionOf(product)].filter(Boolean).join("\n"),
      product.unit,
      item.quantity,
      amount(item.unit_price),
      amount(Number(item.quantity) * Number(item.unit_price)),
    ];
  });
  const definition = {
    pageSize: "A4",
    pageMargins: 36,
    content: [
      {
        columns: [
          {
            width: "55%",
            stack: [
              { text: "THỊNH LỢI", color: "#1d4ed8", bold: true, fontSize: 22 },
              company.business_name || "",
              company.phone || "",
            ],
          },
          {
            width: "45%",
            alignment: "right",
            stack: [
              { text: "HÓA ĐƠN BÁN HÀNG", bold: true, fontSize: 20 },
              { text: "(NỘI BỘ)", bold: true },
              invoice.invoice_code,
              new Date(invoice.invoice_date).toLocaleDateString("vi-VN"),
            ],
          },
        ],
      },
      {
        margin: [0, 20, 0, 20],
        table: {
          widths: ["*"],
          body: [
            [
              {
                stack: [
                  { text: "KHÁCH HÀNG", bold: true },
                  customer.name || "",
                  customer.address || "",
                  customer.phone || "",
                ],
                margin: 10,
              },
            ],
          ],
        },
      },
      {
        table: {
          headerRows: 1,
          widths: [25, "*", 40, 50, 70, 80],
          body: [
            ["STT", "Sản phẩm", "ĐVT", "Số lượng", "Đơn giá", "Thành tiền"],
            ...rows,
          ],
        },
        layout: "lightHorizontalLines",
      },
      {
        text: `TỔNG CỘNG: ${amount(invoice.total_amount)}`,
        alignment: "right",
        bold: true,
        color: "#1d4ed8",
        fontSize: 16,
        margin: [0, 16, 0, 45],
      },
      {
        columns: [
          {
            text: "Người lập phiếu\n\n\n(Ký, ghi rõ họ tên)",
            alignment: "center",
          },
          { text: "Khách hàng\n\n\n(Ký, ghi rõ họ tên)", alignment: "center" },
        ],
      },
    ],
    footer: {
      text: "Chứng từ nội bộ - không phải hóa đơn điện tử",
      alignment: "center",
      color: "#64748b",
      fontSize: 9,
    },
    defaultStyle: { font: "Roboto", fontSize: 9 },
  };
  return pdfMake.createPdf(definition);
}

function outboundPdf(voucher, data) {
  const company = data.settings || {},
    customer =
      data.customers.find((item) => item.id === voucher.customer_id) || {};
  const rows = voucher.outbound_items.map((item, index) => {
    const p = productOf(data.products, item.product_id);
    return [
      index + 1,
      [p.name, p.packaging_specification, dimensionOf(p)]
        .filter(Boolean)
        .join("\n"),
      item.manual_code || "",
      p.unit,
      item.requested_quantity,
      item.actual_quantity ?? item.quantity,
      amount(item.unit_price),
      amount(
        Number(item.actual_quantity ?? item.quantity) * Number(item.unit_price),
      ),
    ].map((value) => centeredCell(value));
  });
  const totalActualQuantity = voucher.outbound_items.reduce(
    (total, item) => total + Number(item.actual_quantity ?? item.quantity ?? 0),
    0,
  );
  const definition = {
    pageSize: "A4",
    pageMargins: [28, 28, 28, 32],
    content: [
      {
        columns: [
          {
            width: "50%",
            stack: [
              {
                text: company.business_name || "",
                bold: true,
                fontSize: 10,
              },
              company.address || "",
              company.phone ? `Điện thoại: ${company.phone}` : "",
            ],
          },
          {
            width: "50%",
            alignment: "center",
            stack: [
              { text: "PHIẾU XUẤT KHO", bold: true, fontSize: 18 },
              `Số: ${voucher.voucher_code}`,
              `Ngày ${new Date(voucher.voucher_date).toLocaleDateString("vi-VN")}`,
              ...(voucher.vehicle_plate
                ? [
                    {
                      text: formatVehiclePlate(voucher.vehicle_plate),
                      bold: true,
                      fontSize: 13,
                      margin: [0, 5, 0, 0],
                    },
                  ]
                : []),
            ],
          },
        ],
      },
      {
        margin: [0, 12],
        table: {
          widths: [110, "*"],
          body: [
            [
              {
                ...centeredCell("TÊN NGƯỜI NHẬN HÀNG", true),
              },
              {
                ...centeredCell(customer.name || "", true),
                fontSize: 10,
              },
            ],
            [
              centeredCell("ĐỊA CHỈ (BỘ PHẬN)", true),
              centeredCell(
                voucher.recipient_department || voucher.delivery_address || "",
              ),
            ],
            [
              centeredCell("LÝ DO XUẤT KHO", true),
              centeredCell(voucher.dispatch_reason || voucher.note || ""),
            ],
            [
              centeredCell("XUẤT TẠI KHO", true),
              centeredCell(voucher.destination || ""),
            ],
          ],
        },
      },
      {
        table: {
          headerRows: 1,
          widths: [20, "*", 45, 30, 45, 45, 60, 65],
          body: [
            [
              "STT",
              "TÊN, NHÃN HIỆU, QUY CÁCH SẢN PHẨM",
              "MÃ SỐ",
              "ĐVT",
              "SL YÊU CẦU",
              "SL THỰC XUẤT",
              "ĐƠN GIÁ",
              "THÀNH TIỀN",
            ].map((value) => centeredCell(value, true)),
            ...rows,
            [
              {
                text: "TỔNG CỘNG",
                colSpan: 5,
                alignment: "center",
                bold: true,
                fontSize: 10,
                margin: [2, 6, 2, 6],
              },
              {},
              {},
              {},
              {},
              {
                text: quantity(totalActualQuantity),
                alignment: "center",
                bold: true,
                fontSize: 10,
                margin: [2, 6, 2, 6],
              },
              {},
              {
                text: amount(voucher.total_amount),
                alignment: "center",
                bold: true,
                fontSize: 10,
                margin: [2, 6, 2, 6],
              },
            ],
          ],
        },
        margin: [0, 0, 0, 18],
      },
      {
        columns: [
          {
            text: "Người nhận hàng\n(Ký, ghi rõ họ tên)\n\n\n",
            alignment: "center",
          },
          {
            text: "NGƯỜI LẬP PHIẾU\n(Ký, ghi rõ họ tên)\n\n\n",
            alignment: "center",
          },
        ],
      },
    ],
    defaultStyle: { font: "Roboto", fontSize: 7 },
  };
  return pdfMake.createPdf(definition);
}

export function previewInvoicePdf(invoice, data) {
  invoicePdf(invoice, data).open();
}

export function downloadInvoicePdf(invoice, data) {
  invoicePdf(invoice, data).download(`${invoice.invoice_code}.pdf`);
}

export function previewOutboundPdf(voucher, data) {
  outboundPdf(voucher, data).open();
}

export function downloadOutboundPdf(voucher, data) {
  outboundPdf(voucher, data).download(`${voucher.voucher_code}.pdf`);
}
