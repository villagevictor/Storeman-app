-- ============================================================
-- STOREMAN FINAL SECURITY / AUTH / ADMIN USER MANAGEMENT
-- ============================================================

create extension if not exists pgcrypto;

create schema if not exists private;

-- ------------------------------------------------------------
-- CORE TABLES
-- ------------------------------------------------------------

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.warehouses (
  id uuid primary key default gen_random_uuid(),
  company_id uuid,
  name text not null,
  location text,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text not null default 'staff',
  status text not null default 'pending',
  company_id uuid,
  warehouse_id uuid,
  permissions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  entity text,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- COMPATIBILITY COLUMNS
-- ------------------------------------------------------------

alter table public.warehouses
  add column if not exists company_id uuid;

alter table public.profiles
  add column if not exists full_name text;

alter table public.profiles
  add column if not exists email text;

alter table public.profiles
  add column if not exists role text;

alter table public.profiles
  add column if not exists status text;

alter table public.profiles
  add column if not exists company_id uuid;

alter table public.profiles
  add column if not exists warehouse_id uuid;

alter table public.profiles
  add column if not exists permissions jsonb;

alter table public.profiles
  add column if not exists created_at timestamptz default now();

alter table public.profiles
  add column if not exists updated_at timestamptz default now();

-- ------------------------------------------------------------
-- DEFAULT COMPANY
-- ------------------------------------------------------------

insert into public.companies(name)
values ('Storeman Main Company')
on conflict (name) do nothing;

insert into public.warehouses(company_id,name,location)
select c.id,'Main Warehouse','Main'
from public.companies c
where c.name='Storeman Main Company'
and not exists (
  select 1
  from public.warehouses w
  where w.company_id=c.id
);

-- ------------------------------------------------------------
-- DEFAULT PERMISSIONS
-- ------------------------------------------------------------

create or replace function private.default_permissions()
returns jsonb
language sql
immutable
as $$
select '{
  "dashboard":{"view":true,"create":false,"update":false,"delete":false},
  "materials":{"view":false,"create":false,"update":false,"delete":false},
  "stock_in":{"view":false,"create":false,"update":false,"delete":false},
  "stock_out":{"view":false,"create":false,"update":false,"delete":false},
  "suppliers":{"view":false,"create":false,"update":false,"delete":false},
  "warehouses":{"view":false,"create":false,"update":false,"delete":false},
  "invoicing":{"view":false,"create":false,"update":false,"delete":false},
  "reports":{"view":false,"create":false,"update":false,"delete":false},
  "backup":{"view":false,"create":false,"update":false,"delete":false},
  "users":{"view":false,"create":false,"update":false,"delete":false},
  "settings":{"view":true,"create":false,"update":true,"delete":false}
}'::jsonb;
$$;

-- ------------------------------------------------------------
-- ADMIN DETECTION
-- ------------------------------------------------------------

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

create or replace function private.current_company_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
select p.company_id
from public.profiles p
where p.id=(select auth.uid())
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
where p.id=(select auth.uid())
limit 1;
$$;

create or replace function private.can_feature(
  feature_name text,
  action_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
select
  private.is_admin()
  or (
    private.is_active_user()
    and coalesce(
      (
        select p.permissions
        from public.profiles p
        where p.id=(select auth.uid())
      )->feature_name->>action_name,
      'false'
    )::boolean
  );
$$;

-- ------------------------------------------------------------
-- NEW USER PROFILE
-- ------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cid uuid;
begin

  select id
  into cid
  from public.companies
  where name='Storeman Main Company'
  limit 1;

  insert into public.profiles(
    id,
    full_name,
    email,
    role,
    status,
    company_id,
    warehouse_id,
    permissions
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    new.email,
    case
      when lower(coalesce(new.email,''))=
           lower('ashenafihailay779@gmail.com')
      then 'admin'
      else 'staff'
    end,
    case
      when lower(coalesce(new.email,''))=
           lower('ashenafihailay779@gmail.com')
      then 'active'
      else 'pending'
    end,
    cid,
    null,
    case
      when lower(coalesce(new.email,''))=
           lower('ashenafihailay779@gmail.com')
      then jsonb_build_object(
        'dashboard',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'materials',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'stock_in',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'stock_out',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'suppliers',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'warehouses',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'invoicing',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'reports',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'backup',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'users',jsonb_build_object('view',true,'create',true,'update',true,'delete',true),
        'settings',jsonb_build_object('view',true,'create',true,'update',true,'delete',true)
      )
      else private.default_permissions()
    end
  )
  on conflict (id)
  do update set
    email=excluded.email;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();

-- ------------------------------------------------------------
-- PROFILE SECURITY
-- ------------------------------------------------------------

create or replace function public.prevent_profile_escalation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  if (select auth.uid())=old.id
     and not private.is_admin()
  then

    if new.role is distinct from old.role
       or new.status is distinct from old.status
       or new.company_id is distinct from old.company_id
       or new.warehouse_id is distinct from old.warehouse_id
       or new.permissions is distinct from old.permissions
    then
      raise exception
      'Only administrator can change security fields.';
    end if;

  end if;

  new.updated_at=now();

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
-- RLS
-- ------------------------------------------------------------

alter table public.companies enable row level security;
alter table public.warehouses enable row level security;
alter table public.profiles enable row level security;
alter table public.activity_logs enable row level security;

revoke all on public.companies from anon,authenticated;
revoke all on public.warehouses from anon,authenticated;
revoke all on public.profiles from anon,authenticated;
revoke all on public.activity_logs from anon,authenticated;

grant select,insert,update,delete on public.companies to authenticated;
grant select,insert,update,delete on public.warehouses to authenticated;
grant select,insert,update,delete on public.profiles to authenticated;
grant select,insert,update,delete on public.activity_logs to authenticated;

-- ------------------------------------------------------------
-- PROFILES
-- ------------------------------------------------------------

drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_delete on public.profiles;

create policy profiles_select
on public.profiles
for select
to authenticated
using (
  id=(select auth.uid())
  or private.is_admin()
);

create policy profiles_update
on public.profiles
for update
to authenticated
using (
  private.is_admin()
)
with check (
  private.is_admin()
);

create policy profiles_delete
on public.profiles
for delete
to authenticated
using (
  private.is_admin()
);

-- ------------------------------------------------------------
-- COMPANIES
-- ------------------------------------------------------------

drop policy if exists companies_select on public.companies;
drop policy if exists companies_insert on public.companies;
drop policy if exists companies_update on public.companies;
drop policy if exists companies_delete on public.companies;

create policy companies_select
on public.companies
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or id=private.current_company_id()
  )
);

create policy companies_insert
on public.companies
for insert
to authenticated
with check (private.is_admin());

create policy companies_update
on public.companies
for update
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy companies_delete
on public.companies
for delete
to authenticated
using (private.is_admin());

-- ------------------------------------------------------------
-- WAREHOUSES
-- ------------------------------------------------------------

drop policy if exists warehouses_select on public.warehouses;
drop policy if exists warehouses_insert on public.warehouses;
drop policy if exists warehouses_update on public.warehouses;
drop policy if exists warehouses_delete on public.warehouses;

create policy warehouses_select
on public.warehouses
for select
to authenticated
using (
  private.is_active_user()
  and (
    private.is_admin()
    or (
      id=private.current_warehouse_id()
      and company_id=private.current_company_id()
    )
  )
);

create policy warehouses_insert
on public.warehouses
for insert
to authenticated
with check (private.is_admin());

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
    or user_id=(select auth.uid())
  )
);

create policy activity_logs_insert
on public.activity_logs
for insert
to authenticated
with check (
  private.is_active_user()
  and user_id=(select auth.uid())
);

create policy activity_logs_update
on public.activity_logs
for update
to authenticated
using(private.is_admin())
with check(private.is_admin());

create policy activity_logs_delete
on public.activity_logs
for delete
to authenticated
using(private.is_admin());

-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------

create index if not exists profiles_email_idx
on public.profiles(lower(email));

create index if not exists profiles_status_idx
on public.profiles(status);

create index if not exists profiles_company_idx
on public.profiles(company_id);

create index if not exists profiles_warehouse_idx
on public.profiles(warehouse_id);

create index if not exists activity_logs_user_idx
on public.activity_logs(user_id,created_at desc);

-- ------------------------------------------------------------
-- FUNCTION PRIVILEGES
-- ------------------------------------------------------------

revoke all on function private.is_admin() from public;
revoke all on function private.is_active_user() from public;
revoke all on function private.current_company_id() from public;
revoke all on function private.current_warehouse_id() from public;
revoke all on function private.can_feature(text,text) from public;

grant execute on function private.is_admin() to authenticated;
grant execute on function private.is_active_user() to authenticated;
grant execute on function private.current_company_id() to authenticated;
grant execute on function private.current_warehouse_id() to authenticated;
grant execute on function private.can_feature(text,text) to authenticated;

-- ------------------------------------------------------------
-- ADMIN BOOTSTRAP
-- ------------------------------------------------------------

update public.profiles p
set
  role='admin',
  status='active',
  company_id=coalesce(
    p.company_id,
    (
      select id
      from public.companies
      where name='Storeman Main Company'
      limit 1
    )
  ),
  permissions=(
    select jsonb_object_agg(
      f,
      jsonb_build_object(
        'view',true,
        'create',true,
        'update',true,
        'delete',true
      )
    )
    from unnest(array[
      'dashboard',
      'materials',
      'stock_in',
      'stock_out',
      'suppliers',
      'warehouses',
      'invoicing',
      'reports',
      'backup',
      'users',
      'settings'
    ]) f
  )
where lower(p.email)=lower('ashenafihailay779@gmail.com');

-- ------------------------------------------------------------
-- PENDING USER VIEW FOR ADMIN
-- ------------------------------------------------------------

create or replace view public.admin_pending_users
with (security_invoker=true)
as
select
  p.id,
  p.email,
  p.full_name,
  p.role,
  p.status,
  p.company_id,
  p.warehouse_id,
  p.permissions,
  p.created_at,
  p.updated_at
from public.profiles p;

revoke all on public.admin_pending_users from anon,authenticated;

grant select on public.admin_pending_users to authenticated;

-- View is protected by underlying profiles RLS because
-- security_invoker=true.
-- ============================================================
-- END
-- ============================================================
