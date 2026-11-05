export function formatCurrency(value) {
  return `${new Intl.NumberFormat("en-US").format(Number(value) || 0)} ₫`;
}

export function formatDate(value) {
  return value ? new Date(value).toLocaleDateString("vi-VN") : "—";
}

export function formatIntegerInput(value) {
  const digits = String(value ?? "")
    .replace(/\D/g, "")
    .slice(0, 15);
  return digits ? Number(digits).toLocaleString("en-US") : "";
}

export function formatVehiclePlate(value) {
  const compact = String(value ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^0-9A-Z]/g, "");
  const match = compact.match(/^(\d{2}[A-Z]{1,2})(\d{3})(\d{2})$/);
  return match ? `${match[1]}-${match[2]}.${match[3]}` : compact;
}
