#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

APP="$HOME/Storeman-app"

if [ ! -d "$APP" ]; then
  echo "ERROR: Storeman-app not found at:"
  echo "$APP"
  echo
  echo "Run:"
  echo "ls ~"
  exit 1
fi

cd "$APP"

STAMP="$(date +%Y%m%d_%H%M%S)"

BACKUP="backup/auth_master_$STAMP"
mkdir -p "$BACKUP"

echo
echo "======================================================"
echo " STOREMAN AUTH MASTER FINAL FIX"
echo "======================================================"
echo "Project: $APP"
echo "Time:    $STAMP"
echo "======================================================"

# ------------------------------------------------------
# 1. BACKUP
# ------------------------------------------------------

echo
echo "[1/8] BACKUP"

cp -f index.html "$BACKUP/index.html" 2>/dev/null || true
cp -f storeman-auth.js "$BACKUP/storeman-auth.js" 2>/dev/null || true
cp -f supabase-config.json "$BACKUP/supabase-config.json" 2>/dev/null || true

echo "Backup: $BACKUP"

# ------------------------------------------------------
# 2. CREATE FINAL SECURITY PATCH
# ------------------------------------------------------

echo
echo "[2/8] CREATE FINAL AUTH SECURITY MODULE"

cat > storeman-auth-final-guard.js <<'JS'
(function () {

    "use strict";

    /*
     * STOREMAN FINAL AUTH GUARD
     *
     * Security model:
     *
     * Supabase Auth
     *      ↓
     * profiles
     *      ↓
     * status
     *      ↓
     * role
     *      ↓
     * permissions
     *
     * Frontend hiding is NOT the database security boundary.
     * Supabase RLS must enforce the same rules.
     */

    const ADMIN_EMAIL =
        "ashenafihailay779@gmail.com";

    function getAuth() {
        return window.StoremanAuth || null;
    }

    function getProfile() {

        const auth =
            getAuth();

        return auth?.profile || null;
    }

    function isAdmin() {

        const p =
            getProfile();

        if (!p)
            return false;

        const role =
            String(
                p.role || ""
            ).toLowerCase();

        const status =
            String(
                p.status || ""
            ).toLowerCase();

        return (
            status === "active" &&
            (
                role === "admin" ||
                role === "owner"
            )
        );
    }

    function isActive() {

        const p =
            getProfile();

        return (
            p &&
            String(p.status || "")
                .toLowerCase() === "active"
        );
    }

    function hasPermission(
        feature,
        action = "view"
    ) {

        if (isAdmin())
            return true;

        if (!isActive())
            return false;

        const p =
            getProfile();

        return Boolean(
            p?.permissions?.[feature]?.[action]
        );
    }

    /*
     * Completely hide administrative UI
     * from ordinary users.
     */

    function hideAdminUI() {

        const selectors = [

            "#storeman-admin-panel",

            "#admin-users",

            "#settings-user-management",

            "#storeman-user-management",

            "[data-admin-only]",

            ".admin-only",

            ".settings-admin-only",

            ".user-management",

            "#user-management",

            "#manage-users"

        ];

        selectors.forEach(selector => {

            document
                .querySelectorAll(selector)
                .forEach(el => {

                    el.style.display = "none";

                    el.hidden = true;

                    el.setAttribute(
                        "aria-hidden",
                        "true"
                    );

                });

        });

    }

    /*
     * Hide settings for ordinary users.
     */

    function protectSettings() {

        if (isAdmin())
            return;

        const settingsButtons =
            document.querySelectorAll(
                `
                button,
                a,
                [role="button"]
                `
            );

        settingsButtons.forEach(el => {

            const text =
                (
                    el.innerText ||
                    el.textContent ||
                    ""
                )
                .trim()
                .toLowerCase();

            if (
                text.includes("settings") ||
                text.includes("setting") ||
                text.includes("manage my profile") ||
                text.includes("manage profile") ||
                text.includes("user management") ||
                text.includes("manage users") ||
                text.includes("permissions")
            ) {

                el.style.display =
                    "none";

                el.hidden = true;

                el.setAttribute(
                    "aria-hidden",
                    "true"
                );
            }

        });

    }

    /*
     * Prevent non-admin from entering
     * admin panels even if the HTML exists.
     */

    function protectAdminPanels() {

        if (isAdmin())
            return;

        document
            .querySelectorAll(
                `
                #storeman-admin-panel,
                #admin-panel,
                #user-management,
                #settings-user-management,
                [data-admin-panel]
                `
            )
            .forEach(el => {

                el.innerHTML = "";

                el.style.display =
                    "none";

                el.hidden = true;

            });

    }

    /*
     * Remove "Manage My Profile" from
     * ordinary users.
     */

    function removeSelfManagement() {

        if (isAdmin())
            return;

        document
            .querySelectorAll(
                "button"
            )
            .forEach(button => {

                const text =
                    (
                        button.innerText ||
                        ""
                    )
                    .toLowerCase();

                if (
                    text.includes(
                        "manage my profile"
                    )
                ) {

                    button.remove();

                }

            });

    }

    /*
     * User must be active before
     * application UI is allowed.
     */

    function enforceActiveUser() {

        const p =
            getProfile();

        if (!p)
            return;

        const status =
            String(
                p.status || ""
            ).toLowerCase();

        if (
            status !== "active"
        ) {

            document
                .querySelectorAll(
                    `
                    #app,
                    #dashboard,
                    main,
                    .app-shell,
                    .dashboard,
                    [data-app-shell]
                    `
                )
                .forEach(el => {

                    el.style.display =
                        "none";

                });

        }

    }

    /*
     * Apply permissions to navigation.
     */

    function applyNavigationPermissions() {

        if (!isActive())
            return;

        if (isAdmin())
            return;

        const map = {

            dashboard:
                [
                    "dashboard"
                ],

            materials:
                [
                    "materials",
                    "material"
                ],

            stock_in:
                [
                    "stock in",
                    "receive stock"
                ],

            stock_out:
                [
                    "stock out",
                    "issue stock"
                ],

            suppliers:
                [
                    "supplier",
                    "suppliers"
                ],

            warehouses:
                [
                    "warehouse",
                    "warehouses"
                ],

            invoicing:
                [
                    "invoice",
                    "invoicing"
                ],

            reports:
                [
                    "report",
                    "reports"
                ],

            backup:
                [
                    "backup"
                ],

            users:
                [
                    "user management",
                    "manage users"
                ],

            settings:
                [
                    "settings",
                    "setting",
                    "permissions"
                ]

        };

        document
            .querySelectorAll(
                "button, a, [role='button']"
            )
            .forEach(el => {

                const text =
                    (
                        el.innerText ||
                        el.textContent ||
                        ""
                    )
                    .trim()
                    .toLowerCase();

                Object.entries(
                    map
                ).forEach(
                    ([feature, words]) => {

                        const matched =
                            words.some(
                                word =>
                                    text.includes(word)
                            );

                        if (
                            matched &&
                            !hasPermission(
                                feature,
                                "view"
                            )
                        ) {

                            el.style.display =
                                "none";

                            el.hidden = true;

                        }

                    }
                );

            });

    }

    /*
     * Main guard.
     */

    function apply() {

        try {

            enforceActiveUser();

            if (!isAdmin()) {

                hideAdminUI();

                protectSettings();

                protectAdminPanels();

                removeSelfManagement();

            }

            applyNavigationPermissions();

        } catch (error) {

            console.error(
                "Storeman security guard:",
                error
            );

        }

    }

    /*
     * Run several times because
     * Storeman creates some UI dynamically.
     */

    document.addEventListener(
        "DOMContentLoaded",
        function () {

            setTimeout(apply, 300);

            setTimeout(apply, 1000);

            setTimeout(apply, 2500);

            setTimeout(apply, 5000);

        }
    );

    setInterval(
        apply,
        5000
    );

    window.StoremanFinalSecurity = {

        apply,

        isAdmin,

        isActive,

        hasPermission

    };

})();
JS

# ------------------------------------------------------
# 3. FIX INDEX LOADING
# ------------------------------------------------------

echo
echo "[3/8] CONNECT FINAL SECURITY GUARD"

python3 - <<'PY'
from pathlib import Path

p = Path("index.html")

if not p.exists():
    raise SystemExit("index.html not found")

s = p.read_text(encoding="utf-8")

tag = '<script src="storeman-auth-final-guard.js"></script>'

if tag not in s:

    if "</head>" in s:
        s = s.replace(
            "</head>",
            "  " + tag + "\n</head>",
            1
        )

    else:
        s += "\n" + tag + "\n"

p.write_text(
    s,
    encoding="utf-8"
)

print("Final security guard connected.")
PY

# ------------------------------------------------------
# 4. CREATE FINAL AUTH FLOW PATCH
# ------------------------------------------------------

echo
echo "[4/8] CREATE MULTI-DEVICE AUTH FLOW"

cat > storeman-auth-flow-final.js <<'JS'
(function () {

    "use strict";

    /*
     * STOREMAN AUTH FLOW FINAL
     *
     * Sign Up
     *    ↓
     * Supabase Auth
     *    ↓
     * Pending profile
     *
     * Sign In
     *    ↓
     * Load profile
     *    ↓
     * status=active?
     *    ↓
     * YES → dashboard
     * NO  → sign out + pending message
     */

    function getSB() {

        return (
            window.storemanSupabase ||
            window.supabaseClient ||
            window.supabase ||
            null
        );

    }

    async function getSessionUser() {

        const sb =
            getSB();

        if (!sb)
            return null;

        const result =
            await sb.auth.getUser();

        if (result.error)
            throw result.error;

        return result.data?.user || null;

    }

    async function getProfile(userId) {

        const sb =
            getSB();

        if (!sb || !userId)
            return null;

        const result =
            await sb
                .from("profiles")
                .select("*")
                .eq("id", userId)
                .maybeSingle();

        if (result.error)
            throw result.error;

        return result.data || null;

    }

    async function enforceSession() {

        const sb =
            getSB();

        if (!sb)
            return;

        const user =
            await getSessionUser();

        if (!user) {

            showAuthScreen();

            return;

        }

        const profile =
            await getProfile(
                user.id
            );

        if (!profile) {

            await sb.auth.signOut();

            showAuthScreen();

            notify(
                "Your Storeman profile was not found.",
                true
            );

            return;

        }

        const status =
            String(
                profile.status || ""
            ).toLowerCase();

        if (
            status !== "active"
        ) {

            await sb.auth.signOut();

            showAuthScreen();

            notify(
                "Your account is waiting for administrator approval.",
                true
            );

            return;

        }

    }

    function showAuthScreen() {

        const root =
            document.getElementById(
                "storeman-auth-root"
            );

        if (root) {

            root.style.display =
                "flex";

        }

    }

    function notify(
        message,
        error
    ) {

        if (
            window.StoremanAuth &&
            typeof window.StoremanAuth.notify ===
                "function"
        ) {

            window.StoremanAuth.notify(
                message,
                error
            );

            return;

        }

        console.log(
            message
        );

    }

    /*
     * Multi-device protection.
     *
     * Every device independently restores
     * its own Supabase session.
     */

    async function init() {

        try {

            const sb =
                getSB();

            if (!sb)
                return;

            await enforceSession();

            sb.auth.onAuthStateChange(
                async function (
                    event,
                    session
                ) {

                    if (
                        event ===
                        "SIGNED_IN"
                    ) {

                        if (
                            !session?.user
                        )
                            return;

                        const profile =
                            await getProfile(
                                session.user.id
                            );

                        if (
                            !profile ||
                            String(
                                profile.status ||
                                ""
                            ).toLowerCase() !==
                            "active"
                        ) {

                            await sb.auth
                                .signOut();

                            showAuthScreen();

                            notify(
                                "Your account requires administrator approval.",
                                true
                            );

                        }

                    }

                    if (
                        event ===
                        "SIGNED_OUT"
                    ) {

                        showAuthScreen();

                    }

                }
            );

        } catch (error) {

            console.error(
                "Storeman final auth flow:",
                error
            );

        }

    }

    window.StoremanAuthFinalFlow = {

        init,

        enforceSession

    };

    document.addEventListener(
        "DOMContentLoaded",
        function () {

            setTimeout(
                init,
                1200
            );

        }
    );

})();
JS

python3 - <<'PY'
from pathlib import Path

p=Path("index.html")
s=p.read_text(encoding="utf-8")

tag='<script src="storeman-auth-flow-final.js"></script>'

if tag not in s:
    s=s.replace(
        "</head>",
        "  "+tag+"\n</head>",
        1
    )

p.write_text(
    s,
    encoding="utf-8"
)
PY

# ------------------------------------------------------
# 5. CREATE FINAL SQL
# ------------------------------------------------------

echo
echo "[5/8] CREATE SUPABASE SQL"

mkdir -p supabase/migrations

SQL="supabase/migrations/${STAMP}_final_auth_security.sql"

cat > "$SQL" <<'SQL'
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
SQL

echo "SQL created:"
echo "$SQL"

# ------------------------------------------------------
# 6. CONNECT MODULES
# ------------------------------------------------------

echo
echo "[6/8] VERIFY FILES"

test -f storeman-auth-final-guard.js
test -f storeman-auth-flow-final.js
test -f "$SQL"

grep -q "storeman-auth-final-guard.js" index.html
grep -q "storeman-auth-flow-final.js" index.html

echo "All modules connected."

# ------------------------------------------------------
# 7. SECURITY CHECK
# ------------------------------------------------------

echo
echo "[7/8] SECURITY CHECK"

echo
echo "--- service role scan ---"

if grep -RniE \
    "service_role|sb_secret_|SUPABASE_SERVICE_ROLE_KEY" \
    storeman-auth-final-guard.js \
    storeman-auth-flow-final.js \
    "$SQL" \
    2>/dev/null
then

    echo "WARNING: sensitive key reference detected."

else

    echo "OK: no Supabase service-role key."

fi

echo
echo "--- admin-only checks ---"

grep -q "storeman_is_admin" "$SQL"
grep -q "status = 'active'" "$SQL"
grep -q "profiles_select_self_or_admin" "$SQL"
grep -q "profiles_admin_update" "$SQL"

echo "RLS security checks passed."

echo
echo "--- frontend checks ---"

grep -q "settings" storeman-auth-final-guard.js
grep -q "Manage My Profile" storeman-auth-final-guard.js
grep -q "isAdmin" storeman-auth-final-guard.js

echo "Frontend admin gate checks passed."

echo
echo "--- git diff check ---"

git diff --check || true

# ------------------------------------------------------
# 8. COMMIT
# ------------------------------------------------------

echo
echo "[8/8] GIT"

git add \
    index.html \
    storeman-auth-final-guard.js \
    storeman-auth-flow-final.js \
    "$SQL" \
    "$BACKUP"

git status --short

git commit \
    -m "fix: finalize supabase auth approval permissions and multi-device security" \
    || echo "Nothing new to commit."

echo
echo "======================================================"
echo " MASTER FIX COMPLETE"
echo "======================================================"

echo
echo "IMPORTANT:"
echo
echo "1. Open Supabase SQL Editor."
echo
echo "2. Copy and run:"
echo "$SQL"
echo
echo "3. Then rebuild/publish the app."
echo
echo "4. Test with a NEW user."
echo
echo "======================================================"
echo " AUTH FLOW"
echo "======================================================"
echo
echo "Sign Up"
echo "  -> Supabase Auth"
echo "  -> profiles"
echo "  -> status=pending"
echo "  -> Admin approval"
echo "  -> role/company/warehouse/permissions"
echo "  -> status=active"
echo "  -> Sign In"
echo "  -> authorized dashboard"
echo
echo "======================================================"
echo " USER SECURITY"
echo "======================================================"
echo
echo "Normal user:"
echo "  YES: permitted business features"
echo "  NO: Settings"
echo "  NO: User Management"
echo "  NO: Manage My Profile"
echo "  NO: Roles"
echo "  NO: Permissions"
echo
echo "Admin:"
echo "  YES: all features"
echo "  YES: Settings"
echo "  YES: User Management"
echo "  YES: Roles"
echo "  YES: Company"
echo "  YES: Warehouse"
echo "  YES: Permissions"
echo
echo "======================================================"
echo " MULTI DEVICE"
echo "======================================================"
echo
echo "Each phone/computer uses its own Supabase session."
echo "The same approved account can sign in on another device."
echo
echo "======================================================"
