import argparse
import json
import os
import sqlite3
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


MIGRATION_ORDER = [
    "suppliers",
    "products",
    "clients",
    "sales",
    "sale_items",
    "inventory_entries",
    "expenses",
    "expense_entries",
    "payment_history",
    "app_error_logs",
    "inventory_drafts",
]


class SupabaseClient:
    def __init__(self, url: str, key: str):
        self.url = url.rstrip("/")
        self.key = key

    def upsert(self, table: str, rows: list[dict], conflict_key: str = "local_id") -> list[dict]:
        if not rows:
            return []

        query = urllib.parse.urlencode({"on_conflict": conflict_key})
        endpoint = f"{self.url}/rest/v1/{table}?{query}"
        payload = json.dumps(rows).encode("utf-8")

        request = urllib.request.Request(
            endpoint,
            data=payload,
            method="POST",
            headers={
                "apikey": self.key,
                "Authorization": f"Bearer {self.key}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates,return=representation",
            },
        )

        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                body = response.read().decode("utf-8")
                return json.loads(body) if body else []
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Supabase error on {table}: HTTP {exc.code}: {body}") from exc


def rows(con: sqlite3.Connection, table: str) -> list[sqlite3.Row]:
    try:
        return con.execute(f'select * from "{table}"').fetchall()
    except sqlite3.OperationalError:
        return []


def bool_from_int(value) -> bool:
    return int(value or 0) == 1


def money(value) -> float:
    return float(value or 0)


def text(value):
    if value is None:
        return None
    return str(value)


def json_or_none(value):
    if value is None or str(value).strip() == "":
        return None
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return {"raw": value}


def build_payloads(con: sqlite3.Connection):
    supplier_rows = rows(con, "suppliers")
    product_rows = rows(con, "products")
    client_rows = rows(con, "clients")
    sale_rows = rows(con, "sales")
    sale_item_rows = rows(con, "sale_items")
    inventory_rows = rows(con, "inventory_entries")
    expense_rows = rows(con, "expenses")
    expense_entry_rows = rows(con, "expense_entries")
    payment_rows = rows(con, "payment_history")
    error_rows = rows(con, "app_error_logs")
    draft_rows = rows(con, "inventory_drafts")

    payloads = {
        "suppliers": [
            {
                "local_id": r["id"],
                "name": text(r["name"]),
                "phone": text(r["phone"]),
                "description": text(r["description"]),
                "address": text(r["address"]),
                "email": text(r["email"]),
            }
            for r in supplier_rows
        ],
        "products": [
            {
                "local_id": r["id"],
                "local_supplier_id": r["supplierId"],
                "name": text(r["name"]),
                "barcode": text(r["barcode"]),
                "description": text(r["description"]),
                "business_type": text(r["business_type"]),
                "price": money(r["price"]),
                "quantity": int(r["quantity"] or 0),
                "cost": money(r["cost"]),
                "is_rentable": bool_from_int(r["is_rentable"]),
                "original_created_at": text(r["createdAt"]),
            }
            for r in product_rows
        ],
        "clients": [
            {
                "local_id": r["id"],
                "name": text(r["name"]),
                "last_name": text(r["lastName"]),
                "phone": text(r["phone"]),
                "address": text(r["address"]),
                "email": text(r["email"]),
                "has_credit": bool_from_int(r["hasCredit"]),
                "credit_limit": money(r["creditLimit"]),
                "credit": money(r["credit"]),
                "credit_available": money(r["creditAvailable"]),
            }
            for r in client_rows
        ],
        "sales": [
            {
                "local_id": r["id"],
                "client_phone": text(r["clientPhone"]),
                "sale_date": text(r["date"]),
                "total": money(r["total"]),
                "amount_due": money(r["amountDue"]),
                "is_credit": bool_from_int(r["isCredit"]),
                "is_paid": bool_from_int(r["isPaid"]),
                "is_voided": bool_from_int(r["isVoided"]),
                "voided_at": text(r["voidedAt"]),
            }
            for r in sale_rows
        ],
        "sale_items": [
            {
                "local_id": r["id"],
                "local_sale_id": r["sale_id"],
                "local_product_id": r["product_id"],
                "quantity": int(r["quantity"] or 0),
                "subtotal": money(r["subtotal"]),
                "discount": money(r["discount"]),
            }
            for r in sale_item_rows
        ],
        "inventory_entries": [
            {
                "local_id": r["id"],
                "local_product_id": r["product_id"],
                "local_supplier_id": r["supplier_id"],
                "quantity": int(r["quantity"] or 0),
                "cost": money(r["cost"]),
                "entry_date": text(r["date"]),
            }
            for r in inventory_rows
        ],
        "expenses": [
            {
                "local_id": r["id"],
                "name": text(r["name"]),
            }
            for r in expense_rows
        ],
        "expense_entries": [
            {
                "local_id": r["id"],
                "local_expense_id": r["expense_id"],
                "amount": money(r["amount"]),
                "entry_date": text(r["date"]),
            }
            for r in expense_entry_rows
        ],
        "payment_history": [
            {
                "local_id": r["id"],
                "client_phone": text(r["client_phone"]),
                "amount": money(r["amount"]),
                "payment_date": text(r["payment_date"]),
                "receipt_number": text(r["receipt_number"]),
                "affected_sales": json_or_none(r["affected_sales"]),
                "created_at": text(r["created_at"]),
            }
            for r in payment_rows
        ],
        "app_error_logs": [
            {
                "local_id": r["id"],
                "source": text(r["source"]),
                "message": text(r["message"]),
                "stack_trace": text(r["stack_trace"]),
                "details": text(r["details"]),
                "created_at": text(r["created_at"]),
            }
            for r in error_rows
        ],
        "inventory_drafts": [
            {
                "draft_key": text(r["draft_key"]),
                "payload": json_or_none(r["payload"]),
                "updated_at": text(r["updated_at"]),
            }
            for r in draft_rows
        ],
    }

    return payloads


def map_returned_ids(returned: list[dict]) -> dict[int, str]:
    return {
        int(row["local_id"]): row["id"]
        for row in returned
        if row.get("local_id") is not None and row.get("id") is not None
    }


def migrate(db_path: Path, dry_run: bool):
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    payloads = build_payloads(con)
    con.close()

    print("Resumen del backup SQLite:")
    for table in MIGRATION_ORDER:
        print(f"  {table}: {len(payloads[table])}")

    if dry_run:
        print("\nDry run terminado. No se envio nada a Supabase.")
        return

    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not supabase_key:
        raise SystemExit(
            "Faltan variables de entorno SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY."
        )

    client = SupabaseClient(supabase_url, supabase_key)

    print("\nSubiendo tablas base...")
    supplier_map = map_returned_ids(client.upsert("suppliers", payloads["suppliers"]))
    client_returned = client.upsert("clients", payloads["clients"])
    client_phone_map = {
        row.get("phone"): row.get("id")
        for row in client_returned
        if row.get("phone") and row.get("id")
    }

    product_payload = []
    for row in payloads["products"]:
        row = dict(row)
        row["supplier_id"] = supplier_map.get(row.get("local_supplier_id"))
        product_payload.append(row)
    product_map = map_returned_ids(client.upsert("products", product_payload))

    sales_payload = []
    for row in payloads["sales"]:
        row = dict(row)
        row["client_id"] = client_phone_map.get(row.get("client_phone"))
        sales_payload.append(row)
    sale_map = map_returned_ids(client.upsert("sales", sales_payload))

    print("Subiendo tablas dependientes...")
    sale_items_payload = []
    for row in payloads["sale_items"]:
        row = dict(row)
        row["sale_id"] = sale_map.get(row.get("local_sale_id"))
        row["product_id"] = product_map.get(row.get("local_product_id"))
        sale_items_payload.append(row)
    client.upsert("sale_items", sale_items_payload)

    inventory_payload = []
    for row in payloads["inventory_entries"]:
        row = dict(row)
        row["product_id"] = product_map.get(row.get("local_product_id"))
        row["supplier_id"] = supplier_map.get(row.get("local_supplier_id"))
        inventory_payload.append(row)
    client.upsert("inventory_entries", inventory_payload)

    expense_map = map_returned_ids(client.upsert("expenses", payloads["expenses"]))

    expense_entries_payload = []
    for row in payloads["expense_entries"]:
        row = dict(row)
        row["expense_id"] = expense_map.get(row.get("local_expense_id"))
        expense_entries_payload.append(row)
    client.upsert("expense_entries", expense_entries_payload)

    payment_payload = []
    for row in payloads["payment_history"]:
        row = dict(row)
        row["client_id"] = client_phone_map.get(row.get("client_phone"))
        payment_payload.append(row)
    client.upsert("payment_history", payment_payload)

    client.upsert("app_error_logs", payloads["app_error_logs"])
    client.upsert("inventory_drafts", payloads["inventory_drafts"], conflict_key="draft_key")

    print("\nMigracion completada.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default=r"C:\FlutterProjects\pos_app\pos_backup.db")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"No existe el backup: {db_path}")

    migrate(db_path, args.dry_run)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
