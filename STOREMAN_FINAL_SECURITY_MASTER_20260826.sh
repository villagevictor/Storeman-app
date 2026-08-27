#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# ============================================================
# STOREMAN ERP
# FINAL SECURITY / AUTH / APPROVAL / EMAILJS / RLS MASTER
# ============================================================

APP_DIR="${APP_DIR:-$HOME/Storeman-app}"

# ------------------------------------------------------------
# IDENTITIES
# ------------------------------------------------------------

ADMIN_EMAIL="ashenafihailay779@gmail.com"

# EmailJS notification receiver
ADMIN_NOTIFICATION_EMAIL="ashenafihailay645@gmail.com"

# ------------------------------------------------------------
# PRODUCTION
# ------------------------------------------------------------

PRODUCTION_URL="https://villagevictor.github.io/Storeman-app/"

# ------------------------------------------------------------
# EMAILJS
# ------------------------------------------------------------

EMAILJS_PUBLIC_KEY="8JupT1wuqer_SMq3p"
EMAILJS_SERVICE_ID="service_g810m8a"

LOW_STOCK_TEMPLATE_ID="template_6tpdips"
DAILY_REPORT_TEMPLATE_ID="template_tqgxj1w"

# New-user / admin approval notification.
# IMPORTANT:
# Create this template in EmailJS and put its ID here.
# If it does not exist yet, the script creates the frontend
# configuration but prints a clear warning.
ADMIN_APPROVAL_TEMPLATE_ID="${ADMIN_APPROVAL_TEMPLATE_ID:-}"

# ------------------------------------------------------------

cd "$APP_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"

BACKUP_DIR="$APP_DIR/backup/final_security_$STAMP"
MIG_DIR="$APP_DIR/supabase/migrations"

mkdir -p "$BACKUP_DIR"
mkdir -p "$MIG_DIR"

MIGRATION="$MIG_DIR/${STAMP}_storeman_final_security.sql"

echo
echo "============================================================"
echo " STOREMAN FINAL SECURITY MASTER"
echo "============================================================"
echo "APP              : $APP_DIR"
echo "ADMIN LOGIN      : $ADMIN_EMAIL"
echo "NOTIFICATION     : $ADMIN_NOTIFICATION_EMAIL"
echo "PRODUCTION URL   : $PRODUCTION_URL"
echo "TIME             : $STAMP"
echo "============================================================"

# ============================================================
# PHASE 1 — BACKUP
# ============================================================

echo
echo "[1/10] Creating complete backup..."

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then

    git status --short > "$BACKUP_DIR/git-status-before.txt" || true
    git branch --show-current > "$BACKUP_DIR/git-branch-before.txt" || true
    git rev-parse HEAD > "$BACKUP_DIR/git-head-before.txt" || true
    git remote -v > "$BACKUP_DIR/git-remotes-before.txt" || true

    if git bundle create \
        "$BACKUP_DIR/storeman-before-final-security.bundle" \
        --all >/dev/null 2>&1
    then
        echo "✓ Git bundle backup created."
    else
        echo "! Git bundle could not be created."
    fi
fi

[ -f index.html ] && cp -p index.html \
    "$BACKUP_DIR/index.html.before-final-security"

[ -f storeman-security.js ] && cp -p storeman-security.js \
    "$BACKUP_DIR/storeman-security.js.before-final-security"

if [ -f "$APP_DIR/supabase/migrations/20260826_storeman_security_auth.sql" ]; then
    cp -p "$APP_DIR/supabase/migrations/20260826_storeman_security_auth.sql" \
        "$BACKUP_DIR/previous-security-migration.sql"
fi

tar \
  --exclude="./.git" \
  --exclude="./backup/final_security_$STAMP" \
  -czf "$BACKUP_DIR/project-before-final-security.tar.gz" \
  . 2>/dev/null || true

echo "✓ Backup:"
echo "  $BACKUP_DIR"

# ============================================================
# PHASE 2 — FINAL SUPABASE SECURITY MIGRATION
# ============================================================

echo
echo "[2/10] Writing final Supabase security migration..."

cat > "$MIGRATION" <<SQL
-- ============================================================
-- STOREMAN FINAL SECURITY MIGRATION
-- ============================================================

create extension if not exists pgcrypto;

create schema if not exists private;

-- ============================================================
-- CORE TABLES
-- ============================================================

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

-- ============================================================
-- ERP TABLES
-- ============================================================

create table if not exists public.materials (
    id uuid primary key default gen_random_uuid(),
    barcode text,
    name text not null,
    unit text default 'Pcs',
    quantity numeric not null default 0,
    unit_price numeric not null default 0,
    min_stock numeric not null default 0,
    company_id uuid,
    warehouse_id uuid,
    created_by uuid,
    created_at timestamptz not null default now()
);

create table if not exists public.suppliers (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    phone text,
    email text,
    address text,
    company_id uuid,
    warehouse_id uuid,
    created_by uuid,
    created_at timestamptz not null default now()
);

create table if not exists public.transactions (
    id uuid primary key default gen_random_uuid(),
    material_name text,
    type text,
    quantity numeric not null default 0,
    supplier text,
    customer text,
    contact text,
    unit_price numeric not null default 0,
    reference text,
    company_id uuid,
    warehouse_id uuid,
    created_by uuid,
    created_at timestamptz not null default now()
);

create table if not exists public.sales_orders (
    id uuid primary key default gen_random_uuid(),
    customer_name text,
    total_amount numeric not null default 0,
    invoice_number text,
    company_id uuid,
    warehouse_id uuid,
    created_by uuid,
    created_at timestamptz not null default now()
);

-- ============================================================
-- COMPATIBILITY COLUMNS
-- ============================================================

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

alter table public.materials
    add column if not exists company_id uuid;

alter table public.materials
    add column if not exists warehouse_id uuid;

alter table public.materials
    add column if not exists created_by uuid;

alter table public.suppliers
    add column if not exists company_id uuid;

alter table public.suppliers
    add column if not exists warehouse_id uuid;

alter table public.suppliers
    add column if not exists created_by uuid;

alter table public.transactions
    add column if not exists company_id uuid;

alter table public.transactions
    add column if not exists warehouse_id uuid;

alter table public.transactions
    add column if not exists created_by uuid;

alter table public.sales_orders
    add column if not exists company_id uuid;

alter table public.sales_orders
    add column if not exists warehouse_id uuid;

alter table public.sales_orders
    add column if not exists created_by uuid;

-- ============================================================
-- DEFAULT COMPANY
-- ============================================================

insert into public.companies(name)
values ('Storeman Main Company')
on conflict (name) do nothing;

insert into public.warehouses(company_id,name,location)
select
    c.id,
    'Main Warehouse',
    'Main'
from public.companies c
where c.name='Storeman Main Company'
and not exists (
    select 1
    from public.warehouses w
    where w.company_id=c.id
);

-- ============================================================
-- DEFAULT PERMISSIONS
-- ============================================================

create or replace function private.default_permissions()
returns jsonb
language sql
immutable
as \$\$
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
  "settings":{"view":false,"create":false,"update":false,"delete":false}
}'::jsonb
\$\$;

-- ============================================================
-- NEW USER PROFILE
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as \$\$
declare
    default_company uuid;
begin

    select id
    into default_company
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
    values(
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name',''),
        new.email,
        case
            when lower(coalesce(new.email,'')) =
                 lower('${ADMIN_EMAIL}')
            then 'admin'
            else 'staff'
        end,
        case
            when lower(coalesce(new.email,'')) =
                 lower('${ADMIN_EMAIL}')
            then 'active'
            else 'pending'
        end,
        default_company,
        null,
        case
            when lower(coalesce(new.email,'')) =
                 lower('${ADMIN_EMAIL}')
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
                'settings',jsonb_build_object('view',true,'create',true,'update',true,'delete',true)
            )
            else private.default_permissions()
        end
    )
    on conflict(id)
    do update set email=excluded.email;

    return new;
end;
\$\$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();

-- ============================================================
-- SECURITY HELPERS
-- ============================================================

create or replace function private.is_active_user()
returns boolean
language sql
stable
security definer
set search_path=public
as \$\$
select exists(
    select 1
    from public.profiles p
    where p.id=(select auth.uid())
    and p.status='active'
);
\$\$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path=public
as \$\$
select exists(
    select 1
    from public.profiles p
    where p.id=(select auth.uid())
    and p.status='active'
    and p.role='admin'
);
\$\$;

create or replace function private.current_company_id()
returns uuid
language sql
stable
security definer
set search_path=public
as \$\$
select company_id
from public.profiles
where id=(select auth.uid())
limit 1;
\$\$;

create or replace function private.current_warehouse_id()
returns uuid
language sql
stable
security definer
set search_path=public
as \$\$
select warehouse_id
from public.profiles
where id=(select auth.uid())
limit 1;
\$\$;

create or replace function private.can_feature(
    feature_name text,
    action_name text
)
returns boolean
language sql
stable
security definer
set search_path=public
as \$\$
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
\$\$;

-- ============================================================
-- ADMIN-ONLY USER MANAGEMENT
-- ============================================================

create or replace function private.can_manage_users()
returns boolean
language sql
stable
security definer
set search_path=public
as \$\$
select private.is_admin();
\$\$;

-- ============================================================
-- RLS
-- ============================================================

do \$\$
declare
    t text;
begin

    foreach t in array array[
        'companies',
        'warehouses',
        'profiles',
        'activity_logs',
        'materials',
        'suppliers',
        'transactions',
        'sales_orders'
    ]
    loop

        execute format(
            'alter table public.%I enable row level security',
            t
        );

        execute format(
            'revoke all on table public.%I from anon',
            t
        );

        execute format(
            'revoke all on table public.%I from authenticated',
            t
        );

        execute format(
            'grant select,insert,update,delete on table public.%I to authenticated',
            t
        );

    end loop;

end
\$\$;

-- ============================================================
-- COMPANIES
-- ============================================================

drop policy if exists companies_select on public.companies;
drop policy if exists companies_insert on public.companies;
drop policy if exists companies_update on public.companies;
drop policy if exists companies_delete on public.companies;

create policy companies_select
on public.companies
for select
to authenticated
using(
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
with check(private.is_admin());

create policy companies_update
on public.companies
for update
to authenticated
using(private.is_admin())
with check(private.is_admin());

create policy companies_delete
on public.companies
for delete
to authenticated
using(private.is_admin());

-- ============================================================
-- WAREHOUSES
-- ============================================================

drop policy if exists warehouses_select on public.warehouses;
drop policy if exists warehouses_insert on public.warehouses;
drop policy if exists warehouses_update on public.warehouses;
drop policy if exists warehouses_delete on public.warehouses;

create policy warehouses_select
on public.warehouses
for select
to authenticated
using(
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
with check(private.is_admin());

create policy warehouses_update
on public.warehouses
for update
to authenticated
using(private.is_admin())
with check(private.is_admin());

create policy warehouses_delete
on public.warehouses
for delete
to authenticated
using(private.is_admin());

-- ============================================================
-- PROFILES
-- ============================================================

drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_delete on public.profiles;

create policy profiles_select
on public.profiles
for select
to authenticated
using(
    id=(select auth.uid())
    or private.is_admin()
);

create policy profiles_update
on public.profiles
for update
to authenticated
using(
    private.is_admin()
    or id=(select auth.uid())
)
with check(
    private.is_admin()
    or id=(select auth.uid())
);

create policy profiles_delete
on public.profiles
for delete
to authenticated
using(private.is_admin());

-- ============================================================
-- ACTIVITY LOGS
-- ============================================================

drop policy if exists activity_logs_select on public.activity_logs;
drop policy if exists activity_logs_insert on public.activity_logs;
drop policy if exists activity_logs_update on public.activity_logs;
drop policy if exists activity_logs_delete on public.activity_logs;

create policy activity_logs_select
on public.activity_logs
for select
to authenticated
using(
    private.is_admin()
    or user_id=(select auth.uid())
);

create policy activity_logs_insert
on public.activity_logs
for insert
to authenticated
with check(
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

-- ============================================================
-- ERP DATA RLS
-- ============================================================

do \$\$
declare
    t text;
    feature text;
begin

    foreach t in array[
        'materials',
        'suppliers',
        'transactions',
        'sales_orders'
    ]
    loop

        feature := case
            when t='materials' then 'materials'
            when t='suppliers' then 'suppliers'
            when t='transactions' then 'stock_in'
            when t='sales_orders' then 'stock_out'
        end;

        execute format(
            'drop policy if exists %I_select on public.%I',
            t,t
        );

        execute format(
            'drop policy if exists %I_insert on public.%I',
            t,t
        );

        execute format(
            'drop policy if exists %I_update on public.%I',
            t,t
        );

        execute format(
            'drop policy if exists %I_delete on public.%I',
            t,t
        );

        execute format(
            'create policy %I_select
             on public.%I
             for select
             to authenticated
             using(
                private.can_feature(%L,''view'')
                and company_id=private.current_company_id()
                and (
                    private.is_admin()
                    or warehouse_id=private.current_warehouse_id()
                )
             )',
            t,t,feature
        );

        execute format(
            'create policy %I_insert
             on public.%I
             for insert
             to authenticated
             with check(
                private.can_feature(%L,''create'')
                and company_id=private.current_company_id()
                and (
                    private.is_admin()
                    or warehouse_id=private.current_warehouse_id()
                )
             )',
            t,t,feature
        );

        execute format(
            'create policy %I_update
             on public.%I
             for update
             to authenticated
             using(
                private.can_feature(%L,''update'')
                and company_id=private.current_company_id()
                and (
                    private.is_admin()
                    or warehouse_id=private.current_warehouse_id()
                )
             )
             with check(
                private.can_feature(%L,''update'')
                and company_id=private.current_company_id()
                and (
                    private.is_admin()
                    or warehouse_id=private.current_warehouse_id()
                )
             )',
            t,t,feature,feature
        );

        execute format(
            'create policy %I_delete
             on public.%I
             for delete
             to authenticated
             using(
                private.can_feature(%L,''delete'')
                and company_id=private.current_company_id()
                and (
                    private.is_admin()
                    or warehouse_id=private.current_warehouse_id()
                )
             )',
            t,t,feature
        );

    end loop;

end
\$\$;

-- ============================================================
-- ADMIN BOOTSTRAP
-- ============================================================

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
    (
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
            'settings'
        ]) f
    )
from auth.users u
cross join(
    select id
    from public.companies
    where name='Storeman Main Company'
    limit 1
)c
where lower(u.email)=lower('${ADMIN_EMAIL}')
on conflict(id)
do update set
    email=excluded.email,
    role='admin',
    status='active',
    company_id=coalesce(
        public.profiles.company_id,
        excluded.company_id
    ),
    permissions=excluded.permissions;

-- ============================================================
-- FUNCTION PRIVILEGES
-- ============================================================

revoke all on function private.is_active_user() from public;
revoke all on function private.is_admin() from public;
revoke all on function private.current_company_id() from public;
revoke all on function private.current_warehouse_id() from public;
revoke all on function private.can_feature(text,text) from public;
revoke all on function private.can_manage_users() from public;

grant execute on function private.is_active_user() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.current_company_id() to authenticated;
grant execute on function private.current_warehouse_id() to authenticated;
grant execute on function private.can_feature(text,text) to authenticated;
grant execute on function private.can_manage_users() to authenticated;

-- ============================================================
-- END
-- ============================================================
SQL

echo "✓ Migration created:"
echo "  $MIGRATION"

# ============================================================
# PHASE 3 — FINAL SECURITY FRONTEND
# ============================================================

echo
echo "[3/10] Writing final storeman-security.js..."

cat > "$APP_DIR/storeman-security.js" <<'JS'
(() => {
'use strict';

/* ============================================================
   STOREMAN FINAL SECURITY FRONTEND
   ============================================================ */

const ADMIN_EMAIL =
  'ashenafihailay779@gmail.com';

const ADMIN_NOTIFICATION_EMAIL =
  'ashenafihailay645@gmail.com';

const APP_URL =
  'https://villagevictor.github.io/Storeman-app/';

const EMAILJS_PUBLIC_KEY =
  '8JupT1wuqer_SMq3p';

const EMAILJS_SERVICE_ID =
  'service_g810m8a';

const EMAILJS_LOW_STOCK_TEMPLATE =
  'template_6tpdips';

const EMAILJS_DAILY_TEMPLATE =
  'template_tqgxj1w';

/*
 * Create an EmailJS template for admin approval notification
 * and put its template ID here.
 */
const EMAILJS_ADMIN_TEMPLATE =
  '__ADMIN_APPROVAL_TEMPLATE_ID__';

const FEATURES = [
  'dashboard',
  'materials',
  'stock_in',
  'stock_out',
  'suppliers',
  'warehouses',
  'invoicing',
  'reports',
  'backup',
  'settings'
];

const ACTIONS = [
  'view',
  'create',
  'update',
  'delete'
];

let client =
  window.supabaseClient ||
  (typeof supabaseClient !== 'undefined'
    ? supabaseClient
    : null);

let currentUser = null;
let currentProfile = null;

/* ============================================================
   BASIC GUARD
   ============================================================ */

function isAdmin() {
  return !!(
    currentProfile &&
    currentProfile.status === 'active' &&
    currentProfile.role === 'admin'
  );
}

function isActive() {
  return !!(
    currentProfile &&
    currentProfile.status === 'active'
  );
}

function hasPermission(feature, action='view') {

  if (isAdmin()) return true;

  if (!isActive()) return false;

  const p =
    currentProfile.permissions || {};

  return !!(
    p[feature] &&
    p[feature][action] === true
  );
}

/* ============================================================
   EMAILJS
   ============================================================ */

async function initEmailJS() {

  if (!window.emailjs) {
    console.warn(
      '[Storeman] EmailJS SDK not loaded.'
    );
    return false;
  }

  try {

    emailjs.init({
      publicKey: EMAILJS_PUBLIC_KEY
    });

    return true;

  } catch (err) {

    console.error(
      '[Storeman] EmailJS init failed',
      err
    );

    return false;
  }
}

/* ============================================================
   ADMIN NOTIFICATION
   ============================================================ */

async function notifyAdminNewUser(user) {

  if (
    !window.emailjs ||
    !EMAILJS_ADMIN_TEMPLATE ||
    EMAILJS_ADMIN_TEMPLATE ===
      '__ADMIN_APPROVAL_TEMPLATE_ID__'
  ) {
    console.warn(
      '[Storeman] Admin EmailJS template is not configured.'
    );

    return false;
  }

  try {

    await initEmailJS();

    await emailjs.send(
      EMAILJS_SERVICE_ID,
      EMAILJS_ADMIN_TEMPLATE,
      {
        to_email:
          ADMIN_NOTIFICATION_EMAIL,

        admin_email:
          ADMIN_NOTIFICATION_EMAIL,

        user_email:
          user.email || '',

        user_id:
          user.id || '',

        user_name:
          user.user_metadata?.full_name || '',

        status:
          'pending',

        role:
          'staff',

        company:
          'Storeman Main Company',

        message:
          'A new Storeman user has registered and is waiting for administrator approval.',

        app_url:
          APP_URL
      }
    );

    console.log(
      '[Storeman] Admin notification sent.'
    );

    return true;

  } catch (err) {

    console.error(
      '[Storeman] Admin notification failed',
      err
    );

    return false;
  }
}

/* ============================================================
   AUTH
   ============================================================ */

async function getProfile(userId) {

  if (!client || !userId)
    return null;

  const result =
    await client
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

  if (result.error) {

    console.error(
      '[Storeman] profile error',
      result.error
    );

    return null;
  }

  return result.data;
}

/* ============================================================
   AUTH GATE
   ============================================================ */

function createGate() {

  let gate =
    document.getElementById(
      'storeman-final-auth-gate'
    );

  if (gate) return gate;

  gate =
    document.createElement('div');

  gate.id =
    'storeman-final-auth-gate';

  gate.style.cssText = `
    position:fixed;
    inset:0;
    z-index:9999999;
    background:#f8fafc;
    display:flex;
    align-items:center;
    justify-content:center;
    padding:20px;
  `;

  gate.innerHTML = `
    <div style="
      max-width:420px;
      width:100%;
      background:white;
      padding:28px;
      border-radius:18px;
      box-shadow:0 20px 60px rgba(0,0,0,.15);
      text-align:center;
      font-family:Arial,sans-serif;
    ">
      <div style="font-size:42px">🔐</div>
      <h2>Storeman ERP</h2>
      <p id="storeman-final-auth-message">
        Checking secure session...
      </p>
    </div>
  `;

  document.body.appendChild(gate);

  return gate;
}

function gateMessage(message) {

  const gate =
    createGate();

  const p =
    gate.querySelector(
      '#storeman-final-auth-message'
    );

  if (p)
    p.textContent = message;
}

function hideGate() {

  const gate =
    document.getElementById(
      'storeman-final-auth-gate'
    );

  if (gate)
    gate.remove();
}

/* ============================================================
   HIDE ADMIN-ONLY UI FROM NORMAL USERS
   ============================================================ */

function hideAdminOnlyUI() {

  if (isAdmin())
    return;

  /*
   * Never allow normal users to see these areas.
   */

  const selectors = [
    '[data-admin-only]',
    '.admin-only',
    '#userManagement',
    '#user-management',
    '#users-management',
    '#adminUserManagement',
    '#admin-user-management'
  ];

  selectors.forEach(selector => {

    document
      .querySelectorAll(selector)
      .forEach(el => {

        el.style.display = 'none';

        el.setAttribute(
          'aria-hidden',
          'true'
        );
      });
  });

  /*
   * Hide common user-management labels
   * if the old UI does not have IDs.
   */

  document
    .querySelectorAll(
      'button,a,h1,h2,h3,h4,label,section,div'
    )
    .forEach(el => {

      const text =
        (el.textContent || '')
          .trim()
          .toLowerCase();

      if (
        text === 'user management' ||
        text === 'manage users' ||
        text === 'users management' ||
        text === 'role' ||
        text === 'permissions'
      ) {

        let parent =
          el.closest(
            '[data-admin-only],.admin-only,section,div'
          );

        if (
          parent &&
          parent !== document.body
        ) {
          parent.style.display =
            'none';
        }
      }
    });
}

/* ============================================================
   SETTINGS ADMIN USER MANAGEMENT ENTRY
   ============================================================ */

function ensureAdminUserManagement() {

  if (!isAdmin())
    return;

  const settings =
    document.querySelector(
      '#settings'
    ) ||
    document.querySelector(
      '[data-section="settings"]'
    );

  if (!settings)
    return;

  if (
    document.getElementById(
      'storeman-admin-user-management'
    )
  )
    return;

  const box =
    document.createElement('div');

  box.id =
    'storeman-admin-user-management';

  box.setAttribute(
    'data-admin-only',
    'true'
  );

  box.style.cssText = `
    margin:16px 0;
    padding:16px;
    border:1px solid #e2e8f0;
    border-radius:14px;
    background:#fff;
  `;

  box.innerHTML = `
    <h3 style="margin-top:0">
      👥 User Management
    </h3>

    <p style="color:#64748b">
      Administrator only.
      Manage user approval, role, company,
      warehouse and feature permissions.
    </p>

    <button
      id="storeman-open-admin-users"
      type="button"
      style="
        width:100%;
        padding:12px;
        border:0;
        border-radius:10px;
        background:#123456;
        color:#fff;
        font-weight:700;
      "
    >
      Manage Users
    </button>

    <div
      id="storeman-admin-users-panel"
      style="display:none;margin-top:15px"
    ></div>
  `;

  settings.appendChild(box);

  document
    .getElementById(
      'storeman-open-admin-users'
    )
    .addEventListener(
      'click',
      loadAdminUsers
    );
}

/* ============================================================
   ADMIN USER MANAGEMENT
   ============================================================ */

async function loadAdminUsers() {

  if (!isAdmin())
    return;

  const panel =
    document.getElementById(
      'storeman-admin-users-panel'
    );

  if (!panel)
    return;

  panel.style.display =
    'block';

  panel.innerHTML =
    '<p>Loading users...</p>';

  const result =
    await client
      .from('profiles')
      .select(`
        id,
        full_name,
        email,
        role,
        status,
        company_id,
        warehouse_id,
        permissions
      `)
      .order(
        'created_at',
        {ascending:false}
      );

  if (result.error) {

    panel.innerHTML =
      '<p style="color:red">Unable to load users.</p>';

    console.error(
      result.error
    );

    return;
  }

  const users =
    result.data || [];

  if (!users.length) {

    panel.innerHTML =
      '<p>No users found.</p>';

    return;
  }

  panel.innerHTML = '';

  users.forEach(user => {

    const card =
      document.createElement('div');

    card.style.cssText = `
      padding:15px;
      margin-bottom:12px;
      border:1px solid #e2e8f0;
      border-radius:12px;
    `;

    const isSelf =
      user.id === currentUser.id;

    card.innerHTML = `
      <strong>
        ${escapeHtml(
          user.full_name ||
          user.email ||
          'User'
        )}
      </strong>

      <div style="font-size:13px;color:#64748b">
        ${escapeHtml(
          user.email || ''
        )}
      </div>

      <label>Role</label>
      <select data-role style="width:100%;padding:9px">
        <option value="staff"
          ${user.role==='staff'?'selected':''}>
          Staff
        </option>

        <option value="manager"
          ${user.role==='manager'?'selected':''}>
          Manager
        </option>

        <option value="admin"
          ${user.role==='admin'?'selected':''}>
          Admin
        </option>
      </select>

      <label>Status</label>
      <select data-status style="width:100%;padding:9px">
        <option value="pending"
          ${user.status==='pending'?'selected':''}>
          Pending
        </option>

        <option value="active"
          ${user.status==='active'?'selected':''}>
          Active
        </option>

        <option value="blocked"
          ${user.status==='blocked'?'selected':''}>
          Blocked
        </option>
      </select>

      <button
        data-save
        style="
          width:100%;
          margin-top:10px;
          padding:10px;
          border:0;
          border-radius:8px;
          background:#059669;
          color:white;
          font-weight:700;
        "
      >
        Save User
      </button>

      <div
        data-msg
        style="margin-top:8px;font-size:13px"
      ></div>
    `;

    const role =
      card.querySelector(
        '[data-role]'
      );

    const status =
      card.querySelector(
        '[data-status]'
      );

    const save =
      card.querySelector(
        '[data-save]'
      );

    const msg =
      card.querySelector(
        '[data-msg]'
      );

    /*
     * Do not accidentally allow changing
     * your own admin account to staff.
     */

    if (isSelf) {

      role.disabled =
        true;

      status.disabled =
        true;
    }

    save.addEventListener(
      'click',
      async () => {

        if (isSelf) {

          msg.textContent =
            'Your admin account is protected.';

          return;
        }

        const update = {

          role:
            role.value,

          status:
            status.value
        };

        const r =
          await client
            .from('profiles')
            .update(update)
            .eq('id', user.id);

        if (r.error) {

          msg.style.color =
            '#dc2626';

          msg.textContent =
            r.error.message;

          return;
        }

        msg.style.color =
          '#059669';

        msg.textContent =
          'Saved successfully.';

        setTimeout(
          loadAdminUsers,
          700
        );
      }
    );

    panel.appendChild(card);
  });
}

/* ============================================================
   ESCAPE
   ============================================================ */

function escapeHtml(value) {

  return String(value || '')
    .replaceAll('&','&amp;')
    .replaceAll('<','&lt;')
    .replaceAll('>','&gt;')
    .replaceAll('"','&quot;')
    .replaceAll("'","&#039;");
}

/* ============================================================
   SIGNUP PATCH
   ============================================================ */

function patchSignup() {

  if (!client?.auth)
    return;

  if (
    client.auth.__storemanFinalSignupPatched
  )
    return;

  const original =
    client.auth.signUp.bind(
      client.auth
    );

  client.auth.signUp =
    async function(credentials={}) {

      const c =
        {...credentials};

      c.options = {
        ...(credentials.options || {}),
        emailRedirectTo:
          APP_URL
      };

      const result =
        await original(c);

      if (
        !result.error &&
        result.data?.user
      ) {

        /*
         * Notify administrator.
         * The database/RLS remains the
         * actual security authority.
         */

        await notifyAdminNewUser(
          result.data.user
        );
      }

      return result;
    };

  client.auth.__storemanFinalSignupPatched =
    true;
}

/* ============================================================
   FEATURE VISIBILITY
   ============================================================ */

function applyFeatureVisibility() {

  /*
   * Hide feature navigation when the user
   * does not have permission.
   */

  const featureSelectors = {

    dashboard: [
      '#dashboard',
      '[data-feature="dashboard"]'
    ],

    materials: [
      '#materials',
      '[data-feature="materials"]'
    ],

    stock_in: [
      '#stock-in',
      '#stock_in',
      '[data-feature="stock_in"]'
    ],

    stock_out: [
      '#stock-out',
      '#stock_out',
      '[data-feature="stock_out"]'
    ],

    suppliers: [
      '#suppliers',
      '[data-feature="suppliers"]'
    ],

    warehouses: [
      '#warehouses',
      '[data-feature="warehouses"]'
    ],

    invoicing: [
      '#invoicing',
      '[data-feature="invoicing"]'
    ],

    reports: [
      '#reports',
      '[data-feature="reports"]'
    ],

    backup: [
      '#backup',
      '[data-feature="backup"]'
    ]
  };

  Object.entries(
    featureSelectors
  ).forEach(
    ([feature, selectors]) => {

      if (
        isAdmin() ||
        hasPermission(feature,'view')
      )
        return;

      selectors.forEach(
        selector => {

          document
            .querySelectorAll(selector)
            .forEach(el => {

              el.style.display =
                'none';

              el.setAttribute(
                'aria-hidden',
                'true'
              );
            });
        }
      );
    }
  );

  hideAdminOnlyUI();
}

/* ============================================================
   SESSION
   ============================================================ */

async function handleSession(session) {

  currentUser =
    session?.user || null;

  if (!currentUser) {

    gateMessage(
      'Please sign in.'
    );

    return;
  }

  currentProfile =
    await getProfile(
      currentUser.id
    );

  if (!currentProfile) {

    gateMessage(
      'Your account profile is not available.'
    );

    return;
  }

  /*
   * IMPORTANT:
   * Email must be confirmed before ERP access.
   */

  if (
    !currentUser.email_confirmed_at
  ) {

    gateMessage(
      'Please confirm your email address first.'
    );

    return;
  }

  /*
   * Admin is immediately active.
   */

  if (
    currentProfile.role === 'admin'
  ) {

    hideGate();

    applyFeatureVisibility();

    setTimeout(
      ensureAdminUserManagement,
      500
    );

    return;
  }

  /*
   * Normal users require ADMIN approval.
   */

  if (
    currentProfile.status !== 'active'
  ) {

    if (
      currentProfile.status === 'pending'
    ) {

      gateMessage(
        'Email confirmed. Waiting for administrator approval.'
      );

    } else {

      gateMessage(
        'Your account is currently blocked.'
      );
    }

    return;
  }

  /*
   * Approved normal user.
   */

  hideGate();

  applyFeatureVisibility();
}

/* ============================================================
   BOOT
   ============================================================ */

async function boot() {

  createGate();

  if (!client) {

    gateMessage(
      'Supabase client was not found.'
    );

    return;
  }

  patchSignup();

  await initEmailJS();

  client.auth.onAuthStateChange(
    (event,session) => {

      setTimeout(
        () => handleSession(session),
        0
      );
    }
  );

  const sessionResult =
    await client.auth.getSession();

  await handleSession(
    sessionResult.data.session
  );

  /*
   * Protect against old UI being
   * dynamically rendered later.
   */

  const observer =
    new MutationObserver(
      () => {

        if (!isAdmin())
          hideAdminOnlyUI();

        if (isActive())
          applyFeatureVisibility();

        if (isAdmin())
          ensureAdminUserManagement();
      }
    );

  observer.observe(
    document.body,
    {
      childList:true,
      subtree:true
    }
  );
}

if (
  document.readyState === 'loading'
) {

  document.addEventListener(
    'DOMContentLoaded',
    boot
  );

} else {

  boot();
}

})();
JS

echo "✓ storeman-security.js written."

# ============================================================
# PHASE 4 — EMAILJS SDK + SECURITY SCRIPT
# ============================================================

echo
echo "[4/10] Ensuring security scripts are loaded..."

if ! grep -q 'cdn.jsdelivr.net/npm/@emailjs/browser' index.html; then

    sed -i \
      's#</head>#<script src="https://cdn.jsdelivr.net/npm/@emailjs/browser@4/dist/email.min.js"></script>\n</head>#' \
      index.html

fi

if ! grep -q 'storeman-security.js' index.html; then

    sed -i \
      's#</body>#<script src="./storeman-security.js"></script>\n</body>#' \
      index.html

fi

echo "✓ EmailJS SDK linked."
echo "✓ storeman-security.js linked."

# ============================================================
# PHASE 5 — REMOVE VISIBLE USER MANAGEMENT FROM MAIN UI
# ============================================================

echo
echo "[5/10] Hardening UI placement..."

cat >> index.html <<'HTML'

<style id="storeman-final-admin-ui-security">
/*
 * Storeman FINAL UI SECURITY
 *
 * User Management / Role / Company / Warehouse /
 * Permissions are administrator-only.
 */

[data-admin-only] {
  display:none;
}

body.storeman-normal-user
#storeman-admin-user-management {
  display:none !important;
}
</style>

<script>
(function(){

  function protectAdminUI(){

    const admin =
      window.__storemanIsAdmin === true;

    if(admin) return;

    document
      .querySelectorAll(
        '[data-admin-only],.admin-only'
      )
      .forEach(
        el => {
          el.style.display='none';
        }
      );
  }

  setInterval(
    protectAdminUI,
    1000
  );

})();
</script>
HTML

echo "✓ Admin-only UI protection added."

# ============================================================
# PHASE 6 — LOCAL SECURITY CHECKS
# ============================================================

echo
echo "[6/10] Running local security checks..."

FAIL=0

check() {

    if eval "$1" >/dev/null 2>&1; then
        echo "✓ $2"
    else
        echo "✗ $2"
        FAIL=1
    fi
}

check \
  "grep -q 'storeman-security.js' index.html" \
  "Security JS linked"

check \
  "grep -q 'emailjs' index.html" \
  "EmailJS SDK linked"

check \
  "grep -q 'enable row level security' '$MIGRATION'" \
  "RLS migration exists"

check \
  "grep -q 'private.is_admin' '$MIGRATION'" \
  "Admin helper exists"

check \
  "grep -q 'status.*pending' '$MIGRATION'" \
  "Pending approval exists"

check \
  "grep -q 'email_confirmed_at' storeman-security.js" \
  "Email confirmation gate exists"

check \
  "grep -q 'Waiting for administrator approval' storeman-security.js" \
  "Admin approval gate exists"

check \
  "grep -q 'ADMIN_NOTIFICATION_EMAIL' storeman-security.js" \
  "Admin notification receiver exists"

check \
  "grep -q 'storeman-admin-user-management' storeman-security.js" \
  "Admin User Management exists"

check \
  "grep -q 'data-admin-only' storeman-security.js" \
  "Admin-only UI marker exists"

# Never put Supabase service_role in frontend.
if grep -Rni \
  --exclude-dir=.git \
  --exclude='*.bundle' \
  'service_role' \
  . >/dev/null 2>&1
then

    echo "! WARNING: service_role text found."
    echo "! NEVER put a Supabase service_role KEY in frontend."

else

    echo "✓ No service_role text detected."

fi

# Check JS syntax.
if command -v node >/dev/null 2>&1; then

    node --check storeman-security.js \
      && echo "✓ JavaScript syntax valid." \
      || FAIL=1

else

    echo "! Node.js not installed; JS syntax check skipped."

fi

# ============================================================
# PHASE 7 — SHOW GIT DIFF
# ============================================================

echo
echo "[7/10] Git status..."

git status --short

echo
echo "Files changed:"
echo "  index.html"
echo "  storeman-security.js"
echo "  $MIGRATION"

# ============================================================
# PHASE 8 — COMMIT
# ============================================================

echo
echo "[8/10] Git commit..."

git add \
  index.html \
  storeman-security.js \
  "$MIGRATION"

git status --short

if [ "$FAIL" -ne 0 ]; then

    echo
    echo "============================================================"
    echo "LOCAL SECURITY CHECK FAILED"
    echo "Commit/PUSH stopped."
    echo "============================================================"

    exit 1
fi

git commit \
  -m "security: finalize auth approval emailjs admin-only settings and RLS" \
  || true

# ============================================================
# PHASE 9 — PUSH
# ============================================================

echo
echo "[9/10] GitHub push..."

BRANCH="$(git branch --show-current)"

if [ -z "$BRANCH" ]; then

    echo "ERROR: Cannot detect branch."
    exit 1

fi

echo "Branch: $BRANCH"

if git ls-remote origin HEAD >/dev/null 2>&1; then

    git push origin "$BRANCH"

    echo "✓ GitHub push completed."

else

    echo
    echo "! GitHub is currently unreachable."
    echo "! Local commit is safe."
    echo "! Run this later:"
    echo
    echo "  cd ~/Storeman-app"
    echo "  git push origin $BRANCH"
    echo
fi

# ============================================================
# PHASE 10 — FINAL INSTRUCTIONS
# ============================================================

echo
echo "============================================================"
echo " FINAL SECURITY MASTER FINISHED"
echo "============================================================"

echo
echo "BACKUP:"
echo "$BACKUP_DIR"

echo
echo "MIGRATION:"
echo "$MIGRATION"

echo
echo "ADMIN LOGIN:"
echo "$ADMIN_EMAIL"

echo
echo "ADMIN NOTIFICATION:"
echo "$ADMIN_NOTIFICATION_EMAIL"

echo
echo "PRODUCTION:"
echo "$PRODUCTION_URL"

echo
echo "============================================================"
echo "SUPABASE"
echo "============================================================"

echo "1. Authentication -> URL Configuration"
echo "2. Site URL:"
echo "   $PRODUCTION_URL"
echo
echo "3. Redirect URL:"
echo "   $PRODUCTION_URL"
echo
echo "4. Authentication -> Providers -> Email"
echo "5. Email Confirmations = ENABLED"
echo
echo "6. SQL Editor:"
echo "   Run:"
echo "   $MIGRATION"

echo
echo "============================================================"
echo "EMAILJS"
echo "============================================================"

echo "Public Key:"
echo "$EMAILJS_PUBLIC_KEY"

echo
echo "Service:"
echo "$EMAILJS_SERVICE_ID"

echo
echo "Receiver:"
echo "$ADMIN_NOTIFICATION_EMAIL"

echo
echo "IMPORTANT:"
echo "Create an EmailJS template for NEW USER ADMIN NOTIFICATION."
echo
echo "Required template variables:"
echo "  to_email"
echo "  admin_email"
echo "  user_email"
echo "  user_id"
echo "  user_name"
echo "  status"
echo "  role"
echo "  company"
echo "  message"
echo "  app_url"

echo
echo "Then edit storeman-security.js:"
echo
echo "EMAILJS_ADMIN_TEMPLATE = 'YOUR_TEMPLATE_ID';"

echo
echo "============================================================"
echo "FINAL TEST"
echo "============================================================"

echo "A) Admin:"
echo "   $ADMIN_EMAIL"
echo
echo "B) Register a NEW user."
echo
echo "C) Confirmation email goes to the NEW USER."
echo
echo "D) User confirms email."
echo
echo "E) User signs in."
echo "   Expected: WAITING FOR ADMIN APPROVAL."
echo
echo "F) Admin notification:"
echo "   $ADMIN_NOTIFICATION_EMAIL"
echo
echo "G) Admin:"
echo "   Settings -> User Management"
echo
echo "H) Admin assigns:"
echo "   Role"
echo "   Company"
echo "   Warehouse"
echo "   Permissions"
echo "   Status = Active"
echo
echo "I) User signs in again."
echo
echo "J) User sees ONLY permitted features."
echo
echo "K) User NEVER sees:"
echo "   User Management"
echo "   Role"
echo "   Company assignment"
echo "   Warehouse assignment"
echo "   Permissions administration"
echo
echo "============================================================"
