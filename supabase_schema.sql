-- Supabase/Postgres schema for POS app migration from local SQLite.
-- Keep local_id/local_* fields to map existing SQLite rows without losing data.

create extension if not exists pgcrypto;

create table if not exists suppliers (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  name text,
  phone text,
  description text,
  address text,
  email text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  supplier_id uuid references suppliers(id) on delete set null,
  local_supplier_id bigint,
  name text,
  barcode text,
  description text,
  business_type text,
  price numeric(12,2) default 0,
  quantity integer default 0,
  cost numeric(12,2) default 0,
  is_rentable boolean default false,
  created_at timestamptz default now(),
  original_created_at text,
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  name text,
  last_name text,
  phone text,
  address text,
  email text,
  has_credit boolean default false,
  credit_limit numeric(12,2) default 0,
  credit numeric(12,2) default 0,
  credit_available numeric(12,2) default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  client_id uuid references clients(id) on delete set null,
  client_phone text,
  sale_date timestamptz,
  total numeric(12,2) default 0,
  amount_due numeric(12,2) default 0,
  is_credit boolean default false,
  is_paid boolean default false,
  is_voided boolean default false,
  voided_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  sale_id uuid references sales(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  local_sale_id bigint,
  local_product_id bigint,
  quantity integer default 0,
  subtotal numeric(12,2) default 0,
  discount numeric(12,2) default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

create table if not exists inventory_entries (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  product_id uuid references products(id) on delete set null,
  supplier_id uuid references suppliers(id) on delete set null,
  local_product_id bigint,
  local_supplier_id bigint,
  quantity integer default 0,
  cost numeric(12,2) default 0,
  entry_date timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

create table if not exists expenses (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

create table if not exists expense_entries (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  expense_id uuid references expenses(id) on delete set null,
  local_expense_id bigint,
  amount numeric(12,2) default 0,
  entry_date timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

create table if not exists payment_history (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  client_id uuid references clients(id) on delete set null,
  client_phone text,
  amount numeric(12,2) default 0,
  payment_date timestamptz,
  receipt_number text,
  affected_sales jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  sync_status text default 'synced'
);

-- Optional local-app support tables. Syncing these to Supabase is not required
-- for POS operation, but they mirror data created by recent app features.
create table if not exists app_error_logs (
  id uuid primary key default gen_random_uuid(),
  local_id bigint unique,
  source text,
  message text,
  stack_trace text,
  details text,
  created_at timestamptz default now()
);

create table if not exists inventory_drafts (
  id uuid primary key default gen_random_uuid(),
  draft_key text unique not null,
  payload jsonb,
  updated_at timestamptz default now()
);

create index if not exists idx_products_barcode on products(barcode);
create index if not exists idx_products_supplier_id on products(supplier_id);
create index if not exists idx_clients_phone on clients(phone);
create index if not exists idx_sales_client_phone on sales(client_phone);
create index if not exists idx_sales_date on sales(sale_date);
create index if not exists idx_sale_items_sale_id on sale_items(sale_id);
create index if not exists idx_sale_items_product_id on sale_items(product_id);
create index if not exists idx_inventory_product_id on inventory_entries(product_id);
create index if not exists idx_inventory_supplier_id on inventory_entries(supplier_id);
create index if not exists idx_payment_history_client_phone on payment_history(client_phone);
