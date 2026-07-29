// Tool definitions handed to Gemini (via the OpenAI-compatible endpoint) plus
// the dispatcher that executes each call against the ERPNext proxy. Read-only.
import { erpnext } from "./erpnext";

export const tools = [
  {
    type: "function" as const,
    function: {
      name: "get_customers",
      description: "List customers known to ERPNext, with contact info and group/territory.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "get_items",
      description: "List active items/products with unit and standard rate.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "get_sales_orders",
      description: "List recent sales orders with customer, total, and status.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "get_sales_invoices",
      description: "List posted sales invoices with amount and outstanding balance.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "get_purchase_invoices",
      description: "List posted purchase invoices (vendor bills) with amount and outstanding balance.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "get_receivables",
      description: "List sales invoices with an outstanding (unpaid) amount — money owed TO the business.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "get_payables",
      description: "List purchase invoices with an outstanding (unpaid) amount — money the business OWES.",
      parameters: { type: "object", properties: {} },
    },
  },
];

export async function runTool(name: string, _args: Record<string, unknown>): Promise<string> {
  try {
    switch (name) {
      case "get_customers":
        return JSON.stringify(await erpnext.customers());
      case "get_items":
        return JSON.stringify(await erpnext.items());
      case "get_sales_orders":
        return JSON.stringify(await erpnext.salesOrders());
      case "get_sales_invoices":
        return JSON.stringify(await erpnext.salesInvoices());
      case "get_purchase_invoices":
        return JSON.stringify(await erpnext.purchaseInvoices());
      case "get_receivables":
        return JSON.stringify(await erpnext.receivables());
      case "get_payables":
        return JSON.stringify(await erpnext.payables());
      default:
        return JSON.stringify({ error: `unknown tool ${name}` });
    }
  } catch (e) {
    return JSON.stringify({ error: e instanceof Error ? e.message : String(e) });
  }
}
