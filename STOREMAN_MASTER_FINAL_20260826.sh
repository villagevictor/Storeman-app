#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

APP="$HOME/Storeman-app"
cd "$APP"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="backup/final_security_${STAMP}"
SQL="supabase/migrations/${STAMP}_storeman_final_security.sql"

ADMIN_EMAIL="ashenafihailay779@gmail.com"
RECEIVER_EMAIL="ashenafihailay645@gmail.com"

EMAILJS_PUBLIC_KEY="8JupT1wuqer_SMq3p"
EMAILJS_SERVICE_ID="service_g810m8a"
EMAILJS_LOW_TEMPLATE="template_6tpdips"
EMAILJS_DAILY_TEMPLATE="template_tqgxj1w"

SITE_URL="https://villagevictor.github.io/Storeman-app/"

echo
echo "============================================================"
echo " STOREMAN FINAL MASTER SECURITY BUILD"
echo "============================================================"
echo "Time: $STAMP"
echo "Admin: $ADMIN_EMAIL"
echo "Notification: $RECEIVER_EMAIL"
echo "Site: $SITE_URL"
echo "============================================================"

mkdir -p "$BACKUP"
mkdir -p "$(dirname "$SQL")"

# ------------------------------------------------------------
# 1. BACKUP
# ------------------------------------------------------------

echo
echo "===== 1. BACKUP ====="

git status --short > "$BACKUP/git-status-before.txt" || true
git branch --show-current > "$BACKUP/git-branch-before.txt" || true
git rev-parse HEAD > "$BACKUP/git-head-before.txt" || true
git remote -v > "$BACKUP/git-remotes-before.txt" || true

cp -f index.html "$BACKUP/index.html.before-final-security" 2>/dev/null || true
cp -f storeman-security.js "$BACKUP/storeman-security.js.before-final-security" 2>/dev/null || true

tar \
  --exclude='.git' \
  --exclude='backup' \
  -czf "$BACKUP/project-before-final-security.tar.gz" . \
  2>/dev/null || true

echo "Backup created:"
echo "$BACKUP"

# ------------------------------------------------------------
# 2. FINAL SECURITY SQL
# ------------------------------------------------------------

echo
echo "===== 2. WRITE FINAL SUPABASE SECURITY SQL ====="

cat > "$SQL" <<'SQL'
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
SQL

echo "SQL created: $SQL"

# ------------------------------------------------------------
# 3. ADMIN MANAGEMENT FRONTEND
# ------------------------------------------------------------

echo
echo "===== 3. CREATE ADMIN USER MANAGEMENT MODULE ====="

cat > storeman-admin-management.js <<'JS'
(function () {
  'use strict';

  const ADMIN_EMAIL = 'ashenafihailay779@gmail.com';
  const RECEIVER_EMAIL = 'ashenafihailay645@gmail.com';

  const EMAILJS_PUBLIC_KEY = '8JupT1wuqer_SMq3p';
  const EMAILJS_SERVICE_ID = 'service_g810m8a';

  /*
   * IMPORTANT:
   * Use the existing Supabase client from the Storeman app.
   * We do not expose any Supabase secret/service-role key here.
   */

  function getSupabase() {
    return (
      window.supabaseClient ||
      window.supabase ||
      window.storemanSupabase ||
      null
    );
  }

  function isAdminProfile(profile) {
    return profile &&
      String(profile.role || '').toLowerCase() === 'admin' &&
      String(profile.status || '').toLowerCase() === 'active';
  }

  async function getCurrentProfile() {
    const sb = getSupabase();
    if (!sb) throw new Error('Supabase client not found.');

    const { data: authData, error: authError } =
      await sb.auth.getUser();

    if (authError) throw authError;

    const user = authData && authData.user;

    if (!user) return null;

    const { data, error } =
      await sb
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();

    if (error) throw error;

    return data;
  }

  function escapeHTML(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

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
    'users',
    'settings'
  ];

  const ACTIONS = [
    'view',
    'create',
    'update',
    'delete'
  ];

  function defaultPermissions() {
    const p = {};
    FEATURES.forEach(feature => {
      p[feature] = {};
      ACTIONS.forEach(action => {
        p[feature][action] = feature === 'dashboard' && action === 'view';
      });
    });
    return p;
  }

  async function sendAdminNotification(userEmail, type) {
    try {
      if (!window.emailjs) {
        console.warn('EmailJS is not loaded.');
        return false;
      }

      if (!window.__storemanEmailJSInitialized) {
        emailjs.init({
          publicKey: EMAILJS_PUBLIC_KEY
        });
        window.__storemanEmailJSInitialized = true;
      }

      /*
       * The existing low-stock template is NOT reused for auth.
       * Admin notification needs an AUTH template.
       *
       * If the template is not yet created, this function records
       * the failure in console without breaking approval.
       */

      const authTemplate =
        window.STOREMAN_AUTH_NOTIFICATION_TEMPLATE_ID ||
        'template_auth_admin';

      const params = {
        to_email: RECEIVER_EMAIL,
        admin_email: ADMIN_EMAIL,
        user_email: userEmail,
        event_type: type,
        app_name: 'Storeman ERP',
        timestamp: new Date().toISOString(),
        message:
          'A Storeman user requires administrator attention: ' +
          userEmail
      };

      const result = await emailjs.send(
        'service_g810m8a',
        authTemplate,
        params
      );

      console.log('Admin notification sent:', result);

      return true;

    } catch (error) {
      console.error(
        'Admin notification failed:',
        error
      );

      return false;
    }
  }

  function renderPermissionEditor(existing) {

    const permissions =
      existing || defaultPermissions();

    return FEATURES.map(feature => {

      const fp = permissions[feature] || {};

      return `
        <div class="storeman-permission-card">
          <strong>${escapeHTML(feature)}</strong>

          <div class="storeman-permission-actions">

            ${ACTIONS.map(action => `
              <label>
                <input
                  type="checkbox"
                  data-permission-feature="${escapeHTML(feature)}"
                  data-permission-action="${escapeHTML(action)}"
                  ${fp[action] ? 'checked' : ''}
                >
                ${escapeHTML(action)}
              </label>
            `).join('')}

          </div>
        </div>
      `;
    }).join('');
  }

  async function loadCompaniesAndWarehouses() {

    const sb = getSupabase();

    const companies =
      await sb
        .from('companies')
        .select('id,name')
        .order('name');

    const warehouses =
      await sb
        .from('warehouses')
        .select('id,name,company_id')
        .order('name');

    return {
      companies: companies.data || [],
      warehouses: warehouses.data || []
    };
  }

  async function findUserByEmail(email) {

    const sb = getSupabase();

    const normalized =
      String(email || '').trim().toLowerCase();

    if (!normalized) {
      throw new Error('Enter the user email.');
    }

    const { data, error } =
      await sb
        .from('profiles')
        .select('*')
        .ilike('email', normalized)
        .limit(1)
        .maybeSingle();

    if (error) throw error;

    if (!data) {
      throw new Error(
        'No registered Storeman user was found with this email.'
      );
    }

    return data;
  }

  async function approveUser(form) {

    const sb = getSupabase();

    const profile =
      await findUserByEmail(form.email.value);

    const role =
      form.role.value;

    const status =
      form.status.value;

    const companyId =
      form.company_id.value || null;

    const warehouseId =
      form.warehouse_id.value || null;

    const permissions = defaultPermissions();

    document
      .querySelectorAll(
        '[data-permission-feature]'
      )
      .forEach(input => {

        const feature =
          input.dataset.permissionFeature;

        const action =
          input.dataset.permissionAction;

        if (!permissions[feature]) {
          permissions[feature] = {};
        }

        permissions[feature][action] =
          input.checked;
      });

    const { data, error } =
      await sb
        .from('profiles')
        .update({
          role,
          status,
          company_id: companyId,
          warehouse_id: warehouseId,
          permissions,
          updated_at: new Date().toISOString()
        })
        .eq('id', profile.id)
        .select('*')
        .single();

    if (error) throw error;

    await sb
      .from('activity_logs')
      .insert({
        user_id: profile.id,
        action: status === 'active'
          ? 'ADMIN_APPROVED_USER'
          : 'ADMIN_UPDATED_USER',
        entity: 'profiles',
        entity_id: profile.id,
        details: {
          email: profile.email,
          role,
          status,
          company_id: companyId,
          warehouse_id: warehouseId,
          permissions
        }
      });

    return data;
  }

  async function renderAdminPanel(container) {

    const profile =
      await getCurrentProfile();

    /*
     * FRONTEND GATE.
     *
     * RLS is the real security.
     * This gate only controls what is displayed.
     */

    if (!isAdminProfile(profile)) {
      container.innerHTML = '';
      container.hidden = true;
      return;
    }

    container.hidden = false;

    const lists =
      await loadCompaniesAndWarehouses();

    container.innerHTML = `
      <section
        id="storeman-admin-user-management"
        class="storeman-admin-panel"
      >

        <h2>👥 User Management</h2>

        <p>
          Administrator only.
          Approve users and assign access.
        </p>

        <form id="storeman-admin-user-form">

          <label>
            Email
            <input
              name="email"
              type="email"
              placeholder="user@example.com"
              autocomplete="off"
              required
            >
          </label>

          <button
            type="button"
            id="storeman-find-user"
          >
            Find User
          </button>

          <div
            id="storeman-user-result"
            style="margin-top:12px"
          ></div>

          <label>
            Role
            <select name="role">
              <option value="staff">Staff</option>
              <option value="manager">Manager</option>
              <option value="accountant">Accountant</option>
              <option value="storekeeper">Storekeeper</option>
              <option value="admin">Admin</option>
            </select>
          </label>

          <label>
            Status
            <select name="status">
              <option value="pending">Pending</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended</option>
              <option value="rejected">Rejected</option>
            </select>
          </label>

          <label>
            Company
            <select name="company_id">
              <option value="">No company</option>

              ${lists.companies.map(c => `
                <option value="${escapeHTML(c.id)}">
                  ${escapeHTML(c.name)}
                </option>
              `).join('')}

            </select>
          </label>

          <label>
            Warehouse
            <select name="warehouse_id">
              <option value="">No warehouse</option>

              ${lists.warehouses.map(w => `
                <option
                  value="${escapeHTML(w.id)}"
                  data-company="${escapeHTML(w.company_id || '')}"
                >
                  ${escapeHTML(w.name)}
                </option>
              `).join('')}

            </select>
          </label>

          <h3>🔐 Permissions</h3>

          <div id="storeman-permission-editor">
            ${renderPermissionEditor()}
          </div>

          <button
            type="submit"
            class="storeman-admin-save"
          >
            Approve / Save User
          </button>

          <div
            id="storeman-admin-message"
            role="status"
            style="margin-top:12px"
          ></div>

        </form>

      </section>
    `;

    const form =
      document.getElementById(
        'storeman-admin-user-form'
      );

    const findButton =
      document.getElementById(
        'storeman-find-user'
      );

    const result =
      document.getElementById(
        'storeman-user-result'
      );

    const message =
      document.getElementById(
        'storeman-admin-message'
      );

    findButton.addEventListener(
      'click',
      async () => {

        try {

          const user =
            await findUserByEmail(
              form.email.value
            );

          form.role.value =
            user.role || 'staff';

          form.status.value =
            user.status || 'pending';

          form.company_id.value =
            user.company_id || '';

          form.warehouse_id.value =
            user.warehouse_id || '';

          document
            .getElementById(
              'storeman-permission-editor'
            )
            .innerHTML =
              renderPermissionEditor(
                user.permissions || defaultPermissions()
              );

          result.innerHTML = `
            <div>
              <strong>User found:</strong>
              ${escapeHTML(user.email)}
            </div>
          `;

          message.textContent =
            'User loaded. Set role, company, warehouse and permissions.';

        } catch (error) {

          result.innerHTML =
            '<span style="color:#b00020">' +
            escapeHTML(error.message) +
            '</span>';

        }
      }
    );

    form.addEventListener(
      'submit',
      async event => {

        event.preventDefault();

        try {

          message.textContent =
            'Saving...';

          const saved =
            await approveUser(form);

          message.textContent =
            `Saved: ${saved.email} (${saved.status})`;

          await sendAdminNotification(
            saved.email,
            saved.status === 'active'
              ? 'USER_APPROVED'
              : 'USER_UPDATED'
          );

        } catch (error) {

          console.error(error);

          message.textContent =
            'ERROR: ' +
            error.message;

        }
      }
    );
  }

  async function installIntoSettings() {

    /*
     * We deliberately do not put User Management on the main
     * dashboard. It belongs inside Settings.
     */

    let settingsHost =
      document.querySelector(
        '#settings-user-management'
      );

    if (!settingsHost) {

      settingsHost =
        document.createElement('div');

      settingsHost.id =
        'settings-user-management';

      settingsHost.hidden = true;

      settingsHost.style.cssText =
        'margin-top:24px;';

      const settings =
        document.querySelector(
          '#settings, [data-page="settings"], [data-section="settings"]'
        );

      if (settings) {
        settings.appendChild(settingsHost);
      } else {
        return;
      }
    }

    await renderAdminPanel(settingsHost);
  }

  async function notifyPendingUser(userEmail) {

    /*
     * Called after signup by the app.
     *
     * The Supabase database trigger creates a pending profile.
     * This notification tells the administrator that approval
     * is required.
     */

    if (!userEmail) return;

    await sendAdminNotification(
      userEmail,
      'NEW_USER_SIGNUP'
    );
  }

  window.StoremanAdminSecurity = {
    getCurrentProfile,
    renderAdminPanel,
    installIntoSettings,
    notifyPendingUser,
    findUserByEmail,
    approveUser
  };

})();
JS

# ------------------------------------------------------------
# 4. EMAILJS CONFIG
# ------------------------------------------------------------

echo
echo "===== 4. CREATE EMAILJS CONFIG ====="

cat > storeman-email-config.js <<EOF
window.STOREMAN_EMAIL_CONFIG = {
  publicKey: "${EMAILJS_PUBLIC_KEY}",
  serviceId: "${EMAILJS_SERVICE_ID}",
  receiverEmail: "${RECEIVER_EMAIL}",
  lowStockTemplateId: "${EMAILJS_LOW_TEMPLATE}",
  dailyReportTemplateId: "${EMAILJS_DAILY_TEMPLATE}",

  /*
   * IMPORTANT:
   * Create this template in EmailJS for administrator alerts.
   *
   * Example template variables:
   * {{to_email}}
   * {{admin_email}}
   * {{user_email}}
   * {{event_type}}
   * {{app_name}}
   * {{timestamp}}
   * {{message}}
   */
  authNotificationTemplateId:
    window.STOREMAN_AUTH_NOTIFICATION_TEMPLATE_ID ||
    "template_auth_admin"
};
EOF

# ------------------------------------------------------------
# 5. CSS
# ------------------------------------------------------------

echo
echo "===== 5. CREATE ADMIN UI CSS ====="

cat > storeman-admin-security.css <<'CSS'
.storeman-admin-panel {
  width: 100%;
  box-sizing: border-box;
  padding: 18px;
  margin-top: 18px;
  border: 1px solid #ddd;
  border-radius: 16px;
  background: #fff;
}

.storeman-admin-panel h2 {
  margin-top: 0;
}

.storeman-admin-panel label {
  display: block;
  margin: 12px 0;
  font-weight: 600;
}

.storeman-admin-panel input,
.storeman-admin-panel select {
  display: block;
  width: 100%;
  box-sizing: border-box;
  margin-top: 6px;
  padding: 12px;
  border: 1px solid #ccc;
  border-radius: 10px;
  font-size: 16px;
}

.storeman-admin-panel button {
  padding: 12px 18px;
  border: 0;
  border-radius: 10px;
  cursor: pointer;
  margin: 6px 4px 6px 0;
}

.storeman-admin-save {
  font-weight: 700;
}

.storeman-permission-card {
  border: 1px solid #e2e2e2;
  border-radius: 12px;
  padding: 12px;
  margin: 8px 0;
}

.storeman-permission-actions {
  display: grid;
  grid-template-columns:
    repeat(4, minmax(70px,1fr));
  gap: 8px;
  margin-top: 8px;
}

.storeman-permission-actions label {
  margin: 0;
  font-weight: 400;
  font-size: 14px;
}

.storeman-permission-actions input {
  width: auto;
  display: inline-block;
}
CSS

# ------------------------------------------------------------
# 6. INJECT MODULES INTO INDEX
# ------------------------------------------------------------

echo
echo "===== 6. CONNECT MODULES TO INDEX.HTML ====="

python3 - <<'PY'
from pathlib import Path

p = Path("index.html")
if not p.exists():
    raise SystemExit("ERROR: index.html not found")

s = p.read_text(encoding="utf-8")

assets = [
    '<link rel="stylesheet" href="storeman-admin-security.css">',
    '<script src="storeman-email-config.js"></script>',
    '<script src="storeman-admin-management.js"></script>'
]

marker = "</head>"

for asset in assets:
    if asset not in s:
        s = s.replace(marker, "  " + asset + "\n" + marker, 1)

p.write_text(s, encoding="utf-8")
PY

# ------------------------------------------------------------
# 7. CREATE SETTINGS HOST
# ------------------------------------------------------------

echo
echo "===== 7. ADD SETTINGS USER-MANAGEMENT HOST ====="

python3 - <<'PY'
from pathlib import Path

p = Path("index.html")
s = p.read_text(encoding="utf-8")

host = '''
<div id="settings-user-management"
     hidden
     aria-hidden="true"></div>
'''

if 'id="settings-user-management"' not in s:

    candidates = [
        '<div id="settings"',
        '<section id="settings"',
        'id="settings"'
    ]

    inserted = False

    for c in candidates:
        pos = s.find(c)
        if pos >= 0:
            end = s.find(">", pos)
            if end >= 0:
                end += 1
                s = s[:end] + host + s[end:]
                inserted = True
                break

    if not inserted:
        print(
            "WARNING: Settings container was not found automatically."
        )
        print(
            "The JS module is installed, but add "
            "#settings-user-management inside Settings."
        )

p.write_text(s, encoding="utf-8")
PY

# ------------------------------------------------------------
# 8. AUTH SIGNUP / LOGIN NOTIFICATION BRIDGE
# ------------------------------------------------------------

echo
echo "===== 8. CREATE AUTH NOTIFICATION BRIDGE ====="

cat > storeman-auth-notification.js <<'JS'
(function () {

  async function notify() {

    try {

      const sb =
        window.supabaseClient ||
        window.supabase ||
        window.storemanSupabase;

      if (!sb) return;

      const { data } =
        await sb.auth.getUser();

      const user =
        data && data.user;

      if (!user || !user.email) return;

      /*
       * Only pending users need administrator approval.
       */

      const profileResult =
        await sb
          .from('profiles')
          .select('email,status,role')
          .eq('id', user.id)
          .maybeSingle();

      const profile =
        profileResult.data;

      if (
        profile &&
        profile.status === 'pending' &&
        window.StoremanAdminSecurity
      ) {
        await window.StoremanAdminSecurity
          .notifyPendingUser(user.email);
      }

    } catch (e) {
      console.warn(
        'Storeman auth notification bridge:',
        e
      );
    }
  }

  window.StoremanAuthNotification = {
    notify
  };

  document.addEventListener(
    'DOMContentLoaded',
    () => {
      setTimeout(notify, 1500);
    }
  );

})();
JS

python3 - <<'PY'
from pathlib import Path

p=Path("index.html")
s=p.read_text(encoding="utf-8")

tag='<script src="storeman-auth-notification.js"></script>'

if tag not in s:
    s=s.replace(
        '</head>',
        '  '+tag+'\\n</head>',
        1
    )

p.write_text(s,encoding="utf-8")
PY

# ------------------------------------------------------------
# 9. SETTINGS GATE
# ------------------------------------------------------------

echo
echo "===== 9. CREATE ADMIN-ONLY SETTINGS GATE ====="

cat > storeman-settings-security.js <<'JS'
(function () {

  async function applyGate() {

    try {

      if (!window.StoremanAdminSecurity) {
        return;
      }

      await window.StoremanAdminSecurity
        .installIntoSettings();

      const host =
        document.getElementById(
          'settings-user-management'
        );

      if (!host) return;

      /*
       * Non-admin:
       * completely hidden.
       */

      const profile =
        await window.StoremanAdminSecurity
          .getCurrentProfile();

      const admin =
        profile &&
        profile.status === 'active' &&
        String(profile.role).toLowerCase() === 'admin';

      if (!admin) {

        host.hidden = true;
        host.setAttribute(
          'aria-hidden',
          'true'
        );

        host.innerHTML = '';

      } else {

        host.hidden = false;
        host.setAttribute(
          'aria-hidden',
          'false'
        );
      }

    } catch (e) {

      console.warn(
        'Settings security gate:',
        e
      );

    }
  }

  window.StoremanSettingsSecurity = {
    applyGate
  };

  document.addEventListener(
    'DOMContentLoaded',
    () => setTimeout(applyGate, 1800)
  );

})();
JS

python3 - <<'PY'
from pathlib import Path

p=Path("index.html")
s=p.read_text(encoding="utf-8")

tag='<script src="storeman-settings-security.js"></script>'

if tag not in s:
    s=s.replace(
        '</head>',
        '  '+tag+'\\n</head>',
        1
    )

p.write_text(s,encoding="utf-8")
PY

# ------------------------------------------------------------
# 10. LOCAL SECURITY CHECKS
# ------------------------------------------------------------

echo
echo "===== 10. LOCAL SECURITY CHECKS ====="

echo "--- files ---"

test -f "$SQL"
test -f storeman-admin-management.js
test -f storeman-email-config.js
test -f storeman-auth-notification.js
test -f storeman-settings-security.js
test -f storeman-admin-security.css

echo "All security files exist."

echo "--- admin email ---"

grep -n "$ADMIN_EMAIL" "$SQL" >/dev/null
echo "Admin configured."

echo "--- receiver ---"

grep -n "$RECEIVER_EMAIL" storeman-email-config.js >/dev/null
echo "EmailJS receiver configured."

echo "--- RLS ---"

grep -n "enable row level security" "$SQL" >/dev/null
grep -n "private.is_admin" "$SQL" >/dev/null
echo "RLS/admin checks found."

echo "--- admin-only frontend ---"

grep -n "isAdminProfile" storeman-admin-management.js >/dev/null
grep -n "hidden" storeman-settings-security.js >/dev/null
echo "Admin-only UI gate found."

echo "--- email approval field ---"

grep -n 'name="email"' storeman-admin-management.js >/dev/null
grep -n "findUserByEmail" storeman-admin-management.js >/dev/null
echo "Editable approval email field found."

echo "--- no service role key ---"

if grep -RniE \
  'service_role|sb_secret_|SUPABASE_SERVICE_ROLE_KEY' \
  storeman-admin-management.js \
  storeman-auth-notification.js \
  storeman-email-config.js \
  2>/dev/null
then
  echo "WARNING: sensitive Supabase server key found."
else
  echo "OK: no Supabase service-role/secret key in frontend."
fi

echo "--- index references ---"

grep -n \
  "storeman-admin-management.js" \
  index.html >/dev/null

grep -n \
  "storeman-auth-notification.js" \
  index.html >/dev/null

grep -n \
  "storeman-settings-security.js" \
  index.html >/dev/null

echo "Frontend modules connected."

# ------------------------------------------------------------
# 11. GIT DIFF CHECK
# ------------------------------------------------------------

echo
echo "===== 11. GIT DIFF CHECK ====="

git diff --check || true

echo
echo "===== CHANGED FILES ====="

git status --short

# ------------------------------------------------------------
# 12. COMMIT
# ------------------------------------------------------------

echo
echo "===== 12. GIT COMMIT ====="

git add \
  index.html \
  storeman-admin-management.js \
  storeman-email-config.js \
  storeman-auth-notification.js \
  storeman-settings-security.js \
  storeman-admin-security.css \
  "$SQL" \
  "$BACKUP"

git commit \
  -m "security: finalize admin user approval permissions and settings gate" \
  || echo "Nothing new to commit."

# ------------------------------------------------------------
# 13. PUSH
# ------------------------------------------------------------

echo
echo "===== 13. GITHUB PUSH ====="

BRANCH="$(git branch --show-current)"

echo "Branch: $BRANCH"

if git push origin "$BRANCH"; then

  echo
  echo "GITHUB PUSH: SUCCESS"

else

  echo
  echo "GITHUB PUSH: FAILED"
  echo
  echo "The commit is SAFE locally."
  echo "Likely network/DNS problem if you see:"
  echo "Could not resolve host: github.com"
  echo
  echo "Retry later with:"
  echo "cd ~/Storeman-app"
  echo "git push origin $BRANCH"

fi

# ------------------------------------------------------------
# 14. FINAL SUMMARY
# ------------------------------------------------------------

echo
echo "============================================================"
echo " STOREMAN MASTER BUILD FINISHED"
echo "============================================================"
echo
echo "BACKUP:"
echo "$BACKUP"
echo
echo "SQL:"
echo "$SQL"
echo
echo "ADMIN:"
echo "$ADMIN_EMAIL"
echo
echo "EMAIL RECEIVER:"
echo "$RECEIVER_EMAIL"
echo
echo "SITE:"
echo "$SITE_URL"
echo
echo "============================================================"
echo " REQUIRED SUPABASE DASHBOARD SETTINGS"
echo "============================================================"
echo
echo "Site URL:"
echo "$SITE_URL"
echo
echo "Redirect URL:"
echo "$SITE_URL"
echo
echo "Authentication:"
echo "  Confirm Email = ENABLED"
echo "  Allow New Users = ENABLED"
echo
echo "============================================================"
echo " EMAILJS"
echo "============================================================"
echo
echo "Public Key:"
echo "$EMAILJS_PUBLIC_KEY"
echo
echo "Service:"
echo "$EMAILJS_SERVICE_ID"
echo
echo "Receiver:"
echo "$RECEIVER_EMAIL"
echo
echo "IMPORTANT:"
echo "Create an EmailJS ADMIN AUTH notification template."
echo "Suggested template ID:"
echo "template_auth_admin"
echo
echo "Template variables:"
echo "  {{to_email}}"
echo "  {{admin_email}}"
echo "  {{user_email}}"
echo "  {{event_type}}"
echo "  {{app_name}}"
echo "  {{timestamp}}"
echo "  {{message}}"
echo
echo "============================================================"
echo " FINAL TEST"
echo "============================================================"
echo
echo "1. Open:"
echo "$SITE_URL"
echo
echo "2. Admin login:"
echo "$ADMIN_EMAIL"
echo
echo "3. Open:"
echo "Settings -> User Management"
echo
echo "4. Confirm normal user cannot see User Management."
echo
echo "5. Register a new user."
echo
echo "6. User receives Supabase confirmation email."
echo
echo "7. User confirms own email."
echo
echo "8. Admin receives NEW_USER_SIGNUP notification."
echo
echo "9. Admin enters user's email."
echo
echo "10. Find User."
echo
echo "11. Set Role."
echo
echo "12. Set Status = Active."
echo
echo "13. Set Company."
echo
echo "14. Set Warehouse."
echo
echo "15. Set only required Permissions."
echo
echo "16. Save."
echo
echo "17. User signs in again."
echo
echo "18. User sees ONLY authorized features."
echo
echo "19. Try unauthorized database access."
echo "    It must be rejected by RLS."
echo
echo "============================================================"
echo " IMPORTANT"
echo "============================================================"
echo
echo "The SQL migration MUST be executed in Supabase SQL Editor."
echo
echo "Frontend hiding is NOT the security boundary."
echo "Supabase RLS is the security boundary."
echo
echo "============================================================"
echo " DONE"
echo "============================================================"
