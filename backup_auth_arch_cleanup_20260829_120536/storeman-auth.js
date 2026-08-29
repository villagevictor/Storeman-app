(function () {
    "use strict";

    /*
     * ============================================================
     * STOREMAN FINAL AUTH SYSTEM
     * ============================================================
     *
     * Features:
     *
     * User management
     * Block / Unblock
     * Role management
     * Company assignment
     * Warehouse assignment
     * Permissions
     * Activity logs
     * Last login / Last seen
     * Persistent Supabase session
     * Logout
     * Forgot password
     *
     * IMPORTANT:
     * RLS remains the real database security layer.
     * This JavaScript only provides the UI and calls Supabase.
     */

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

    const ACTIONS = [
        "view",
        "create",
        "update",
        "delete"
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

    function notify(message, error) {

        let box = $("storeman-global-message");

        if (!box) {

            box = document.createElement("div");

            box.id =
                "storeman-global-message";

            box.style.cssText = `
                position:fixed;
                top:15px;
                left:50%;
                transform:translateX(-50%);
                z-index:10000000;
                padding:12px 18px;
                border-radius:8px;
                font-family:Arial,sans-serif;
                font-size:14px;
                box-shadow:0 5px 20px rgba(0,0,0,.2);
                max-width:90%;
                text-align:center;
            `;

            document.body.appendChild(box);
        }

        box.textContent = message;

        box.style.background =
            error ? "#ffebee" : "#e8f5e9";

        box.style.color =
            error ? "#b71c1c" : "#1b5e20";

        clearTimeout(
            box._timer
        );

        box._timer =
            setTimeout(
                () => box.remove(),
                5000
            );
    }

    function createAuthScreen() {

        if ($("storeman-auth-root"))
            return;

        const root =
            document.createElement("div");

        root.id =
            "storeman-auth-root";

        root.innerHTML = `

        <!-- =====================================================
             LOGIN
        ====================================================== -->

        <div id="storeman-login-page">

            <div class="storeman-login-card">

                <div class="storeman-logo">
                    📦
                </div>

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
                        📧 Forgot Password?
                    </button>

                </form>

                <div id="storeman-login-message"></div>

            </div>

        </div>


        <!-- =====================================================
             ADMIN PANEL
        ====================================================== -->

        <div
            id="storeman-admin-panel"
            style="display:none"
        >

            <div class="storeman-admin-card">

                <div class="admin-header">

                    <div>

                        <b>
                            🛡 STOREMAN ADMIN
                        </b>

                        <div
                            id="admin-company-name"
                            class="admin-company-name"
                        ></div>

                    </div>

                    <button
                        id="admin-close"
                        class="admin-close"
                    >
                        ✕
                    </button>

                </div>


                <!-- ADMIN ACTION BAR -->

                <div class="admin-toolbar">

                    <button
                        id="admin-refresh"
                    >
                        🔄 Refresh
                    </button>

                    <button
                        id="admin-logout"
                    >
                        🚪 Logout
                    </button>

                </div>


                <!-- USERS -->

                <div class="admin-section">

                    <h2>
                        👤 User Management
                    </h2>

                    <div
                        id="admin-users"
                    >
                        Loading users...
                    </div>

                </div>


                <!-- ACTIVITY -->

                <div class="admin-section">

                    <h2>
                        📊 Activity Logs
                    </h2>

                    <div
                        id="admin-activity"
                    >
                        Loading activity...
                    </div>

                </div>

            </div>

        </div>


        <!-- =====================================================
             USER EDIT MODAL
        ====================================================== -->

        <div
            id="storeman-user-modal"
            style="display:none"
        >

            <div class="storeman-user-modal-card">

                <div class="modal-header">

                    <b>
                        🔐 Manage User
                    </b>

                    <button
                        id="user-modal-close"
                    >
                        ✕
                    </button>

                </div>


                <input
                    type="hidden"
                    id="edit-user-id"
                >


                <div class="modal-field">

                    <label>
                        Email
                    </label>

                    <input
                        id="edit-user-email"
                        readonly
                    >

                </div>


                <div class="modal-field">

                    <label>
                        Role
                    </label>

                    <select id="edit-user-role">

                        <option value="user">
                            User
                        </option>

                        <option value="manager">
                            Manager
                        </option>

                        <option value="admin">
                            Admin
                        </option>

                        <option value="owner">
                            Owner
                        </option>

                    </select>

                </div>


                <div class="modal-field">

                    <label>
                        Status
                    </label>

                    <select id="edit-user-status">

                        <option value="active">
                            Active
                        </option>

                        <option value="blocked">
                            Blocked
                        </option>

                    </select>

                </div>


                <div class="modal-field">

                    <label>
                        🏢 Company
                    </label>

                    <select id="edit-user-company">

                        <option value="">
                            Select company
                        </option>

                    </select>

                </div>


                <div class="modal-field">

                    <label>
                        🏭 Warehouse
                    </label>

                    <select id="edit-user-warehouse">

                        <option value="">
                            No warehouse
                        </option>

                    </select>

                </div>


                <div class="modal-field">

                    <label>
                        🔐 Permissions
                    </label>

                    <div
                        id="edit-user-permissions"
                        class="permission-grid"
                    ></div>

                </div>


                <button
                    id="save-user-changes"
                    class="save-user-button"
                >
                    💾 Save Changes
                </button>

                <div
                    id="user-edit-message"
                ></div>

            </div>

        </div>
        `;

        document.body.prepend(root);

        $("storeman-login-form")
            .addEventListener(
                "submit",
                login
            );

        $("storeman-reset-password")
            .addEventListener(
                "click",
                resetPassword
            );

        $("admin-close")
            .addEventListener(
                "click",
                closeAdmin
            );

        $("admin-refresh")
            .addEventListener(
                "click",
                refreshAdmin
            );

        $("admin-logout")
            .addEventListener(
                "click",
                logout
            );

        $("user-modal-close")
            .addEventListener(
                "click",
                closeUserModal
            );

        $("save-user-changes")
            .addEventListener(
                "click",
                saveUserChanges
            );
    }


    function installStyles() {

        if ($("storeman-auth-style"))
            return;

        const style =
            document.createElement("style");

        style.id =
            "storeman-auth-style";

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

            box-shadow:
                0 15px 45px
                rgba(0,0,0,.15);

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


        .storeman-login-card input,
        .storeman-user-modal-card input,
        .storeman-user-modal-card select {

            width:100%;

            box-sizing:border-box;

            padding:12px;

            margin:6px 0;

            border:
                1px solid #ddd;

            border-radius:8px;

            font-size:14px;
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

            background:
                rgba(0,0,0,.65);

            overflow:auto;

            padding:20px;

            font-family:Arial,sans-serif;
        }


        .storeman-admin-card {

            max-width:1100px;

            margin:auto;

            background:white;

            border-radius:15px;

            padding:20px;
        }


        .admin-header {

            display:flex;

            justify-content:space-between;

            align-items:center;

            border-bottom:
                1px solid #ddd;

            padding-bottom:15px;
        }


        .admin-company-name {

            margin-top:5px;

            color:#777;

            font-size:13px;
        }


        .admin-close {

            border:0;

            background:#eee;

            padding:8px 12px;

            border-radius:7px;

            cursor:pointer;
        }


        .admin-toolbar {

            display:flex;

            gap:10px;

            flex-wrap:wrap;

            margin:15px 0;
        }


        .admin-toolbar button {

            border:0;

            border-radius:7px;

            padding:10px 14px;

            cursor:pointer;

            font-weight:bold;
        }


        .admin-section {

            border:
                1px solid #ddd;

            border-radius:10px;

            padding:15px;

            margin-top:15px;

            overflow:auto;
        }


        .admin-section h2 {

            margin-top:0;

            color:#0f2b48;
        }


        .admin-user {

            padding:14px;

            border-bottom:
                1px solid #eee;
        }


        .admin-user:last-child {

            border-bottom:0;
        }


        .admin-user button {

            margin-top:8px;

            margin-right:5px;

            padding:8px 12px;

            border:0;

            border-radius:6px;

            cursor:pointer;
        }


        .user-edit-button {

            background:#0f2b48;

            color:white;
        }


        .block-button {

            background:#ffebee;

            color:#b71c1c;
        }


        .unblock-button {

            background:#e8f5e9;

            color:#1b5e20;
        }


        .status-active {

            color:#16803c;

            font-weight:bold;
        }


        .status-blocked {

            color:#c62828;

            font-weight:bold;
        }


        #storeman-user-modal {

            position:fixed;

            inset:0;

            z-index:1000001;

            background:
                rgba(0,0,0,.65);

            display:flex;

            justify-content:center;

            align-items:center;

            padding:20px;

            overflow:auto;
        }


        .storeman-user-modal-card {

            width:100%;

            max-width:650px;

            background:white;

            border-radius:14px;

            padding:20px;
        }


        .modal-header {

            display:flex;

            justify-content:space-between;

            align-items:center;

            border-bottom:
                1px solid #ddd;

            padding-bottom:12px;

            margin-bottom:15px;
        }


        .modal-header button {

            border:0;

            background:#eee;

            border-radius:6px;

            padding:7px 11px;

        }


        .modal-field {

            margin-bottom:12px;
        }


        .modal-field label {

            display:block;

            font-weight:bold;

            margin-bottom:4px;

        }


        .permission-grid {

            display:grid;

            grid-template-columns:
                repeat(2,1fr);

            gap:8px;

            max-height:300px;

            overflow:auto;

            border:
                1px solid #ddd;

            border-radius:8px;

            padding:10px;
        }


        .permission-item {

            border:
                1px solid #eee;

            padding:8px;

            border-radius:6px;

            font-size:13px;
        }


        .permission-item strong {

            display:block;

            margin-bottom:5px;
        }


        .permission-item label {

            display:inline-block;

            margin-right:7px;

            font-weight:normal;

        }


        .save-user-button {

            width:100%;

            padding:13px;

            border:0;

            border-radius:8px;

            background:#0f2b48;

            color:white;

            font-weight:bold;

            cursor:pointer;
        }


        #user-edit-message {

            margin-top:10px;

            font-size:13px;
        }


        @media(max-width:700px) {

            .permission-grid {

                grid-template-columns:1fr;
            }

            .storeman-admin-card {

                padding:12px;
            }
        }

        `;

        document.head.appendChild(style);
    }


    function setMessage(message, error) {

        const box =
            $("storeman-login-message");

        if (!box)
            return;

        box.textContent =
            message;

        box.style.color =
            error
            ? "#c62828"
            : "#16803c";
    }


    async function initSupabase() {

        if (
            typeof supabase ===
            "undefined"
        ) {

            setMessage(
                "Supabase library failed to load.",
                true
            );

            return false;
        }

        sb =
            supabase.createClient(
                SUPABASE_URL,
                SUPABASE_ANON_KEY
            );

        return true;
    }


    async function login(event) {

        event.preventDefault();

        const email =
            $("storeman-email")
                .value
                .trim();

        const password =
            $("storeman-password")
                .value;

        setMessage(
            "Signing in...",
            false
        );

        try {

            const result =
                await sb.auth
                    .signInWithPassword({
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
                currentProfile.status !==
                "active"
            ) {

                await sb.auth.signOut();

                throw new Error(
                    "This user account is blocked or disabled."
                );
            }

            await recordActivity(
                "LOGIN",
                "profiles",
                currentUser.id
            );

            hideLogin();

            applyPermissions();

            await showAdminIfNeeded();

            await setLastSeen();

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

        currentUser =
            result.data.user;

        if (!currentUser)
            throw new Error(
                "No authenticated user."
            );

        const profile =
            await sb
                .from("profiles")
                .select("*")
                .eq(
                    "id",
                    currentUser.id
                )
                .maybeSingle();

        if (profile.error)
            throw profile.error;

        currentProfile =
            profile.data;

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
                .eq(
                    "id",
                    currentUser.id
                );
        }
    }


    function hideLogin() {

        const page =
            $("storeman-login-page");

        if (page)
            page.style.display =
                "none";
    }


    function showLogin() {

        const page =
            $("storeman-login-page");

        if (page)
            page.style.display =
                "flex";
    }


    function closeAdmin() {

        const panel =
            $("storeman-admin-panel");

        if (panel)
            panel.style.display =
                "none";
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

        } catch (error) {

            console.error(error);

        } finally {

            currentUser = null;

            currentProfile = null;

            location.reload();
        }
    }


    async function resetPassword() {

        const email =
            $("storeman-email")
                .value
                .trim();

        if (!email) {

            setMessage(
                "Enter your email first.",
                true
            );

            return;
        }

        try {

            const result =
                await sb.auth
                    .resetPasswordForEmail(
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
            currentProfile?.role ||
            ""
        ).toLowerCase();
    }


    function isAdmin() {

        return [
            "admin",
            "owner"
        ].includes(
            currentRole()
        );
    }


    function hasPermission(
        feature,
        action
    ) {

        if (isAdmin())
            return true;

        const permissions =
            currentProfile?.permissions ||
            {};

        return Boolean(
            permissions?.[feature]?.[action]
        );
    }


    function applyPermissions() {

        if (!currentProfile)
            return;

        const buttons =
            document.querySelectorAll(
                "button"
            );

        buttons.forEach(button => {

            const text =
                (
                    button.innerText ||
                    ""
                ).toLowerCase();

            let feature = null;

            if (
                text.includes("warehouse")
            )
                feature =
                    "warehouses";

            else if (
                text.includes("supplier")
            )
                feature =
                    "suppliers";

            else if (
                text.includes("receive stock") ||
                text.includes("stock in")
            )
                feature =
                    "stock_in";

            else if (
                text.includes("stock out") ||
                text.includes("issue stock")
            )
                feature =
                    "stock_out";

            else if (
                text.includes("backup")
            )
                feature =
                    "backup";

            else if (
                text.includes("daily report")
            )
                feature =
                    "reports";

            else if (
                text.includes("whatsapp")
            )
                feature =
                    "whatsapp";

            if (
                feature &&
                !hasPermission(
                    feature,
                    "view"
                )
            ) {

                button.style.display =
                    "none";
            }
        });


        window.storemanAuth = {

            user:
                currentUser,

            profile:
                currentProfile,

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
            .eq(
                "id",
                currentUser.id
            );
    }


    async function recordActivity(
        action,
        tableName,
        recordId,
        details
    ) {

        if (
            !sb ||
            !currentUser
        )
            return;

        const companyId =
            currentProfile?.company_id;

        if (!companyId)
            return;

        try {

            await sb
                .from("activity_logs")
                .insert([{

                    user_id:
                        currentUser.id,

                    company_id:
                        companyId,

                    action,

                    table_name:
                        tableName ||
                        null,

                    record_id:
                        recordId ||
                        null,

                    details:
                        details ||
                        {
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

        panel.style.display =
            "block";

        await loadAdminCompany();

        await loadUsers();

        await loadActivity();
    }


    async function loadAdminCompany() {

        if (
            !currentProfile?.company_id
        )
            return;

        const result =
            await sb
                .from("companies")
                .select("name")
                .eq(
                    "id",
                    currentProfile.company_id
                )
                .maybeSingle();

        if (
            result.data &&
            $("admin-company-name")
        ) {

            $("admin-company-name")
                .textContent =
                result.data.name;
        }
    }


    async function refreshAdmin() {

        if (!isAdmin())
            return;

        notify(
            "Refreshing admin panel..."
        );

        await loadAdminCompany();

        await loadUsers();

        await loadActivity();

        notify(
            "Admin panel refreshed."
        );
    }


    async function loadUsers() {

        const box =
            $("admin-users");

        if (!box)
            return;

        box.innerHTML =
            "Loading users...";

        const result =
            await sb
                .from("profiles")
                .select(
                    "id,full_name,email,role,status,company_id,warehouse_id,permissions,last_login_at,last_seen_at"
                )
                .order(
                    "last_seen_at",
                    {
                        ascending:false
                    }
                );

        if (result.error) {

            box.textContent =
                result.error.message;

            return;
        }

        if (
            !result.data ||
            !result.data.length
        ) {

            box.textContent =
                "No users found.";

            return;
        }

        box.innerHTML =
            result.data.map(
                renderUser
            ).join("");
    }


    function renderUser(u) {

        const blocked =
            String(
                u.status ||
                "active"
            ).toLowerCase()
            !== "active";

        const isMe =
            u.id ===
            currentUser.id;

        const statusClass =
            blocked
            ? "status-blocked"
            : "status-active";

        const statusText =
            blocked
            ? "Blocked"
            : "Active";

        return `

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
                ${esc(
                    u.email || ""
                )}
            </small>

            <br>

            <small>
                Role:
                <b>
                    ${esc(
                        u.role ||
                        "user"
                    )}
                </b>
                —
                Status:
                <span
                    class="${statusClass}"
                >
                    ${statusText}
                </span>
            </small>

            <br>

            <small>
                Company:
                ${esc(
                    u.company_id ||
                    "None"
                )}
            </small>

            <br>

            <small>
                Warehouse:
                ${esc(
                    u.warehouse_id ||
                    "None"
                )}
            </small>

            <br>

            <small>
                Last login:
                ${esc(
                    u.last_login_at ||
                    "Never"
                )}
            </small>

            <br>

            <small>
                Last seen:
                ${esc(
                    u.last_seen_at ||
                    "Never"
                )}
            </small>

            <br>

            ${
                isMe

                ? `

                    <button
                        class="user-edit-button"
                        onclick="
                            window.StoremanAdminEditUser(
                                '${u.id}'
                            )
                        "
                    >
                        🔑 Manage My Profile
                    </button>

                    <br>

                    <small>
                        Current Admin
                    </small>

                `

                : `

                    <button
                        class="user-edit-button"
                        onclick="
                            window.StoremanAdminEditUser(
                                '${u.id}'
                            )
                        "
                    >
                        🔑 Manage User
                    </button>

                    <button
                        class="${
                            blocked
                            ? "unblock-button"
                            : "block-button"
                        }"
                        onclick="
                            window.StoremanAdminToggleUser(
                                '${u.id}',
                                '${
                                    blocked
                                    ? "active"
                                    : "blocked"
                                }'
                            )
                        "
                    >
                        ${
                            blocked
                            ? "✅ Unblock User"
                            : "🚫 Block User"
                        }
                    </button>

                `
            }

        </div>

        `;
    }


    async function loadActivity() {

        const box =
            $("admin-activity");

        if (!box)
            return;

        box.innerHTML =
            "Loading activity...";

        const result =
            await sb
                .from("activity_logs")
                .select(
                    "action,table_name,created_at,user_id,details"
                )
                .order(
                    "created_at",
                    {
                        ascending:false
                    }
                )
                .limit(100);

        if (result.error) {

            box.textContent =
                result.error.message;

            return;
        }

        if (
            !result.data ||
            !result.data.length
        ) {

            box.textContent =
                "No activity yet.";

            return;
        }

        box.innerHTML =
            result.data.map(
                a => `

                <div class="admin-user">

                    <b>
                        ${esc(
                            a.action
                        )}
                    </b>

                    <br>

                    <small>
                        Table:
                        ${esc(
                            a.table_name ||
                            ""
                        )}
                    </small>

                    <br>

                    <small>
                        User:
                        ${esc(
                            a.user_id ||
                            ""
                        )}
                    </small>

                    <br>

                    <small>
                        ${esc(
                            a.created_at ||
                            ""
                        )}
                    </small>

                </div>

                `
            ).join("");
    }


    async function loadCompanies() {

        const select =
            $("edit-user-company");

        if (!select)
            return;

        const result =
            await sb
                .from("companies")
                .select(
                    "id,name"
                )
                .order(
                    "name"
                );

        if (result.error)
            throw result.error;

        select.innerHTML = `

            <option value="">
                Select company
            </option>

            ${
                (result.data || [])
                .map(
                    c => `

                    <option
                        value="${esc(c.id)}"
                    >
                        ${esc(c.name)}
                    </option>

                    `
                )
                .join("")
            }

        `;
    }


    async function loadWarehouses(
        companyId,
        selectedId
    ) {

        const select =
            $("edit-user-warehouse");

        if (!select)
            return;

        select.innerHTML = `

            <option value="">
                No warehouse
            </option>

        `;

        if (!companyId)
            return;

        const result =
            await sb
                .from("warehouses")
                .select(
                    "id,name,company_id"
                )
                .eq(
                    "company_id",
                    companyId
                )
                .order(
                    "name"
                );

        if (result.error)
            throw result.error;

        select.innerHTML +=
            (result.data || [])
            .map(
                w => `

                <option
                    value="${esc(w.id)}"
                    ${
                        w.id === selectedId
                        ? "selected"
                        : ""
                    }
                >
                    ${esc(w.name)}
                </option>

                `
            )
            .join("");
    }


    function renderPermissions(
        permissions
    ) {

        const box =
            $("edit-user-permissions");

        if (!box)
            return;

        permissions =
            permissions ||
            {};

        box.innerHTML =
            FEATURES.map(
                feature => {

                    const fp =
                        permissions[
                            feature
                        ] || {};

                    return `

                    <div
                        class="permission-item"
                    >

                        <strong>
                            ${esc(feature)}
                        </strong>

                        ${ACTIONS.map(
                            action => `

                            <label>

                                <input
                                    type="checkbox"
                                    data-feature="${esc(feature)}"
                                    data-action="${esc(action)}"
                                    ${
                                        fp[action]
                                        ? "checked"
                                        : ""
                                    }
                                >

                                ${esc(action)}

                            </label>

                            `
                        ).join("")}

                    </div>

                    `;

                }
            ).join("");
    }


    async function openUserModal(
        userId
    ) {

        if (!isAdmin()) {

            notify(
                "Admin permission required.",
                true
            );

            return;
        }

        const result =
            await sb
                .from("profiles")
                .select(
                    "id,email,role,status,company_id,warehouse_id,permissions"
                )
                .eq(
                    "id",
                    userId
                )
                .maybeSingle();

        if (result.error) {

            notify(
                result.error.message,
                true
            );

            return;
        }

        if (!result.data) {

            notify(
                "User profile not found.",
                true
            );

            return;
        }

        const user =
            result.data;

        $("edit-user-id")
            .value =
            user.id;

        $("edit-user-email")
            .value =
            user.email ||
            "";

        $("edit-user-role")
            .value =
            user.role ||
            "user";

        $("edit-user-status")
            .value =
            user.status ||
            "active";

        await loadCompanies();

        $("edit-user-company")
            .value =
            user.company_id ||
            "";

        await loadWarehouses(
            user.company_id,
            user.warehouse_id
        );

        renderPermissions(
            user.permissions
        );

        $("user-edit-message")
            .textContent =
            "";

        $("storeman-user-modal")
            .style.display =
            "flex";
    }


    function closeUserModal() {

        const modal =
            $("storeman-user-modal");

        if (modal)
            modal.style.display =
                "none";
    }


    async function saveUserChanges() {

        if (!isAdmin()) {

            notify(
                "Admin permission required.",
                true
            );

            return;
        }

        const userId =
            $("edit-user-id")
                .value;

        if (!userId)
            return;

        const role =
            $("edit-user-role")
                .value;

        const status =
            $("edit-user-status")
                .value;

        const companyId =
            $("edit-user-company")
                .value ||
            null;

        const warehouseId =
            $("edit-user-warehouse")
                .value ||
            null;

        const permissions = {};

        document
            .querySelectorAll(
                "#edit-user-permissions input[type=checkbox]"
            )
            .forEach(
                checkbox => {

                    const feature =
                        checkbox.dataset.feature;

                    const action =
                        checkbox.dataset.action;

                    if (!permissions[feature])
                        permissions[feature] = {};

                    permissions[
                        feature
                    ][action] =
                        checkbox.checked;
                }
            );

        const message =
            $("user-edit-message");

        message.textContent =
            "Saving...";

        try {

            /*
             * Prevent removing company while assigning warehouse.
             */

            const finalWarehouseId =
                companyId
                ? warehouseId
                : null;


            const update =
                await sb
                    .from("profiles")
                    .update({

                        role,

                        status,

                        company_id:
                            companyId,

                        warehouse_id:
                            finalWarehouseId,

                        permissions

                    })
                    .eq(
                        "id",
                        userId
                    );

            if (update.error)
                throw update.error;


            await recordActivity(
                "UPDATE_USER",
                "profiles",
                userId,
                {
                    source:
                        "storeman-admin",

                    role,

                    status,

                    company_id:
                        companyId,

                    warehouse_id:
                        finalWarehouseId
                }
            );


            message.textContent =
                "User updated successfully.";

            message.style.color =
                "#16803c";


            notify(
                "User updated successfully."
            );


            closeUserModal();

            await loadUsers();

            await loadActivity();


            /*
             * If admin edited own profile,
             * reload local profile.
             */

            if (
                userId ===
                currentUser.id
            ) {

                await loadProfile();

                applyPermissions();
            }

        } catch (error) {

            console.error(error);

            message.textContent =
                error.message ||
                "Failed to update user.";

            message.style.color =
                "#c62828";

            notify(
                error.message ||
                "Failed to update user.",
                true
            );
        }
    }


    async function toggleUser(
        userId,
        newStatus
    ) {

        if (!isAdmin()) {

            notify(
                "Admin permission required.",
                true
            );

            return;
        }

        if (
            userId ===
            currentUser.id
        ) {

            notify(
                "You cannot block your own account.",
                true
            );

            return;
        }

        const action =
            newStatus === "blocked"
            ? "Block"
            : "Unblock";

        if (
            !confirm(
                `${action} this user?`
            )
        )
            return;

        try {

            const result =
                await sb
                    .from("profiles")
                    .update({
                        status:
                            newStatus
                    })
                    .eq(
                        "id",
                        userId
                    );

            if (result.error)
                throw result.error;


            await recordActivity(
                newStatus === "blocked"
                ? "BLOCK_USER"
                : "UNBLOCK_USER",
                "profiles",
                userId,
                {
                    source:
                        "storeman-admin",

                    status:
                        newStatus
                }
            );


            notify(
                newStatus === "blocked"
                ? "User blocked."
                : "User unblocked."
            );


            await loadUsers();

            await loadActivity();

        } catch (error) {

            console.error(error);

            notify(
                error.message ||
                "Failed to update user status.",
                true
            );
        }
    }


    window.StoremanAdminEditUser =
        openUserModal;

    window.StoremanAdminToggleUser =
        toggleUser;


    async function boot() {

        createAuthScreen();

        installStyles();

        if (
            !(await initSupabase())
        )
            return;


        /*
         * Persistent login:
         * Supabase automatically restores the
         * existing session from browser storage.
         */

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

                    await showAdminIfNeeded();

                    await setLastSeen();

                } else {

                    await sb.auth.signOut();

                    showLogin();
                }

            } catch (error) {

                console.warn(
                    "Session restore failed:",
                    error
                );

                showLogin();
            }

        } else {

            showLogin();
        }


        /*
         * Auth state listener
         */

        sb.auth.onAuthStateChange(
            async function (event) {

                if (
                    event ===
                    "SIGNED_OUT"
                ) {

                    currentUser =
                        null;

                    currentProfile =
                        null;

                    showLogin();

                    return;
                }


                if (
                    event ===
                    "SIGNED_IN"
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

                            await showAdminIfNeeded();

                            await setLastSeen();

                        } else {

                            await sb.auth
                                .signOut();

                            showLogin();
                        }

                    } catch (error) {

                        console.error(
                            error
                        );
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
