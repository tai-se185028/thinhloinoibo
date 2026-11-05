import { supabase } from "@/lib/supabase";

export async function issueInvoiceForOutbound(outboundId, data) {
  const existing = await supabase
    .from("invoices")
    .select("id,status")
    .eq("outbound_voucher_id", outboundId)
    .maybeSingle();
  if (existing.error) throw existing.error;
  if (existing.data) {
    if (existing.data.status === "draft") {
      const finalized = await supabase.rpc("finalize_invoice", {
        p_invoice_id: existing.data.id,
      });
      if (finalized.error) throw finalized.error;
    }
    return existing.data.id;
  }

  const voucher = await supabase
    .from("outbound_vouchers")
    .select("id,customer_id,status,discount_amount,outbound_items(*)")
    .eq("id", outboundId)
    .single();
  if (voucher.error) throw voucher.error;
  if (voucher.data.status !== "confirmed") {
    throw new Error("Phiếu xuất phải được xác nhận trước khi lập hóa đơn.");
  }
  if (!voucher.data.outbound_items?.length) {
    throw new Error("Phiếu xuất không có sản phẩm để lập hóa đơn.");
  }

  const created = await supabase.rpc("create_invoice_draft", {
    p_customer_id: voucher.data.customer_id,
    p_outbound_voucher_id: outboundId,
    p_discount_amount: Number(voucher.data.discount_amount || 0),
    p_items: voucher.data.outbound_items.map((item) => ({
      product_id: item.product_id,
      description:
        data.products.find((product) => product.id === item.product_id)?.name ||
        "Sản phẩm",
      quantity: Number(item.actual_quantity ?? item.quantity),
      unit_price: Number(item.unit_price),
    })),
  });
  if (created.error) throw created.error;
  const invoiceId = created.data?.id;
  if (!invoiceId) throw new Error("Backend không trả về mã hóa đơn vừa tạo.");
  const finalized = await supabase.rpc("finalize_invoice", {
    p_invoice_id: invoiceId,
  });
  if (finalized.error) throw finalized.error;
  return invoiceId;
}
