#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

APP="$HOME/Storeman-app"

if [ ! -d "$APP" ]; then
    echo
    echo "ERROR: Storeman-app folder not found."
    echo
    echo "Run:"
    echo "ls -lah ~"
    exit 1
fi

cd "$APP"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="backup/master_link_auth_$STAMP"

SITE_URL="https://villagevictor.github.io/Storeman-app/"

ADMIN_EMAIL="ashenafihailay779@gmail.com"

echo
echo "============================================================"
echo " STOREMAN MASTER LINK + AUTH FINAL FIX"
echo "============================================================"
echo "APP: $APP"
echo "SITE: $SITE_URL"
echo "ADMIN: $ADMIN_EMAIL"
echo "TIME: $STAMP"
echo "============================================================"

# ============================================================
# 1. BACKUP
# ============================================================

echo
echo "===== 1. BACKUP ====="

mkdir -p "$BACKUP"

cp -f index.html \
    "$BACKUP/index.html.before-master" \
    2>/dev/null || true

git status --short \
    > "$BACKUP/git-status.txt" \
    2>/dev/null || true

git branch --show-current \
    > "$BACKUP/git-branch.txt" \
    2>/dev/null || true

git rev-parse HEAD \
    > "$BACKUP/git-head.txt" \
    2>/dev/null || true

echo "Backup:"
echo "$BACKUP"


# ============================================================
# 2. CHECK INDEX
# ============================================================

echo
echo "===== 2. CHECK INDEX.HTML ====="

if [ ! -f index.html ]; then
    echo "ERROR: index.html not found."
    exit 1
fi

echo "index.html found."


# ============================================================
# 3. CREATE AUTH + PROFILE SECURITY BRIDGE
# ============================================================

echo
echo "===== 3. AUTH SECURITY BRIDGE ====="

cat > storeman-auth-final.js <<'JS'
(function () {
    'use strict';

    /*
     * STOREMAN FINAL AUTH BRIDGE
     *
     * Supabase:
     *
     * Sign Up
     *     ↓
     * Auth User
     *     ↓
     * Pending Profile
     *     ↓
     * Admin Approval
     *     ↓
     * Active User
     */

    function getSupabase() {

        return (
            window.supabaseClient ||
            window.storemanSupabase ||
            window.supabase ||
            null
        );

    }


    async function getAuthUser() {

        const sb = getSupabase();

        if (!sb) {
            throw new Error(
                'Supabase client not found.'
            );
        }

        const result =
            await sb.auth.getUser();

        if (result.error) {
            throw result.error;
        }

        return result.data.user || null;

    }


    async function getProfile() {

        const sb = getSupabase();

        if (!sb) {
            throw new Error(
                'Supabase client not found.'
            );
        }

        const user =
            await getAuthUser();

        if (!user) {
            return null;
        }

        const result =
            await sb
                .from('profiles')
                .select('*')
                .eq('id', user.id)
                .maybeSingle();

        if (result.error) {
            throw result.error;
        }

        return result.data || null;

    }


    function isAdmin(profile) {

        if (!profile) {
            return false;
        }

        return (
            String(profile.status || '')
                .toLowerCase() === 'active'
            &&
            ['admin', 'owner'].includes(
                String(profile.role || '')
                    .toLowerCase()
            )
        );

    }


    function isActive(profile) {

        return (
            profile &&
            String(profile.status || '')
                .toLowerCase() === 'active'
        );

    }


    function can(profile, feature, action) {

        if (isAdmin(profile)) {
            return true;
        }

        if (!isActive(profile)) {
            return false;
        }

        const permissions =
            profile.permissions || {};

        const featurePermissions =
            permissions[feature] || {};

        return (
            featurePermissions[action] === true
        );

    }


    function hideElement(selector) {

        document
            .querySelectorAll(selector)
            .forEach(function (element) {

                element.style.display = 'none';

                element.setAttribute(
                    'aria-hidden',
                    'true'
                );

            });

    }


    function showElement(selector) {

        document
            .querySelectorAll(selector)
            .forEach(function (element) {

                element.style.display = '';

                element.setAttribute(
                    'aria-hidden',
                    'false'
                );

            });

    }


    function protectSettings(profile) {

        const admin =
            isAdmin(profile);

        /*
         * These are deliberately hidden
         * from normal users.
         */

        const selectors = [
            '#settings-user-management',
            '#manage-profile',
            '#manageProfile',
            '[data-feature="users"]',
            '[data-feature="permissions"]',
            '[data-feature="user-management"]',
            '[data-feature="manage-profile"]',
            '[data-page="users"]',
            '[data-page="permissions"]',
            '[data-section="users"]',
            '[data-section="permissions"]'
        ];

        selectors.forEach(function (selector) {

            if (admin) {
                showElement(selector);
            } else {
                hideElement(selector);
            }

        });

    }


    function protectFeatures(profile) {

        const map = {
            materials: [
                '[data-feature="materials"]',
                '#materials'
            ],

            stock_in: [
                '[data-feature="stock_in"]',
                '#stock-in',
                '#stock_in'
            ],

            stock_out: [
                '[data-feature="stock_out"]',
                '#stock-out',
                '#stock_out'
            ],

            suppliers: [
                '[data-feature="suppliers"]',
                '#suppliers'
            ],

            warehouses: [
                '[data-feature="warehouses"]',
                '#warehouses'
            ],

            customers: [
                '[data-feature="customers"]',
                '#customers'
            ],

            invoices: [
                '[data-feature="invoices"]',
                '#invoices'
            ],

            transactions: [
                '[data-feature="transactions"]',
                '#transactions'
            ],

            reports: [
                '[data-feature="reports"]',
                '#reports'
            ],

            backup: [
                '[data-feature="backup"]',
                '#backup'
            ],

            whatsapp: [
                '[data-feature="whatsapp"]',
                '#whatsapp'
            ]
        };


        Object.keys(map).forEach(
            function (feature) {

                const allowed =
                    can(
                        profile,
                        feature,
                        'view'
                    );

                map[feature].forEach(
                    function (selector) {

                        if (allowed) {
                            showElement(selector);
                        } else {
                            hideElement(selector);
                        }

                    }
                );

            }
        );

    }


    async function enforce() {

        try {

            const profile =
                await getProfile();

            if (!profile) {

                /*
                 * No authenticated user.
                 * Existing login screen remains.
                 */

                return {
                    user: null,
                    profile: null,
                    state: 'signed_out'
                };

            }


            if (
                String(profile.status)
                    .toLowerCase() === 'pending'
            ) {

                protectSettings(profile);

                /*
                 * Do not automatically sign the user out.
                 * The application can show a pending message.
                 */

                document.body
                    .setAttribute(
                        'data-storeman-auth',
                        'pending'
                    );

                return {
                    user: await getAuthUser(),
                    profile: profile,
                    state: 'pending'
                };

            }


            if (
                String(profile.status)
                    .toLowerCase() !== 'active'
            ) {

                document.body
                    .setAttribute(
                        'data-storeman-auth',
                        'blocked'
                    );

                protectSettings(profile);

                return {
                    user: await getAuthUser(),
                    profile: profile,
                    state: 'blocked'
                };

            }


            document.body
                .setAttribute(
                    'data-storeman-auth',
                    'active'
                );


            protectSettings(profile);
            protectFeatures(profile);


            return {
                user: await getAuthUser(),
                profile: profile,
                state: 'active'
            };

        } catch (error) {

            console.error(
                'Storeman auth enforcement error:',
                error
            );

            return {
                user: null,
                profile: null,
                state: 'error',
                error: error
            };

        }

    }


    async function signOut() {

        const sb =
            getSupabase();

        if (!sb) {
            throw new Error(
                'Supabase client not found.'
            );
        }

        const result =
            await sb.auth.signOut();

        if (result.error) {
            throw result.error;
        }

        window.location.reload();

    }


    window.StoremanFinalAuth = {

        getSupabase,
        getAuthUser,
        getProfile,

        isAdmin,
        isActive,
        can,

        enforce,
        signOut

    };


    document.addEventListener(
        'DOMContentLoaded',
        function () {

            setTimeout(
                function () {

                    enforce();

                },
                1200
            );

        }
    );

})();
JS


# ============================================================
# 4. CREATE PENDING USER UI
# ============================================================

echo
echo "===== 4. PENDING USER UI ====="

cat > storeman-pending-ui.js <<'JS'
(function () {

    'use strict';


    function createPendingScreen() {

        if (
            document.getElementById(
                'storeman-pending-screen'
            )
        ) {
            return;
        }


        const box =
            document.createElement('div');

        box.id =
            'storeman-pending-screen';

        box.style.cssText = `
            position:fixed;
            inset:0;
            z-index:999999;
            display:none;
            align-items:center;
            justify-content:center;
            background:#f5f7fa;
            padding:20px;
            box-sizing:border-box;
        `;


        box.innerHTML = `

            <div style="
                max-width:520px;
                width:100%;
                background:white;
                border-radius:18px;
                padding:28px;
                box-shadow:0 10px 35px rgba(0,0,0,.12);
                text-align:center;
                font-family:Arial,sans-serif;
            ">

                <div style="
                    font-size:48px;
                    margin-bottom:12px;
                ">
                    ⏳
                </div>

                <h2>
                    Account Pending Approval
                </h2>

                <p>
                    Your Storeman ERP account has been
                    created successfully.
                </p>

                <p>
                    An administrator must approve your
                    account before you can use the ERP.
                </p>

                <button
                    id="storeman-pending-signout"
                    style="
                        padding:12px 20px;
                        border:0;
                        border-radius:10px;
                        cursor:pointer;
                    "
                >
                    Sign Out
                </button>

            </div>
        `;


        document.body.appendChild(box);


        const signout =
            document.getElementById(
                'storeman-pending-signout'
            );


        if (signout) {

            signout.addEventListener(
                'click',
                async function () {

                    try {

                        await window
                            .StoremanFinalAuth
                            .signOut();

                    } catch (e) {

                        console.error(e);

                    }

                }
            );

        }

    }


    async function check() {

        if (
            !window.StoremanFinalAuth
        ) {
            return;
        }


        const state =
            await window
                .StoremanFinalAuth
                .enforce();


        createPendingScreen();


        const screen =
            document.getElementById(
                'storeman-pending-screen'
            );


        if (!screen) {
            return;
        }


        if (
            state.state === 'pending' ||
            state.state === 'blocked'
        ) {

            screen.style.display =
                'flex';

        } else {

            screen.style.display =
                'none';

        }

    }


    document.addEventListener(
        'DOMContentLoaded',
        function () {

            setTimeout(
                check,
                1600
            );

        }
    );


    window.StoremanPendingUI = {
        check
    };

})();
JS


# ============================================================
# 5. CREATE ADMIN SETTINGS GATE
# ============================================================

echo
echo "===== 5. ADMIN SETTINGS GATE ====="

cat > storeman-admin-final.js <<'JS'
(function () {

    'use strict';


    async function apply() {

        if (
            !window.StoremanFinalAuth
        ) {
            return;
        }


        const profile =
            await window
                .StoremanFinalAuth
                .getProfile();


        if (!profile) {
            return;
        }


        const admin =
            window
                .StoremanFinalAuth
                .isAdmin(profile);


        const selectors = [

            '#settings-user-management',

            '#user-management',

            '#users',

            '[data-feature="users"]',

            '[data-feature="permissions"]',

            '[data-feature="manage-profile"]',

            '[data-page="users"]',

            '[data-page="permissions"]'

        ];


        selectors.forEach(
            function (selector) {

                document
                    .querySelectorAll(selector)
                    .forEach(function (el) {

                        if (admin) {

                            el.style.display =
                                '';

                            el.hidden = false;

                        } else {

                            el.style.display =
                                'none';

                            el.hidden = true;

                            el.innerHTML =
                                '';

                        }

                    });

            }
        );

    }


    window.StoremanAdminFinal = {
        apply
    };


    document.addEventListener(
        'DOMContentLoaded',
        function () {

            setTimeout(
                apply,
                1800
            );

        }
    );

})();
JS


# ============================================================
# 6. CREATE AUTH CSS
# ============================================================

echo
echo "===== 6. AUTH CSS ====="

cat > storeman-auth-final.css <<'CSS'
[data-storeman-auth="pending"] #dashboard,
[data-storeman-auth="pending"] .dashboard,
[data-storeman-auth="blocked"] #dashboard,
[data-storeman-auth="blocked"] .dashboard {
    visibility: hidden;
}

#storeman-pending-screen {
    font-family:
        Arial,
        Helvetica,
        sans-serif;
}
CSS


# ============================================================
# 7. CONNECT FILES TO INDEX
# ============================================================

echo
echo "===== 7. CONNECT MODULES ====="

python3 - <<'PY'
from pathlib import Path

p = Path("index.html")

s = p.read_text(encoding="utf-8")

assets = [
    '<link rel="stylesheet" href="storeman-auth-final.css">',
    '<script src="storeman-auth-final.js"></script>',
    '<script src="storeman-pending-ui.js"></script>',
    '<script src="storeman-admin-final.js"></script>'
]

for asset in assets:

    if asset not in s:

        if "</head>" in s:

            s = s.replace(
                "</head>",
                "  " + asset + "\n</head>",
                1
            )

        else:

            s += "\n" + asset + "\n"


p.write_text(
    s,
    encoding="utf-8"
)

print("Auth modules connected.")
PY


# ============================================================
# 8. MAKE SURE SUPABASE CLIENT EXISTS
# ============================================================

echo
echo "===== 8. CHECK SUPABASE ====="

if grep -Eiq \
    'supabase\.createClient|createClient\(.*supabase|supabaseClient' \
    index.html
then

    echo "Supabase client reference detected."

else

    echo
    echo "WARNING:"
    echo "Supabase client was not detected automatically."
    echo
    echo "Your existing app may load Supabase from another file."
    echo "Do not delete the existing configuration."
fi


# ============================================================
# 9. CHECK AUTH MODULES
# ============================================================

echo
echo "===== 9. SECURITY CHECK ====="

test -f storeman-auth-final.js
test -f storeman-pending-ui.js
test -f storeman-admin-final.js
test -f storeman-auth-final.css

grep -q \
    "StoremanFinalAuth" \
    index.html

grep -q \
    "storeman-pending-ui.js" \
    index.html

grep -q \
    "storeman-admin-final.js" \
    index.html

echo "Security modules detected."


# ============================================================
# 10. CHECK ADMIN EMAIL
# ============================================================

echo
echo "===== 10. ADMIN CHECK ====="

if grep -Rni \
    "$ADMIN_EMAIL" \
    . \
    --exclude-dir=.git \
    --exclude-dir=backup \
    2>/dev/null | head -n 5
then
    echo "Admin email reference detected."
else
    echo "WARNING: Admin email not found in frontend."
fi


# ============================================================
# 11. CHECK GITHUB
# ============================================================

echo
echo "===== 11. GITHUB CHECK ====="

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then

    echo "Git repository: OK"

else

    echo "ERROR: This folder is not a Git repository."
    exit 1

fi


REMOTE="$(git remote get-url origin 2>/dev/null || true)"

echo "Remote:"
echo "$REMOTE"


# ============================================================
# 12. GIT DIFF CHECK
# ============================================================

echo
echo "===== 12. GIT DIFF CHECK ====="

git diff --check || true


# ============================================================
# 13. SHOW CHANGES
# ============================================================

echo
echo "===== 13. CHANGED FILES ====="

git status --short


# ============================================================
# 14. COMMIT
# ============================================================

echo
echo "===== 14. COMMIT ====="

git add \
    index.html \
    storeman-auth-final.js \
    storeman-pending-ui.js \
    storeman-admin-final.js \
    storeman-auth-final.css \
    "$BACKUP"

git commit \
    -m "fix: finalize supabase auth approval permissions and share link" \
    || echo "Nothing new to commit."


# ============================================================
# 15. PUSH
# ============================================================

echo
echo "===== 15. PUSH TO GITHUB ====="

BRANCH="$(git branch --show-current)"

if [ -z "$BRANCH" ]; then

    echo "ERROR: Git branch not detected."
    exit 1

fi


echo "Branch:"
echo "$BRANCH"


if git push origin "$BRANCH"; then

    echo
    echo "GITHUB PUSH: SUCCESS"

else

    echo
    echo "GITHUB PUSH: FAILED"
    echo
    echo "Your local changes are still safe."
    echo
    echo "Retry:"
    echo "cd ~/Storeman-app"
    echo "git push origin $BRANCH"
    echo
    echo "If DNS/network is unavailable, connect to a working"
    echo "internet connection and retry."
fi


# ============================================================
# 16. GITHUB PAGES DETECTION
# ============================================================

echo
echo "===== 16. GITHUB PAGES ====="

echo
echo "Expected application URL:"
echo "$SITE_URL"

echo
echo "If GitHub Pages is already enabled for this repository,"
echo "the link should be:"
echo "$SITE_URL"


# ============================================================
# 17. FINAL VERIFICATION
# ============================================================

echo
echo "===== 17. FINAL VERIFICATION ====="

echo
echo "--- index modules ---"

grep -n \
    "storeman-auth-final.js" \
    index.html || true

grep -n \
    "storeman-pending-ui.js" \
    index.html || true

grep -n \
    "storeman-admin-final.js" \
    index.html || true

grep -n \
    "storeman-auth-final.css" \
    index.html || true


echo
echo "--- files ---"

ls -lh \
    index.html \
    storeman-auth-final.js \
    storeman-pending-ui.js \
    storeman-admin-final.js \
    storeman-auth-final.css


# ============================================================
# 18. FINAL MESSAGE
# ============================================================

echo
echo "============================================================"
echo " STOREMAN MASTER COMPLETE"
echo "============================================================"

echo
echo "SHARE LINK:"
echo "$SITE_URL"

echo
echo "AUTH FLOW:"
echo "Sign Up"
echo "  -> Supabase Auth"
echo "  -> Pending Profile"
echo "  -> Admin Approval"
echo "  -> Active"
echo "  -> Permissions"
echo "  -> Dashboard"

echo
echo "ADMIN:"
echo "$ADMIN_EMAIL"

echo
echo "ADMIN ONLY:"
echo "Settings"
echo "User Management"
echo "Manage Profile"
echo "Permissions"

echo
echo "MULTI DEVICE:"
echo "Android"
echo "iPhone"
echo "Computer"

echo
echo "BACKUP:"
echo "$BACKUP"

echo
echo "============================================================"
echo " IMPORTANT"
echo "============================================================"

echo
echo "If the share link still shows only 'Please Sign In',"
echo "that is NORMAL for a new device."
echo
echo "A new device has no Supabase session."
echo "The user must Sign In or Sign Up."
echo
echo "After Sign In:"
echo "  pending -> waiting for admin"
echo "  active  -> dashboard"
echo "  suspended/rejected -> blocked"
echo
echo "============================================================"
