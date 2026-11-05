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

export function isValidVehiclePlate(value) {
  if (!value) return true;
  const compact = String(value).trim().toUpperCase().replace(/[^0-9A-Z]/g, "");
  return /^\d{2}[A-Z]{1,2}\d?(\d{4}|\d{5})$/.test(compact);
}

export function formatVehiclePlate(value) {
  if (!value) return "";
  const raw = String(value).trim().toUpperCase();
  const compact = raw.replace(/[^0-9A-Z]/g, "");
  const match5 = compact.match(/^(\d{2}[A-Z]{1,2}\d?)(\d{3})(\d{2})$/);
  if (match5) {
    return `${match5[1]} - ${match5[2]}.${match5[3]}`;
  }
  const match4 = compact.match(/^(\d{2}[A-Z]{1,2}\d?)(\d{4})$/);
  if (match4) {
    return `${match4[1]} - ${match4[2]}`;
  }
  return raw;
}
