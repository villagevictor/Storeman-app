-- ============================================================
-- STOREMAN FINAL AUTH SECURITY
-- SIGNUP -> PROFILE -> PENDING -> ADMIN APPROVAL
-- ROLE / COMPANY / WAREHOUSE / PERMISSIONS
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- PROFILE COLUMNS
-- ------------------------------------------------------------

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
add column if not exists created_at timestamptz
default now();

alter table public.profiles
add column if not exists updated_at timestamptz
default now();

-- ------------------------------------------------------------
-- SAFE DEFAULTS
-- ------------------------------------------------------------

update public.profiles
set status = 'pending'
where status is null;

update public.profiles
set role = 'staff'
where role is null;

update public.profiles
set permissions = '{}'::jsonb
where permissions is null;

-- ------------------------------------------------------------
-- ADMIN CHECK
-- ------------------------------------------------------------

create or replace function public.storeman_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and status = 'active'
      and lower(role) in ('admin','owner')
);
$$;

-- ------------------------------------------------------------
-- ACTIVE USER CHECK
-- ------------------------------------------------------------

create or replace function public.storeman_is_active()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and status = 'active'
);
$$;

-- ------------------------------------------------------------
-- USER PROFILE ACCESS
-- ------------------------------------------------------------

alter table public.profiles
enable row level security;

drop policy if exists
profiles_select_self_or_admin
on public.profiles;

create policy
profiles_select_self_or_admin
on public.profiles
for select
to authenticated
using (
    id = auth.uid()
    or public.storeman_is_admin()
);

-- ------------------------------------------------------------
-- ADMIN ONLY UPDATE
-- ------------------------------------------------------------

drop policy if exists
profiles_admin_update
on public.profiles;

create policy
profiles_admin_update
on public.profiles
for update
to authenticated
using (
    public.storeman_is_admin()
)
with check (
    public.storeman_is_admin()
);

-- ------------------------------------------------------------
-- ADMIN ONLY DELETE
-- ------------------------------------------------------------

drop policy if exists
profiles_admin_delete
on public.profiles;

create policy
profiles_admin_delete
on public.profiles
for delete
to authenticated
using (
    public.storeman_is_admin()
);

-- ------------------------------------------------------------
-- NEW USER PROFILE TRIGGER
-- ------------------------------------------------------------

create or replace function public.storeman_create_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    insert into public.profiles (
        id,
        full_name,
        email,
        role,
        status,
        permissions
    )
    values (
        new.id,
        coalesce(
            new.raw_user_meta_data->>'full_name',
            ''
        ),
        lower(new.email),
        'staff',
        'pending',
        '{}'::jsonb
    )
    on conflict (id)
    do update set
        email = excluded.email,
        full_name =
            case
                when public.profiles.full_name is null
                     or public.profiles.full_name = ''
                then excluded.full_name
                else public.profiles.full_name
            end;

    return new;

end;
$$;

drop trigger if exists
storeman_auth_user_profile
on auth.users;

create trigger
storeman_auth_user_profile
after insert on auth.users
for each row
execute function public.storeman_create_profile();

-- ------------------------------------------------------------
-- ADMIN BOOTSTRAP
-- ------------------------------------------------------------

update public.profiles
set
    role = 'admin',
    status = 'active',
    permissions = jsonb_build_object(

        'dashboard',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'materials',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'stock_in',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'stock_out',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'suppliers',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'warehouses',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'customers',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'invoices',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'transactions',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'reports',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'backup',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'whatsapp',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'settings',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        ),

        'users',
        jsonb_build_object(
            'view',true,
            'create',true,
            'update',true,
            'delete',true
        )

    ),
    updated_at = now()
where lower(email) =
      lower('ashenafihailay779@gmail.com');

-- ------------------------------------------------------------
-- FUNCTION SECURITY
-- ------------------------------------------------------------

revoke all
on function public.storeman_is_admin()
from public;

revoke all
on function public.storeman_is_active()
from public;

grant execute
on function public.storeman_is_admin()
to authenticated;

grant execute
on function public.storeman_is_active()
to authenticated;

-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------

create index if not exists
profiles_email_lower_idx
on public.profiles(lower(email));

create index if not exists
profiles_status_idx
on public.profiles(status);

create index if not exists
profiles_role_idx
on public.profiles(role);

-- ------------------------------------------------------------
-- VERIFY ADMIN
-- ------------------------------------------------------------

select
    id,
    email,
    role,
    status,
    permissions
from public.profiles
where lower(email) =
      lower('ashenafihailay779@gmail.com');

-- ============================================================
-- END
-- ============================================================
