"""
Thin, READ-ONLY client for the local ERPNext instance (localhost:8080) over
its REST API.

Design rules (security):
- Only ever does GET requests against /api/resource/<Doctype>. No POST/PUT/DELETE.
- Every query the proxy can trigger is a fixed function defined here — the
  HTTP layer (main.py) does not accept arbitrary doctypes/filters from callers.
"""
import os
import httpx

ERPNEXT_URL = os.getenv("ERPNEXT_URL", "http://localhost:8080")
ERPNEXT_API_KEY = os.getenv("ERPNEXT_API_KEY", "")
ERPNEXT_API_SECRET = os.getenv("ERPNEXT_API_SECRET", "")

_headers = {
    "Authorization": f"token {ERPNEXT_API_KEY}:{ERPNEXT_API_SECRET}",
    "Content-Type": "application/json",
}


def _get(doctype: str, fields: list[str], filters: list | None = None, limit: int = 50, order_by: str = "") -> list[dict]:
    params = {
        "fields": __import__("json").dumps(fields),
        "limit_page_length": limit,
    }
    if filters:
        params["filters"] = __import__("json").dumps(filters)
    if order_by:
        params["order_by"] = order_by
    resp = httpx.get(
        f"{ERPNEXT_URL}/api/resource/{doctype}",
        headers=_headers,
        params=params,
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json().get("data", [])


def ping() -> tuple[bool, str]:
    try:
        resp = httpx.get(f"{ERPNEXT_URL}/api/method/ping", timeout=5)
        resp.raise_for_status()
        return True, "erpnext reachable"
    except Exception as e:  # noqa: BLE001
        return False, str(e)


# ---------------------------------------------------------------------------
# Public, whitelisted read operations
# ---------------------------------------------------------------------------
def list_customers(limit: int = 50) -> list[dict]:
    return _get(
        "Customer",
        ["name", "customer_name", "customer_group", "territory", "mobile_no", "email_id"],
        limit=limit,
    )


def list_items(limit: int = 50) -> list[dict]:
    return _get(
        "Item",
        ["name", "item_name", "item_group", "stock_uom", "standard_rate"],
        filters=[["disabled", "=", 0]],
        limit=limit,
    )


def list_sales_orders(limit: int = 50) -> list[dict]:
    return _get(
        "Sales Order",
        ["name", "customer", "transaction_date", "grand_total", "status"],
        limit=limit,
        order_by="transaction_date desc",
    )


def list_sales_invoices(limit: int = 50) -> list[dict]:
    return _get(
        "Sales Invoice",
        ["name", "customer", "posting_date", "grand_total", "outstanding_amount", "status"],
        filters=[["docstatus", "=", 1]],
        limit=limit,
        order_by="posting_date desc",
    )


def list_purchase_invoices(limit: int = 50) -> list[dict]:
    return _get(
        "Purchase Invoice",
        ["name", "supplier", "posting_date", "grand_total", "outstanding_amount", "status"],
        filters=[["docstatus", "=", 1]],
        limit=limit,
        order_by="posting_date desc",
    )


def receivables(limit: int = 50) -> list[dict]:
    """Posted sales invoices with an outstanding (unpaid) amount."""
    return _get(
        "Sales Invoice",
        ["name", "customer", "posting_date", "grand_total", "outstanding_amount"],
        filters=[["docstatus", "=", 1], ["outstanding_amount", ">", 0]],
        limit=limit,
        order_by="posting_date desc",
    )


def payables(limit: int = 50) -> list[dict]:
    """Posted purchase invoices with an outstanding (unpaid) amount."""
    return _get(
        "Purchase Invoice",
        ["name", "supplier", "posting_date", "grand_total", "outstanding_amount"],
        filters=[["docstatus", "=", 1], ["outstanding_amount", ">", 0]],
        limit=limit,
        order_by="posting_date desc",
    )
