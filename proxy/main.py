"""
Local READ-ONLY proxy in front of the ERPNext instance.

Runs on your laptop. A tunnel exposes ONLY this proxy to the internet, never
ERPNext's raw :8080 port directly. The Vercel app calls these endpoints with a
bearer token; Gemini can only reach the fixed, read-only operations defined in
erpnext_client.py.
"""
import os

from dotenv import load_dotenv

load_dotenv()  # must run before importing erpnext_client, which reads env vars at import time

from fastapi import Depends, FastAPI, Header, HTTPException  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402

import erpnext_client as erpnext  # noqa: E402

TOKEN = os.getenv("ERPNEXT_PROXY_TOKEN")

app = FastAPI(title="ERPNext Read-Only Proxy", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    allow_methods=["GET"],
    allow_headers=["Authorization"],
)


def require_token(authorization: str | None = Header(default=None)) -> None:
    if not TOKEN:
        raise HTTPException(status_code=500, detail="Proxy token not configured on server")
    if authorization != f"Bearer {TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/health")
def health():
    ok, detail = erpnext.ping()
    return {"status": "ok", "erpnext_reachable": ok, "detail": detail}


@app.get("/customers", dependencies=[Depends(require_token)])
def customers():
    return {"customers": erpnext.list_customers()}


@app.get("/items", dependencies=[Depends(require_token)])
def items():
    return {"items": erpnext.list_items()}


@app.get("/sales_orders", dependencies=[Depends(require_token)])
def sales_orders():
    return {"sales_orders": erpnext.list_sales_orders()}


@app.get("/sales_invoices", dependencies=[Depends(require_token)])
def sales_invoices():
    return {"sales_invoices": erpnext.list_sales_invoices()}


@app.get("/purchase_invoices", dependencies=[Depends(require_token)])
def purchase_invoices():
    return {"purchase_invoices": erpnext.list_purchase_invoices()}


@app.get("/receivables", dependencies=[Depends(require_token)])
def receivables():
    return {"receivables": erpnext.receivables()}


@app.get("/payables", dependencies=[Depends(require_token)])
def payables():
    return {"payables": erpnext.payables()}
