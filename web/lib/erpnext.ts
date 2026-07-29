// Server-side client for the local read-only ERPNext proxy (reached via the
// tunnel in production). Never imported into client components — the token
// stays on the server.

const BASE = process.env.ERPNEXT_PROXY_URL || "";
const TOKEN = process.env.ERPNEXT_PROXY_TOKEN || "";

async function call(path: string): Promise<unknown> {
  if (!BASE || !TOKEN) throw new Error("ERPNext proxy not configured");
  const res = await fetch(`${BASE}${path}`, {
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      "ngrok-skip-browser-warning": "true",
    },
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`ERPNext proxy ${path} -> HTTP ${res.status}`);
  return res.json();
}

export const erpnext = {
  customers: () => call("/customers"),
  items: () => call("/items"),
  salesOrders: () => call("/sales_orders"),
  salesInvoices: () => call("/sales_invoices"),
  purchaseInvoices: () => call("/purchase_invoices"),
  receivables: () => call("/receivables"),
  payables: () => call("/payables"),
};
