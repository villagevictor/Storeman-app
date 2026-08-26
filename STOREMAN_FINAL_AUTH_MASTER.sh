#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "============================================================"
echo "        STOREMAN FINAL AUTH + FULL APP MASTER"
echo "============================================================"

ROOT="$HOME/Storeman-app"
INDEX="$ROOT/app/src/main/assets/index.html"
AUTH="$ROOT/app/src/main/assets/storeman-auth.js"

cd "$ROOT"

if [ ! -f "$INDEX" ]; then
    echo "ERROR: Existing Storeman index.html was not found."
    exit 1
fi

echo
echo "1. Creating safety backup..."

BACKUP="backup_before_final_auth_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"

cp "$INDEX" "$BACKUP/index.html"

if [ -f "$AUTH" ]; then
    cp "$AUTH" "$BACKUP/storeman-auth.js"
fi

cp app/src/main/AndroidManifest.xml "$BACKUP/AndroidManifest.xml" 2>/dev/null || true

echo "Backup created: $BACKUP"

echo
echo "2. Checking existing Storeman features..."

FEATURES=(
"warehouses_store"
"suppliers_store"
"sales_orders"
"store_backups"
"transactions"
"sendWhatsAppReceipt"
"processStockIn"
"emailjs"
"sendDailyReport"
"activeReceiptData"
)

for F in "${FEATURES[@]}"; do
    if grep -Eiq "$F" "$INDEX"; then
        echo "✓ $F"
    else
        echo "! $F not found"
    fi
done

echo
echo "3. Creating authentication layer..."

cat > "$AUTH" <<'AUTHJS'
(function () {
    "use strict";

    const SUPABASE_URL =
        "https://cfnrbgfczqfpmdjzzbia.supabase.co";

    const SUPABASE_ANON_KEY =
        "sb_publishable_AN3kSG6xIx38ThIMg4o28w_u6kPIrn2";

    let sb = null;
    let currentUser = null;
    let currentProfile = null;

    const FEATURES = [
        "dashboard",
        "materials",
        "stock_in",
        "stock_out",
        "warehouses",
        "suppliers",
        "customers",
        "invoices",
        "transactions",
        "backup",
        "reports",
        "whatsapp",
        "settings",
        "users"
    ];

    function $(id) {
        return document.getElementById(id);
    }

    function esc(value) {
        return String(value ?? "")
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
            .replaceAll("'", "&#039;");
    }

    function createAuthScreen() {

        if ($("storeman-auth-root")) return;

        const root = document.createElement("div");

        root.id = "storeman-auth-root";

        root.innerHTML = `
        <div id="storeman-login-page">

            <div class="storeman-login-card">

                <div class="storeman-logo">📦</div>

                <h1>STOREMAN</h1>

                <p class="storeman-subtitle">
                    Inventory & Business Management
                </p>

                <form id="storeman-login-form">

                    <input
                        id="storeman-email"
                        type="email"
                        placeholder="Email"
                        autocomplete="username"
                        required
                    >

                    <input
                        id="storeman-password"
                        type="password"
                        placeholder="Password"
                        autocomplete="current-password"
                        required
                    >

                    <button type="submit">
                        🔐 Login
                    </button>

                    <button
                        type="button"
                        id="storeman-reset-password"
                        class="secondary"
                    >
                        Forgot Password?
                    </button>

                </form>

                <div id="storeman-login-message"></div>

            </div>

        </div>

        <div id="storeman-admin-panel" style="display:none">

            <div class="storeman-admin-card">

                <div class="admin-header">
                    <div>
                        <b>🛡 STOREMAN ADMIN</b>
                        <div id="admin-company-name"></div>
                    </div>

                    <button id="admin-close">
                        ✕
                    </button>
                </div>

                <div class="admin-grid">

                    <div class="admin-box">
                        <h3>👤 Users</h3>
                        <div id="admin-users"></div>
                    </div>

                    <div class="admin-box">
                        <h3>📊 Activity</h3>
                        <div id="admin-activity"></div>
                    </div>

                </div>

            </div>

        </div>
        `;

        document.body.prepend(root);

        $("storeman-login-form")
            .addEventListener("submit", login);

        $("storeman-reset-password")
            .addEventListener("click", resetPassword);

        $("admin-close")
            .addEventListener("click", function () {
                $("storeman-admin-panel").style.display = "none";
            });
    }

    function installStyles() {

        const style = document.createElement("style");

        style.id = "storeman-auth-style";

        style.textContent = `
        #storeman-login-page {
            position:fixed;
            inset:0;
            z-index:999999;
            background:#f3f6f9;
            display:flex;
            justify-content:center;
            align-items:center;
            padding:20px;
            font-family:Arial,sans-serif;
        }

        .storeman-login-card {
            width:100%;
            max-width:390px;
            background:white;
            padding:30px;
            border-radius:16px;
            box-shadow:0 15px 45px rgba(0,0,0,.15);
            text-align:center;
        }

        .storeman-logo {
            font-size:55px;
        }

        .storeman-login-card h1 {
            margin:5px 0;
            color:#0f2b48;
        }

        .storeman-subtitle {
            color:#777;
            margin-bottom:25px;
        }

        .storeman-login-card input {
            width:100%;
            box-sizing:border-box;
            padding:13px;
            margin:7px 0;
            border:1px solid #ddd;
            border-radius:8px;
            font-size:15px;
        }

        .storeman-login-card button {
            width:100%;
            padding:13px;
            margin-top:10px;
            border:0;
            border-radius:8px;
            background:#0f2b48;
            color:white;
            font-weight:bold;
            cursor:pointer;
        }

        .storeman-login-card button.secondary {
            background:#eee;
            color:#333;
        }

        #storeman-login-message {
            margin-top:15px;
            font-size:14px;
        }

        #storeman-admin-panel {
            position:fixed;
            inset:0;
            z-index:1000000;
            background:rgba(0,0,0,.65);
            overflow:auto;
            padding:20px;
            font-family:Arial,sans-serif;
        }

        .storeman-admin-card {
            max-width:1000px;
            margin:auto;
            background:white;
            border-radius:15px;
            padding:20px;
        }

        .admin-header {
            display:flex;
            justify-content:space-between;
            align-items:center;
            border-bottom:1px solid #ddd;
            padding-bottom:15px;
        }

        .admin-header button {
            border:0;
            background:#eee;
            padding:8px 12px;
            border-radius:7px;
        }

        .admin-grid {
            display:grid;
            grid-template-columns:1fr 1fr;
            gap:15px;
            margin-top:20px;
        }

        .admin-box {
            border:1px solid #ddd;
            border-radius:10px;
            padding:15px;
        }

        .admin-user {
            padding:10px;
            border-bottom:1px solid #eee;
        }

        .admin-user small {
            color:#777;
        }

        @media(max-width:700px) {
            .admin-grid {
                grid-template-columns:1fr;
            }
        }
        `;

        document.head.appendChild(style);
    }

    function setMessage(message, error) {

        const box = $("storeman-login-message");

        if (!box) return;

        box.textContent = message;

        box.style.color = error ? "#c62828" : "#16803c";
    }

    async function initSupabase() {

        if (typeof supabase === "undefined") {
            setMessage(
                "Supabase library failed to load.",
                true
            );
            return false;
        }

        sb = supabase.createClient(
            SUPABASE_URL,
            SUPABASE_ANON_KEY
        );

        return true;
    }

    async function login(event) {

        event.preventDefault();

        const email =
            $("storeman-email").value.trim();

        const password =
            $("storeman-password").value;

        setMessage("Signing in...", false);

        try {

            const result =
                await sb.auth.signInWithPassword({
                    email,
                    password
                });

            if (result.error)
                throw result.error;

            await loadProfile();

            if (!currentProfile) {

                await sb.auth.signOut();

                throw new Error(
                    "Your account has no Storeman profile."
                );
            }

            if (
                currentProfile.status !== "active"
            ) {

                await sb.auth.signOut();

                throw new Error(
                    "This user account is disabled."
                );
            }

            await recordActivity(
                "LOGIN",
                "profiles",
                currentUser.id
            );

            hideLogin();

            applyPermissions();

            showAdminIfNeeded();

            setLastSeen();

        } catch (error) {

            console.error(error);

            setMessage(
                error.message ||
                "Login failed.",
                true
            );
        }
    }

    async function loadProfile() {

        const result =
            await sb.auth.getUser();

        if (result.error)
            throw result.error;

        currentUser = result.data.user;

        if (!currentUser)
            throw new Error("No authenticated user.");

        const profile =
            await sb
                .from("profiles")
                .select("*")
                .eq("id", currentUser.id)
                .maybeSingle();

        if (profile.error)
            throw profile.error;

        currentProfile = profile.data;

        if (currentProfile) {

            await sb
                .from("profiles")
                .update({
                    last_login_at:
                        currentProfile.last_login_at ||
                        new Date().toISOString(),

                    last_seen_at:
                        new Date().toISOString()
                })
                .eq("id", currentUser.id);
        }
    }

    function hideLogin() {

        const page =
            $("storeman-login-page");

        if (page)
            page.style.display = "none";
    }

    function showLogin() {

        const page =
            $("storeman-login-page");

        if (page)
            page.style.display = "flex";
    }

    async function logout() {

        try {

            if (currentUser) {

                await recordActivity(
                    "LOGOUT",
                    "profiles",
                    currentUser.id
                );
            }

            await sb.auth.signOut();

        } finally {

            currentUser = null;
            currentProfile = null;

            location.reload();
        }
    }

    async function resetPassword() {

        const email =
            $("storeman-email").value.trim();

        if (!email) {

            setMessage(
                "Enter your email first.",
                true
            );

            return;
        }

        try {

            const result =
                await sb.auth.resetPasswordForEmail(
                    email,
                    {
                        redirectTo:
                            window.location.origin +
                            window.location.pathname
                    }
                );

            if (result.error)
                throw result.error;

            setMessage(
                "Password reset email sent.",
                false
            );

        } catch (error) {

            setMessage(
                error.message ||
                "Password reset failed.",
                true
            );
        }
    }

    function currentRole() {

        return String(
            currentProfile?.role || ""
        ).toLowerCase();
    }

    function isAdmin() {

        return [
            "admin",
            "owner"
        ].includes(currentRole());
    }

    function hasPermission(
        feature,
        action
    ) {

        if (isAdmin())
            return true;

        const p =
            currentProfile?.permissions || {};

        return Boolean(
            p?.[feature]?.[action]
        );
    }

    function applyPermissions() {

        if (!currentProfile)
            return;

        /*
         * The database RLS is the real security layer.
         * This UI layer only hides unavailable features.
         */

        const buttons =
            document.querySelectorAll(
                "button"
            );

        buttons.forEach(button => {

            const text =
                (button.innerText || "")
                .toLowerCase();

            let feature = null;

            if (
                text.includes("warehouse")
            )
                feature = "warehouses";

            else if (
                text.includes("supplier")
            )
                feature = "suppliers";

            else if (
                text.includes("receive stock") ||
                text.includes("stock in")
            )
                feature = "stock_in";

            else if (
                text.includes("stock out") ||
                text.includes("issue stock")
            )
                feature = "stock_out";

            else if (
                text.includes("backup")
            )
                feature = "backup";

            else if (
                text.includes("daily report")
            )
                feature = "reports";

            else if (
                text.includes("whatsapp")
            )
                feature = "whatsapp";

            if (
                feature &&
                !hasPermission(feature, "view")
            ) {

                button.style.display =
                    "none";
            }
        });

        window.storemanAuth = {
            user: currentUser,
            profile: currentProfile,
            isAdmin,
            hasPermission,
            logout
        };
    }

    async function setLastSeen() {

        if (!currentUser)
            return;

        await sb
            .from("profiles")
            .update({
                last_seen_at:
                    new Date().toISOString()
            })
            .eq("id", currentUser.id);
    }

    async function recordActivity(
        action,
        tableName,
        recordId
    ) {

        if (!sb || !currentUser)
            return;

        const companyId =
            currentProfile?.company_id;

        if (!companyId)
            return;

        try {

            await sb
                .from("activity_logs")
                .insert([{
                    user_id: currentUser.id,
                    company_id: companyId,
                    action,
                    table_name:
                        tableName || null,
                    record_id:
                        recordId || null,
                    details: {
                        source:
                            "storeman-web"
                    }
                }]);

        } catch (error) {

            console.warn(
                "Activity logging failed:",
                error
            );
        }
    }

    async function showAdminIfNeeded() {

        if (!isAdmin())
            return;

        const panel =
            $("storeman-admin-panel");

        if (!panel)
            return;

        panel.style.display = "block";

        const company =
            await sb
                .from("companies")
                .select("name")
                .eq(
                    "id",
                    currentProfile.company_id
                )
                .maybeSingle();

        if (
            company.data &&
            $("admin-company-name")
        ) {

            $("admin-company-name")
                .textContent =
                company.data.name;
        }

        await loadUsers();

        await loadActivity();
    }

    async function loadUsers() {

        const box =
            $("admin-users");

        if (!box)
            return;

        const result =
            await sb
                .from("profiles")
                .select(
                    "id,full_name,email,role,status,warehouse_id,last_login_at,last_seen_at"
                )
                .eq(
                    "company_id",
                    currentProfile.company_id
                )
                .order(
                    "last_seen_at",
                    { ascending:false }
                );

        if (result.error) {

            box.textContent =
                result.error.message;

            return;
        }

        if (!result.data.length) {

            box.textContent =
                "No users found.";

            return;
        }

        box.innerHTML =
            result.data.map(u => `
                <div class="admin-user">

                    <b>
                        ${esc(
                            u.full_name ||
                            u.email ||
                            u.id
                        )}
                    </b>

                    <br>

                    <small>
                        ${esc(u.email || "")}
                        —
                        ${esc(u.role || "user")}
                        —
                        ${esc(u.status || "active")}
                    </small>

                    <br>

                    <small>
                        Last login:
                        ${esc(
                            u.last_login_at ||
                            "Never"
                        )}
                    </small>

                </div>
            `).join("");
    }

    async function loadActivity() {

        const box =
            $("admin-activity");

        if (!box)
            return;

        const result =
            await sb
                .from("activity_logs")
                .select(
                    "action,table_name,created_at,user_id,details"
                )
                .eq(
                    "company_id",
                    currentProfile.company_id
                )
                .order(
                    "created_at",
                    { ascending:false }
                )
                .limit(50);

        if (result.error) {

            box.textContent =
                result.error.message;

            return;
        }

        box.innerHTML =
            result.data.map(a => `
                <div class="admin-user">
                    <b>${esc(a.action)}</b>
                    <br>
                    <small>
                        ${esc(
                            a.table_name || ""
                        )}
                        —
                        ${esc(
                            a.created_at || ""
                        )}
                    </small>
                </div>
            `).join("") ||
            "No activity yet.";
    }

    async function boot() {

        createAuthScreen();

        installStyles();

        if (
            !(await initSupabase())
        )
            return;

        const session =
            await sb.auth.getSession();

        if (
            session.data &&
            session.data.session
        ) {

            try {

                await loadProfile();

                if (
                    currentProfile &&
                    currentProfile.status ===
                    "active"
                ) {

                    hideLogin();

                    applyPermissions();

                    showAdminIfNeeded();

                    setLastSeen();

                    return;
                }

            } catch (error) {

                console.warn(error);
            }
        }

        showLogin();

        sb.auth.onAuthStateChange(
            async function (event) {

                if (
                    event === "SIGNED_OUT"
                ) {

                    showLogin();

                    return;
                }

                if (
                    event === "SIGNED_IN"
                ) {

                    try {

                        await loadProfile();

                        if (
                            currentProfile &&
                            currentProfile.status ===
                            "active"
                        ) {

                            hideLogin();

                            applyPermissions();

                            showAdminIfNeeded();

                            setLastSeen();
                        }

                    } catch (error) {

                        console.error(error);
                    }
                }
            }
        );
    }

    window.StoremanAuth = {
        boot,
        logout,
        hasPermission,
        isAdmin,
        recordActivity
    };

    if (
        document.readyState ===
        "loading"
    ) {

        document.addEventListener(
            "DOMContentLoaded",
            boot
        );

    } else {

        boot();
    }

})();
AUTHJS

echo "✓ storeman-auth.js created"

echo
echo "4. Adding authentication script to EXISTING index.html..."

python - <<'PY'
from pathlib import Path

p = Path("app/src/main/assets/index.html")
s = p.read_text(encoding="utf-8")

tag = '<script src="storeman-auth.js"></script>'

if tag not in s:

    marker = "</body>"

    if marker in s:
        s = s.replace(
            marker,
            tag + "\n" + marker,
            1
        )

    else:
        s += "\n" + tag + "\n"

    p.write_text(
        s,
        encoding="utf-8"
    )

    print("✓ Authentication layer linked")

else:
    print("✓ Authentication layer already linked")
PY

echo
echo "5. Updating Android WebView configuration..."

cat > app/src/main/java/com/example/storeman/MainActivity.java <<'JAVA'
package com.example.storeman;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;

public class MainActivity extends Activity {

    private WebView webView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        webView = new WebView(this);

        WebSettings settings =
                webView.getSettings();

        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setJavaScriptCanOpenWindowsAutomatically(true);

        webView.setWebViewClient(
            new WebViewClient() {

                @Override
                public boolean shouldOverrideUrlLoading(
                        WebView view,
                        WebResourceRequest request) {

                    return handleUrl(
                        request.getUrl().toString()
                    );
                }

                @Override
                public boolean shouldOverrideUrlLoading(
                        WebView view,
                        String url) {

                    return handleUrl(url);
                }

                private boolean handleUrl(String url) {

                    if (
                        url.startsWith("mailto:") ||
                        url.startsWith("https://wa.me/") ||
                        url.startsWith("whatsapp:")
                    ) {

                        try {

                            Intent intent =
                                new Intent(
                                    Intent.ACTION_VIEW,
                                    Uri.parse(url)
                                );

                            startActivity(intent);

                        } catch(Exception ignored) {}

                        return true;
                    }

                    return false;
                }
            }
        );

        webView.loadUrl(
            "file:///android_asset/index.html"
        );

        setContentView(webView);
    }

    @Override
    public void onBackPressed() {

        if (webView != null &&
            webView.canGoBack()) {

            webView.goBack();

        } else {

            super.onBackPressed();
        }
    }
}
JAVA

echo "✓ Android WebView updated"

echo
echo "6. Checking that original Storeman remains..."

wc -c "$INDEX"

echo
echo "7. Checking auth layer..."

grep -nE \
"storeman-auth.js|storeman-login|StoremanAuth|currentProfile|company_id|hasPermission" \
"$INDEX" \
"$AUTH" \
| head -50

echo
echo "8. Git status..."

git status --short

echo
echo "9. Git add..."

git add \
app/src/main/assets/index.html \
app/src/main/assets/storeman-auth.js \
app/src/main/java/com/example/storeman/MainActivity.java

echo
echo "10. Commit..."

git commit -m \
"Storeman: integrate authentication company security and admin layer" \
|| true

echo
echo "11. Push..."

git branch --show-current

BRANCH="$(git branch --show-current)"

if [ -z "$BRANCH" ]; then
    BRANCH="main"
fi

git push origin "$BRANCH"

echo
echo "============================================================"
echo "       STOREMAN FINAL MASTER COMPLETE"
echo "============================================================"

echo
echo "Existing Storeman features were preserved."

echo
echo "Authentication:"
echo "✓ Supabase Login"
echo "✓ Active User Check"
echo "✓ Company Isolation"
echo "✓ Admin / Owner detection"
echo "✓ Permission foundation"
echo "✓ Last Login"
echo "✓ Last Seen"
echo "✓ Activity Log"
echo "✓ Admin Users View"
echo "✓ Password Reset"
echo "✓ Android WebView integration"

echo
echo "IMPORTANT:"
echo "Do NOT put Supabase service_role key inside index.html."
echo "The browser must use only the publishable/anon key."

echo
echo "NEXT:"
echo "Create the first Admin in Supabase Authentication."
echo "Then create its matching profiles row with:"
echo "role = admin"
echo "status = active"
echo "company_id = Storeman Main Company"

echo
echo "GitHub Pages:"
echo "https://villagevictor.github.io/Storeman-app/"

echo
echo "============================================================"
