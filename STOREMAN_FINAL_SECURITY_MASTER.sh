#!/data/data/com.termux/files/usr/bin/bash

set -u

APP="$HOME/Storeman-app"
cd "$APP" || exit 1

STAMP="$(date +%Y%m%d_%H%M%S)"

echo "============================================================"
echo " STOREMAN FINAL SECURITY MASTER"
echo " AUTH + APPROVAL + ADMIN ONLY + PERMISSIONS + RLS + PUSH"
echo "============================================================"

echo
echo "===== 1. ENVIRONMENT ====="
echo "APP: $APP"
echo "BRANCH: $(git branch --show-current 2>/dev/null || echo unknown)"
echo

echo "===== 2. BACKUP ====="

mkdir -p "backup/final_security_$STAMP"

cp -f index.html \
  "backup/final_security_$STAMP/index.html.before-final-security" \
  2>/dev/null || true

cp -f storeman-security.js \
  "backup/final_security_$STAMP/storeman-security.js.before-final-security" \
  2>/dev/null || true

cp -f supabase/migrations/20260826_storeman_security_auth.sql \
  "backup/final_security_$STAMP/security-migration.before-final-security.sql" \
  2>/dev/null || true

echo "Backup created:"
echo "backup/final_security_$STAMP"

echo
echo "===== 3. CREATE FINAL RLS PATCH ====="

mkdir -p supabase/migrations

cat > supabase/migrations/20260826_storeman_final_security_patch.sql <<'SQL'
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
SQL

echo "RLS patch created."

echo
echo "===== 4. CREATE ADMIN-ONLY FRONTEND SECURITY ====="

cat > storeman-final-security.js <<'JS'
/*
============================================================
STOREMAN FINAL FRONTEND SECURITY
============================================================

IMPORTANT:
This file is NOT the primary security layer.
Supabase RLS is the primary security layer.

This file:
1. Detects current profile.
2. Hides admin-only UI from normal users.
3. Blocks pending/blocked users from ERP UI.
4. Shows only authorized features.
5. Makes user-management UI admin-only.
============================================================
*/

(function () {
  "use strict";

  const ADMIN_EMAIL = "ashenafihailay779@gmail.com";

  const ADMIN_ONLY_IDS = [
    "users",
    "userManagement",
    "user-management",
    "users-section",
    "adminUsers",
    "admin-user-management",
    "userAdmin",
    "manageUsers",
    "usersManagement"
  ];

  const ADMIN_ONLY_CLASSES = [
    ".admin-only",
    ".adminOnly",
    ".admin-only-section",
    ".user-management",
    ".users-management",
    "[data-admin-only]"
  ];

  const SECURITY_FEATURES = [
    "dashboard",
    "materials",
    "stock_in",
    "stock_out",
    "suppliers",
    "warehouses",
    "invoicing",
    "reports",
    "backup",
    "users",
    "settings"
  ];

  function hideElement(el) {
    if (!el) return;

    el.style.display = "none";
    el.setAttribute("aria-hidden", "true");
    el.setAttribute("data-security-hidden", "true");
  }

  function showElement(el) {
    if (!el) return;

    el.style.removeProperty("display");
    el.removeAttribute("aria-hidden");
    el.removeAttribute("data-security-hidden");
  }

  function hideAdminOnlyUI() {
    ADMIN_ONLY_IDS.forEach(function (id) {
      hideElement(document.getElementById(id));
    });

    ADMIN_ONLY_CLASSES.forEach(function (selector) {
      document.querySelectorAll(selector).forEach(hideElement);
    });

    /*
     * Also hide common navigation items pointing to users.
     */
    document.querySelectorAll(
      '[data-feature="users"],' +
      '[data-section="users"],' +
      '[data-page="users"],' +
      '[data-nav="users"]'
    ).forEach(hideElement);
  }

  function showAdminOnlyUI() {
    ADMIN_ONLY_IDS.forEach(function (id) {
      showElement(document.getElementById(id));
    });

    ADMIN_ONLY_CLASSES.forEach(function (selector) {
      document.querySelectorAll(selector).forEach(showElement);
    });

    document.querySelectorAll(
      '[data-feature="users"],' +
      '[data-section="users"],' +
      '[data-page="users"],' +
      '[data-nav="users"]'
    ).forEach(showElement);
  }

  function getPermission(profile, feature, action) {
    if (!profile) return false;

    if (
      String(profile.role || "").toLowerCase() === "admin"
    ) {
      return true;
    }

    const permissions = profile.permissions || {};
    const featurePermissions = permissions[feature] || {};

    return featurePermissions[action] === true;
  }

  function applyFeaturePermissions(profile) {

    if (!profile) return;

    const isAdmin =
      String(profile.role || "").toLowerCase() === "admin";

    /*
     * USER MANAGEMENT IS ALWAYS ADMIN ONLY.
     */
    if (isAdmin) {
      showAdminOnlyUI();
    } else {
      hideAdminOnlyUI();
    }

    /*
     * Hide feature navigation according to permissions.
     */
    SECURITY_FEATURES.forEach(function (feature) {

      if (feature === "users") {
        return;
      }

      const allowed =
        isAdmin ||
        getPermission(profile, feature, "view");

      document.querySelectorAll(
        '[data-feature="' + feature + '"],' +
        '[data-section="' + feature + '"],' +
        '[data-page="' + feature + '"]'
      ).forEach(function (el) {

        if (allowed) {
          showElement(el);
        } else {
          hideElement(el);
        }

      });

    });
  }

  function blockInactiveUser(profile) {

    if (!profile) return;

    const status =
      String(profile.status || "").toLowerCase();

    if (status === "active") {
      return;
    }

    /*
     * Pending / blocked users should not use ERP.
     */
    document.body.classList.add(
      "storeman-account-not-active"
    );

    document.body.setAttribute(
      "data-account-status",
      status
    );

    /*
     * Hide application sections.
     */
    document.querySelectorAll(
      '[data-feature],' +
      '[data-section],' +
      '[data-page],' +
      'main .app-content'
    ).forEach(function (el) {
      hideElement(el);
    });

    /*
     * Hide admin controls regardless of status.
     */
    hideAdminOnlyUI();

    let message = document.getElementById(
      "storeman-security-message"
    );

    if (!message) {

      message = document.createElement("div");

      message.id =
        "storeman-security-message";

      message.style.padding = "24px";
      message.style.margin = "24px";
      message.style.borderRadius = "12px";
      message.style.background = "#fff3cd";
      message.style.color = "#664d03";
      message.style.fontSize = "16px";
      message.style.fontWeight = "600";

      document.body.prepend(message);
    }

    if (status === "pending") {

      message.textContent =
        "Your email has been registered, but your account is waiting for administrator approval.";

    } else if (status === "blocked") {

      message.textContent =
        "Your account has been blocked. Please contact the administrator.";

    } else {

      message.textContent =
        "Your account is not active. Please contact the administrator.";

    }
  }

  async function loadStoremanSecurity() {

    /*
     * The existing app should expose Supabase as:
     *
     * window.supabaseClient
     *
     * OR:
     * window.supabase
     *
     */

    const client =
      window.supabaseClient ||
      (
        window.supabase &&
        typeof window.supabase.from === "function"
          ? window.supabase
          : null
      );

    if (!client) {
      console.warn(
        "Storeman security: Supabase client not found."
      );
      return;
    }

    try {

      const result =
        await client.auth.getUser();

      const user =
        result && result.data
          ? result.data.user
          : null;

      if (!user) {
        hideAdminOnlyUI();
        return;
      }

      const profileResult =
        await client
          .from("profiles")
          .select(
            "id,email,full_name,role,status,company_id,warehouse_id,permissions"
          )
          .eq("id", user.id)
          .maybeSingle();

      if (profileResult.error) {
        console.error(
          "Storeman security profile error:",
          profileResult.error
        );

        hideAdminOnlyUI();
        return;
      }

      const profile =
        profileResult.data;

      if (!profile) {
        hideAdminOnlyUI();
        return;
      }

      /*
       * Extra client-side admin identity check.
       *
       * Real authorization remains RLS.
       */
      const isAdmin =
        String(profile.role || "").toLowerCase() === "admin" &&
        String(profile.email || "").toLowerCase() ===
          ADMIN_EMAIL.toLowerCase();

      profile.__storemanAdmin = isAdmin;

      window.storemanCurrentProfile = profile;

      if (isAdmin) {
        showAdminOnlyUI();
      } else {
        hideAdminOnlyUI();
      }

      blockInactiveUser(profile);

      if (
        String(profile.status || "").toLowerCase() ===
        "active"
      ) {
        applyFeaturePermissions(profile);
      }

      /*
       * Notify application code.
       */
      window.dispatchEvent(
        new CustomEvent(
          "storeman:security-ready",
          {
            detail: {
              user: user,
              profile: profile,
              isAdmin: isAdmin
            }
          }
        )
      );

    } catch (error) {

      console.error(
        "Storeman security initialization failed:",
        error
      );

      hideAdminOnlyUI();
    }
  }

  /*
   * Make functions available to existing application.
   */
  window.StoremanSecurity = {
    load: loadStoremanSecurity,
    hideAdminOnlyUI: hideAdminOnlyUI,
    showAdminOnlyUI: showAdminOnlyUI,
    getPermission: getPermission
  };

  /*
   * Start after DOM.
   */
  if (
    document.readyState === "loading"
  ) {

    document.addEventListener(
      "DOMContentLoaded",
      loadStoremanSecurity
    );

  } else {

    loadStoremanSecurity();

  }

})();
JS

echo "Frontend security file created."

echo
echo "===== 5. CREATE ADMIN NOTIFICATION HELPER ====="

cat > storeman-admin-notification.js <<'JS'
/*
============================================================
STOREMAN ADMIN SIGNUP NOTIFICATION
============================================================

This notification is NOT the authorization mechanism.

Authorization:
Supabase RLS + profiles.status

Notification:
EmailJS, if configured.

The new user's confirmation email remains sent by
Supabase Auth to the NEW USER.

The administrator receives a separate notification.
============================================================
*/

(function () {

  "use strict";

  const ADMIN_EMAIL =
    "ashenafihailay779@gmail.com";

  async function notifyAdminNewUser(user, profile) {

    try {

      if (!window.emailjs) {
        console.warn(
          "EmailJS is not configured. Admin notification skipped."
        );

        return {
          ok: false,
          reason: "emailjs_not_configured"
        };
      }

      /*
       * These values can be connected to the existing
       * Storeman EmailJS settings.
       */
      const publicKey =
        localStorage.getItem(
          "storeman_emailjs_public_key"
        );

      const serviceId =
        localStorage.getItem(
          "storeman_emailjs_service_id"
        );

      const templateId =
        localStorage.getItem(
          "storeman_admin_signup_template_id"
        );

      if (
        !publicKey ||
        !serviceId ||
        !templateId
      ) {

        console.warn(
          "Storeman admin notification settings are incomplete."
        );

        return {
          ok: false,
          reason: "emailjs_settings_missing"
        };
      }

      if (
        typeof window.emailjs.init === "function"
      ) {

        window.emailjs.init({
          publicKey: publicKey
        });

      }

      const params = {

        to_email: ADMIN_EMAIL,

        admin_email: ADMIN_EMAIL,

        user_email:
          user && user.email
            ? user.email
            : "",

        user_id:
          user && user.id
            ? user.id
            : "",

        full_name:
          profile && profile.full_name
            ? profile.full_name
            : "",

        status:
          profile && profile.status
            ? profile.status
            : "pending",

        role:
          profile && profile.role
            ? profile.role
            : "staff",

        company:
          profile && profile.company_id
            ? profile.company_id
            : "",

        warehouse:
          profile && profile.warehouse_id
            ? profile.warehouse_id
            : "",

        message:
          "A new Storeman user registered and is waiting for administrator approval."

      };

      const response =
        await window.emailjs.send(
          serviceId,
          templateId,
          params
        );

      console.log(
        "Storeman admin notification sent:",
        response
      );

      return {
        ok: true
      };

    } catch (error) {

      console.error(
        "Storeman admin notification failed:",
        error
      );

      return {
        ok: false,
        reason: "send_failed",
        error: error
      };
    }
  }

  window.StoremanAdminNotification = {
    notifyNewUser: notifyAdminNewUser
  };

})();
JS

echo "Admin notification helper created."

echo
echo "===== 6. ADD FRONTEND FILES TO INDEX.HTML ====="

if [ -f index.html ]; then

  cp index.html \
    "backup/final_security_$STAMP/index.html.before-script-injection"

  python - <<'PY'
from pathlib import Path

p = Path("index.html")
s = p.read_text(errors="ignore")

scripts = """
<!-- STOREMAN FINAL SECURITY -->
<script src="storeman-final-security.js"></script>
<script src="storeman-admin-notification.js"></script>
"""

if "storeman-final-security.js" not in s:

    if "</body>" in s.lower():
        pos = s.lower().rfind("</body>")
        s = s[:pos] + scripts + "\\n" + s[pos:]
    else:
        s += "\\n" + scripts

    p.write_text(s)

print("index.html security scripts checked.")
PY

else

  echo "WARNING: index.html not found."

fi

echo
echo "===== 7. CREATE ADMIN NOTIFICATION TABLE ====="

cat > supabase/migrations/20260826_storeman_admin_notifications.sql <<'SQL'
-- ============================================================
-- STOREMAN ADMIN NOTIFICATIONS
-- ============================================================

create table if not exists public.admin_notifications (

  id uuid primary key default gen_random_uuid(),

  user_id uuid references auth.users(id)
    on delete cascade,

  user_email text,

  full_name text,

  type text not null default 'new_signup',

  status text not null default 'unread',

  message text,

  created_at timestamptz not null default now()

);

alter table public.admin_notifications
enable row level security;

revoke all
on public.admin_notifications
from anon, authenticated;

grant select, update
on public.admin_notifications
to authenticated;

drop policy if exists admin_notifications_select
on public.admin_notifications;

create policy admin_notifications_select
on public.admin_notifications
for select
to authenticated
using (
  private.is_admin()
);

drop policy if exists admin_notifications_update
on public.admin_notifications;

create policy admin_notifications_update
on public.admin_notifications
for update
to authenticated
using (
  private.is_admin()
)
with check (
  private.is_admin()
);

-- No normal authenticated user can insert notifications.
-- Notifications are created by trusted backend/webhook logic.

SQL

echo "Notification table created."

echo
echo "===== 8. CREATE TEST / SECURITY CHECK SQL ====="

cat > STOREMAN_FINAL_SECURITY_CHECK.sql <<'SQL'
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

SQL

echo
echo "===== 9. SYNTAX / FILE CHECK ====="

bash -n STOREMAN_FINAL_SECURITY_MASTER.sh

if [ -f storeman-final-security.js ]; then
  echo "OK: storeman-final-security.js"
fi

if [ -f storeman-admin-notification.js ]; then
  echo "OK: storeman-admin-notification.js"
fi

if [ -f supabase/migrations/20260826_storeman_final_security_patch.sql ]; then
  echo "OK: final RLS patch"
fi

if [ -f supabase/migrations/20260826_storeman_admin_notifications.sql ]; then
  echo "OK: admin notification migration"
fi

echo
echo "===== 10. GIT STATUS BEFORE COMMIT ====="

git status --short

echo
echo "===== 11. GIT ADD ====="

git add \
  index.html \
  storeman-final-security.js \
  storeman-admin-notification.js \
  STOREMAN_FINAL_SECURITY_MASTER.sh \
  STOREMAN_FINAL_SECURITY_CHECK.sql \
  supabase/migrations/20260826_storeman_final_security_patch.sql \
  supabase/migrations/20260826_storeman_admin_notifications.sql \
  "backup/final_security_$STAMP"

echo
echo "===== 12. COMMIT ====="

git commit \
  -m "security: enforce admin-only user management and final RLS"

echo
echo "===== 13. NETWORK CHECK ====="

if command -v getent >/dev/null 2>&1; then

  if getent hosts github.com >/dev/null 2>&1; then
    echo "GitHub DNS: OK"
  else
    echo "GitHub DNS: FAILED"
    echo
    echo "IMPORTANT:"
    echo "Commit is safe locally."
    echo "Push will be attempted only when GitHub DNS works."
    exit 0
  fi

else

  echo "getent not available; attempting push."

fi

echo
echo "===== 14. PUSH ====="

BRANCH="$(git branch --show-current)"

if [ -z "$BRANCH" ]; then
  echo "ERROR: branch not detected."
  exit 1
fi

git push origin "$BRANCH"

echo
echo "============================================================"
echo " FINAL SECURITY MASTER COMPLETE"
echo "============================================================"
echo "Branch: $BRANCH"
echo "Commit created and pushed."
echo
echo "IMPORTANT SUPABASE STEPS:"
echo
echo "1. Run:"
echo "   supabase/migrations/20260826_storeman_final_security_patch.sql"
echo
echo "2. Run:"
echo "   supabase/migrations/20260826_storeman_admin_notifications.sql"
echo
echo "3. Keep Email Confirmations ENABLED."
echo
echo "4. Site URL:"
echo "   https://villagevictor.github.io/Storeman-app/"
echo
echo "5. Redirect URL:"
echo "   https://villagevictor.github.io/Storeman-app/"
echo
echo "6. Test NEW USER:"
echo "   Signup"
echo "   -> confirmation email goes to NEW USER"
echo "   -> profile = pending"
echo "   -> ERP access blocked"
echo "   -> admin notification"
echo "   -> admin approves"
echo "   -> admin assigns warehouse"
echo "   -> admin assigns permissions"
echo "   -> user signs in"
echo "   -> only permitted features/data"
echo
echo "7. Admin-only:"
echo "   Email"
echo "   Role"
echo "   Status"
echo "   Company"
echo "   Warehouse"
echo "   Permissions"
echo "   User management"
echo
echo "============================================================"

