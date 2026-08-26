-- ============================================================
-- STOREMAN FINAL SECURITY CHECK
-- Run after migrations.
-- ============================================================

-- 1. Check admin
select
  id,
  email,
  role,
  status,
  company_id,
  warehouse_id,
  permissions
from public.profiles
where lower(email) =
      lower('ashenafihailay779@gmail.com');

-- 2. Check pending users
select
  id,
  email,
  role,
  status,
  company_id,
  warehouse_id
from public.profiles
order by created_at desc;

-- 3. Check companies
select *
from public.companies;

-- 4. Check warehouses
select *
from public.warehouses;

-- 5. Check RLS
select
  schemaname,
  tablename,
  rowsecurity
from pg_tables
where schemaname = 'public'
and tablename in (
  'profiles',
  'companies',
  'warehouses',
  'materials',
  'suppliers',
  'transactions',
  'sales_orders',
  'activity_logs',
  'admin_notifications'
);

-- 6. Check admin profile
select
  email,
  role,
  status,
  permissions
from public.profiles
where lower(email) =
      lower('ashenafihailay779@gmail.com');

