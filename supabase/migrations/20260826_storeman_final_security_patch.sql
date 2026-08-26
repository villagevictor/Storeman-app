-- ============================================================
-- STOREMAN FINAL SECURITY PATCH
-- Admin-only user management
-- Pending approval
-- Company / warehouse / permission protection
-- ============================================================

create schema if not exists private;

-- ------------------------------------------------------------
-- ADMIN / ACTIVE HELPERS
-- ------------------------------------------------------------

create or replace function private.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.status = 'active'
  );
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.status = 'active'
      and lower(p.role) = 'admin'
  );
$$;

create or replace function private.current_company_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.company_id
  from public.profiles p
  where p.id = (select auth.uid())
  limit 1;
$$;

create or replace function private.current_warehouse_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.warehouse_id
  from public.profiles p
  where p.id = (select auth.uid())
  limit 1;
$$;

-- ------------------------------------------------------------
-- PROFILE SECURITY
-- ------------------------------------------------------------

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon;
grant select, update on table public.profiles to authenticated;

drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_delete on public.profiles;

-- Normal user:
-- can see ONLY own profile.
--
-- Admin:
-- can see ALL profiles.
create policy profiles_select
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) = id
  or private.is_admin()
);

-- Normal user can update ONLY safe personal information.
-- Security fields are protected by trigger below.
--
-- Admin can update all profiles.
create policy profiles_update
on public.profiles
for update
to authenticated
using (
  (select auth.uid()) = id
  or private.is_admin()
)
with check (
  (select auth.uid()) = id
  or private.is_admin()
);

-- Only admin can delete profiles.
create policy profiles_delete
on public.profiles
for delete
to authenticated
using (
  private.is_admin()
);

-- ------------------------------------------------------------
-- PREVENT PRIVILEGE ESCALATION
-- ------------------------------------------------------------

create or replace function public.prevent_profile_escalation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  -- A normal user can NOT modify security fields.
  if (select auth.uid()) = old.id
     and not private.is_admin()
  then

    if new.role is distinct from old.role
       or new.status is distinct from old.status
       or new.company_id is distinct from old.company_id
       or new.warehouse_id is distinct from old.warehouse_id
       or new.permissions is distinct from old.permissions
       or new.email is distinct from old.email
    then

      raise exception
        'Only an administrator can change role, status, company, warehouse, permissions or email.';

    end if;

  end if;

  new.updated_at := now();

  return new;
end;
$$;

drop trigger if exists profile_security_guard
on public.profiles;

create trigger profile_security_guard
before update on public.profiles
for each row
execute procedure public.prevent_profile_escalation();

-- ------------------------------------------------------------
-- USER STATUS RULE
-- ------------------------------------------------------------

-- Pending users can authenticate but must not access ERP data.
-- RLS policies below require is_active_user().
-- Therefore:
--
-- pending = no ERP access
-- active  = authorized access
-- blocked = no ERP access

-- ------------------------------------------------------------
-- ADMIN-ONLY USER MANAGEMENT
-- ------------------------------------------------------------

create or replace function private.can_manage_users()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin();
$$;

revoke all on function private.can_manage_users() from public;
grant execute on function private.can_manage_users() to authenticated;

-- ------------------------------------------------------------
-- ADMIN PROFILE BOOTSTRAP
-- ------------------------------------------------------------

insert into public.profiles(
  id,
  email,
  full_name,
  role,
  status,
  company_id,
  warehouse_id,
  permissions
)
select
  u.id,
  u.email,
  coalesce(
    u.raw_user_meta_data->>'full_name',
    'System Administrator'
  ),
  'admin',
  'active',
  c.id,
  null,
  jsonb_build_object(
    'dashboard', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'materials', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'stock_in', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'stock_out', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'suppliers', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'warehouses', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'invoicing', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'reports', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'backup', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'users', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    ),
    'settings', jsonb_build_object(
      'view',true,'create',true,'update',true,'delete',true
    )
  )
from auth.users u
cross join (
  select id
  from public.companies
  where name = 'Storeman Main Company'
  limit 1
) c
where lower(u.email) =
      lower('ashenafihailay779@gmail.com')

on conflict (id) do update
set
  email = excluded.email,
  role = 'admin',
  status = 'active',
  company_id =
    coalesce(public.profiles.company_id, excluded.company_id),
  permissions = excluded.permissions;

-- ------------------------------------------------------------
-- IMPORTANT:
-- ADMIN CAN SEE ALL USERS.
-- NORMAL USER CAN SEE ONLY SELF.
-- ------------------------------------------------------------

-- This is intentionally NOT:
--
-- using (true)
--
-- because that would expose every user's profile.

-- ------------------------------------------------------------
-- DATA RLS
-- ------------------------------------------------------------

do $$
declare
  t text;
begin

  foreach t in array array[
    'companies',
    'warehouses',
    'materials',
    'suppliers',
    'transactions',
    'sales_orders',
    'activity_logs'
  ]
  loop

    execute format(
      'alter table public.%I enable row level security',
      t
    );

  end loop;

end
$$;

-- ------------------------------------------------------------
-- COMPANIES
-- ------------------------------------------------------------

drop policy if exists companies_select on public.companies;

create policy companies_select
on public.companies
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or id = private.current_company_id()
  )
);

-- ------------------------------------------------------------
-- WAREHOUSES
-- ------------------------------------------------------------

drop policy if exists warehouses_select on public.warehouses;

create policy warehouses_select
on public.warehouses
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      id = private.current_warehouse_id()
      and company_id = private.current_company_id()
    )
  )
);

-- Only admin can create/update/delete warehouses.
drop policy if exists warehouses_insert on public.warehouses;
drop policy if exists warehouses_update on public.warehouses;
drop policy if exists warehouses_delete on public.warehouses;

create policy warehouses_insert
on public.warehouses
for insert
to authenticated
with check (
  private.is_admin()
);

create policy warehouses_update
on public.warehouses
for update
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy warehouses_delete
on public.warehouses
for delete
to authenticated
using (private.is_admin());

-- ------------------------------------------------------------
-- DATA TABLES
-- ------------------------------------------------------------

drop policy if exists materials_select on public.materials;
drop policy if exists materials_insert on public.materials;
drop policy if exists materials_update on public.materials;
drop policy if exists materials_delete on public.materials;

create policy materials_select
on public.materials
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy materials_insert
on public.materials
for insert
to authenticated
with check (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy materials_update
on public.materials
for update
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
)
with check (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy materials_delete
on public.materials
for delete
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

-- ------------------------------------------------------------
-- SUPPLIERS
-- ------------------------------------------------------------

drop policy if exists suppliers_select on public.suppliers;
drop policy if exists suppliers_insert on public.suppliers;
drop policy if exists suppliers_update on public.suppliers;
drop policy if exists suppliers_delete on public.suppliers;

create policy suppliers_select
on public.suppliers
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy suppliers_insert
on public.suppliers
for insert
to authenticated
with check (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy suppliers_update
on public.suppliers
for update
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
)
with check (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy suppliers_delete
on public.suppliers
for delete
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

-- ------------------------------------------------------------
-- TRANSACTIONS
-- ------------------------------------------------------------

drop policy if exists transactions_select on public.transactions;
drop policy if exists transactions_insert on public.transactions;
drop policy if exists transactions_update on public.transactions;
drop policy if exists transactions_delete on public.transactions;

create policy transactions_select
on public.transactions
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy transactions_insert
on public.transactions
for insert
to authenticated
with check (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy transactions_update
on public.transactions
for update
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
)
with check (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy transactions_delete
on public.transactions
for delete
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

-- ------------------------------------------------------------
-- SALES ORDERS
-- ------------------------------------------------------------

drop policy if exists sales_orders_select on public.sales_orders;
drop policy if exists sales_orders_insert on public.sales_orders;
drop policy if exists sales_orders_update on public.sales_orders;
drop policy if exists sales_orders_delete on public.sales_orders;

create policy sales_orders_select
on public.sales_orders
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy sales_orders_insert
on public.sales_orders
for insert
to authenticated
with check (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy sales_orders_update
on public.sales_orders
for update
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
)
with check (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

create policy sales_orders_delete
on public.sales_orders
for delete
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      company_id = private.current_company_id()
      and warehouse_id = private.current_warehouse_id()
    )
  )
);

-- ------------------------------------------------------------
-- ACTIVITY LOGS
-- ------------------------------------------------------------

drop policy if exists activity_logs_select on public.activity_logs;
drop policy if exists activity_logs_insert on public.activity_logs;
drop policy if exists activity_logs_update on public.activity_logs;
drop policy if exists activity_logs_delete on public.activity_logs;

create policy activity_logs_select
on public.activity_logs
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or user_id = (select auth.uid())
  )
);

create policy activity_logs_insert
on public.activity_logs
for insert
to authenticated
with check (
  private.is_active_user()
  and user_id = (select auth.uid())
);

create policy activity_logs_update
on public.activity_logs
for update
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy activity_logs_delete
on public.activity_logs
for delete
to authenticated
using (private.is_admin());

-- ------------------------------------------------------------
-- FUNCTION SECURITY
-- ------------------------------------------------------------

revoke all on function private.is_active_user() from public;
revoke all on function private.is_admin() from public;
revoke all on function private.current_company_id() from public;
revoke all on function private.current_warehouse_id() from public;
revoke all on function private.can_manage_users() from public;

grant execute on function private.is_active_user()
to authenticated;

grant execute on function private.is_admin()
to authenticated;

grant execute on function private.current_company_id()
to authenticated;

grant execute on function private.current_warehouse_id()
to authenticated;

grant execute on function private.can_manage_users()
to authenticated;

-- ============================================================
-- END
-- ============================================================
