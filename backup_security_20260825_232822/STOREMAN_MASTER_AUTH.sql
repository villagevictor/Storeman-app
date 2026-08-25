
-- =========================================================
-- STOREMAN MASTER AUTH / COMPANY / USER SYSTEM
-- =========================================================

create extension if not exists pgcrypto;

-- =========================================================
-- 1. COMPANIES
-- =========================================================

create table if not exists public.companies (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    owner_id uuid,
    status text not null default 'active',
    created_at timestamptz not null default now()
);

-- =========================================================
-- 2. PROFILES
-- =========================================================

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    company_id uuid references public.companies(id) on delete cascade,
    full_name text,
    role text not null default 'user',
    status text not null default 'active',
    warehouse_id uuid,
    permissions jsonb not null default '{}'::jsonb,
    last_seen_at timestamptz,
    created_at timestamptz not null default now()
);

-- Existing profiles table compatibility
alter table public.profiles
    add column if not exists company_id uuid;

alter table public.profiles
    add column if not exists full_name text;

alter table public.profiles
    add column if not exists status text default 'active';

alter table public.profiles
    add column if not exists warehouse_id uuid;

alter table public.profiles
    add column if not exists permissions jsonb default '{}'::jsonb;

alter table public.profiles
    add column if not exists last_seen_at timestamptz;

-- =========================================================
-- 3. WAREHOUSE
-- =========================================================

create table if not exists public.warehouses (
    id uuid primary key default gen_random_uuid(),
    company_id uuid,
    name text not null,
    location text,
    status text not null default 'active',
    created_at timestamptz not null default now()
);

alter table public.warehouses
    add column if not exists company_id uuid;

-- =========================================================
-- 4. SUPPLIERS
-- =========================================================

create table if not exists public.suppliers (
    id uuid primary key default gen_random_uuid(),
    company_id uuid,
    name text not null,
    phone text,
    email text,
    address text,
    created_at timestamptz not null default now()
);

alter table public.suppliers
    add column if not exists company_id uuid;

-- =========================================================
-- 5. MATERIALS
-- =========================================================

create table if not exists public.materials (
    id uuid primary key default gen_random_uuid(),
    company_id uuid,
    warehouse_id uuid,
    code text,
    name text not null,
    category text,
    unit text,
    opening_stock numeric not null default 0,
    reorder_level numeric not null default 0,
    created_at timestamptz not null default now()
);

alter table public.materials
    add column if not exists company_id uuid;

alter table public.materials
    add column if not exists warehouse_id uuid;

-- =========================================================
-- 6. TRANSACTIONS
-- =========================================================

create table if not exists public.transactions (
    id uuid primary key default gen_random_uuid(),
    company_id uuid,
    warehouse_id uuid,
    material_id uuid,
    user_id uuid,
    type text,
    quantity numeric default 0,
    note text,
    created_at timestamptz not null default now()
);

alter table public.transactions
    add column if not exists company_id uuid;

alter table public.transactions
    add column if not exists warehouse_id uuid;

alter table public.transactions
    add column if not exists user_id uuid;

-- =========================================================
-- 7. SALES ORDERS
-- =========================================================

create table if not exists public.sales_orders (
    id uuid primary key default gen_random_uuid(),
    company_id uuid,
    user_id uuid,
    customer_name text,
    customer_phone text,
    total_amount numeric default 0,
    payment_status text default 'pending',
    created_at timestamptz not null default now()
);

alter table public.sales_orders
    add column if not exists company_id uuid;

alter table public.sales_orders
    add column if not exists user_id uuid;

-- =========================================================
-- 8. ACTIVITY LOG
-- =========================================================

create table if not exists public.activity_logs (
    id uuid primary key default gen_random_uuid(),
    company_id uuid,
    user_id uuid,
    action text not null,
    table_name text,
    record_id uuid,
    details jsonb default '{}'::jsonb,
    created_at timestamptz not null default now()
);

-- =========================================================
-- 9. STORE BACKUPS
-- =========================================================

create table if not exists public.store_backups (
    id uuid primary key default gen_random_uuid(),
    company_id uuid,
    user_id uuid,
    backup_name text,
    backup_data jsonb,
    created_at timestamptz not null default now()
);

-- =========================================================
-- 10. HELPER FUNCTIONS
-- =========================================================

create or replace function public.current_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select company_id
    from public.profiles
    where id = auth.uid()
    limit 1
$$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
    select role
    from public.profiles
    where id = auth.uid()
    limit 1
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        (
            select role = 'admin'
            from public.profiles
            where id = auth.uid()
        ),
        false
    )
$$;

-- =========================================================
-- 11. INDEXES
-- =========================================================

create index if not exists idx_profiles_company
on public.profiles(company_id);

create index if not exists idx_warehouses_company
on public.warehouses(company_id);

create index if not exists idx_suppliers_company
on public.suppliers(company_id);

create index if not exists idx_materials_company
on public.materials(company_id);

create index if not exists idx_transactions_company
on public.transactions(company_id);

create index if not exists idx_sales_orders_company
on public.sales_orders(company_id);

create index if not exists idx_activity_company
on public.activity_logs(company_id);

create index if not exists idx_backups_company
on public.store_backups(company_id);

-- =========================================================
-- 12. ENABLE RLS
-- =========================================================

alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.warehouses enable row level security;
alter table public.suppliers enable row level security;
alter table public.materials enable row level security;
alter table public.transactions enable row level security;
alter table public.sales_orders enable row level security;
alter table public.activity_logs enable row level security;
alter table public.store_backups enable row level security;

-- =========================================================
-- 13. DROP OLD STOREMAN POLICIES
-- =========================================================

drop policy if exists companies_select on public.companies;
drop policy if exists companies_update on public.companies;

drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_admin_all on public.profiles;

drop policy if exists warehouses_company_all on public.warehouses;
drop policy if exists suppliers_company_all on public.suppliers;
drop policy if exists materials_company_all on public.materials;
drop policy if exists transactions_company_all on public.transactions;
drop policy if exists sales_orders_company_all on public.sales_orders;
drop policy if exists activity_company_select on public.activity_logs;
drop policy if exists activity_company_insert on public.activity_logs;
drop policy if exists backups_company_all on public.store_backups;

-- =========================================================
-- 14. COMPANY POLICIES
-- =========================================================

create policy companies_select
on public.companies
for select
to authenticated
using (
    id = public.current_company_id()
);

create policy companies_update
on public.companies
for update
to authenticated
using (
    id = public.current_company_id()
    and public.is_admin()
)
with check (
    id = public.current_company_id()
    and public.is_admin()
);

-- =========================================================
-- 15. PROFILE POLICIES
-- =========================================================

create policy profiles_select
on public.profiles
for select
to authenticated
using (
    company_id = public.current_company_id()
);

create policy profiles_update
on public.profiles
for update
to authenticated
using (
    company_id = public.current_company_id()
    and public.is_admin()
)
with check (
    company_id = public.current_company_id()
);

create policy profiles_admin_all
on public.profiles
for all
to authenticated
using (
    company_id = public.current_company_id()
    and public.is_admin()
)
with check (
    company_id = public.current_company_id()
);

-- =========================================================
-- 16. WAREHOUSE
-- =========================================================

create policy warehouses_company_all
on public.warehouses
for all
to authenticated
using (
    company_id = public.current_company_id()
)
with check (
    company_id = public.current_company_id()
);

-- =========================================================
-- 17. SUPPLIERS
-- =========================================================

create policy suppliers_company_all
on public.suppliers
for all
to authenticated
using (
    company_id = public.current_company_id()
)
with check (
    company_id = public.current_company_id()
);

-- =========================================================
-- 18. MATERIALS
-- =========================================================

create policy materials_company_all
on public.materials
for all
to authenticated
using (
    company_id = public.current_company_id()
)
with check (
    company_id = public.current_company_id()
);

-- =========================================================
-- 19. TRANSACTIONS
-- =========================================================

create policy transactions_company_all
on public.transactions
for all
to authenticated
using (
    company_id = public.current_company_id()
)
with check (
    company_id = public.current_company_id()
);

-- =========================================================
-- 20. SALES
-- =========================================================

create policy sales_orders_company_all
on public.sales_orders
for all
to authenticated
using (
    company_id = public.current_company_id()
)
with check (
    company_id = public.current_company_id()
);

-- =========================================================
-- 21. ACTIVITY
-- =========================================================

create policy activity_company_select
on public.activity_logs
for select
to authenticated
using (
    company_id = public.current_company_id()
);

create policy activity_company_insert
on public.activity_logs
for insert
to authenticated
with check (
    company_id = public.current_company_id()
);

-- =========================================================
-- 22. BACKUPS
-- =========================================================

create policy backups_company_all
on public.store_backups
for all
to authenticated
using (
    company_id = public.current_company_id()
)
with check (
    company_id = public.current_company_id()
);

-- =========================================================
-- DONE
-- =========================================================

select
    'STOREMAN AUTH DATABASE STRUCTURE READY' as status;

