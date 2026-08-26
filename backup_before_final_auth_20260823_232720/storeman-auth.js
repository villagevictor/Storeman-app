(function () {
    "use strict";

    const SUPABASE_URL =
        "https://cfnrbgfczqfpmdjzzbia.supabase.co";

    const SUPABASE_KEY =
        "sb_publishable_AN3kSG6xIx38ThIMg4o28w_u6kPIrn2";

    let client = null;
    let currentUser = null;
    let currentProfile = null;

    function waitForSupabase() {
        return new Promise((resolve, reject) => {

            let tries = 0;

            const timer = setInterval(() => {

                if (window.supabase &&
                    typeof window.supabase.createClient === "function") {

                    clearInterval(timer);

                    try {
                        client = window.supabase.createClient(
                            SUPABASE_URL,
                            SUPABASE_KEY,
                            {
                                auth: {
                                    persistSession: true,
                                    autoRefreshToken: true,
                                    detectSessionInUrl: false
                                }
                            }
                        );

                        resolve(client);

                    } catch (e) {
                        clearInterval(timer);
                        reject(e);
                    }
                }

                tries++;

                if (tries > 100) {
                    clearInterval(timer);
                    reject(new Error("Supabase library timeout"));
                }

            }, 100);
        });
    }

    function escapeHtml(value) {
        return String(value || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    function createLoginUI() {

        if (document.getElementById("storeman-auth-screen")) {
            return;
        }

        const style = document.createElement("style");

        style.textContent = `
        #storeman-auth-screen {
            position: fixed;
            inset: 0;
            z-index: 999999;
            background: linear-gradient(135deg,#0f2b48,#163f68);
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            font-family: Arial,sans-serif;
        }

        #storeman-auth-card {
            width: 100%;
            max-width: 400px;
            background: white;
            border-radius: 16px;
            padding: 28px;
            box-shadow: 0 20px 60px rgba(0,0,0,.30);
        }

        #storeman-auth-card h2 {
            margin: 0 0 8px;
            color: #0f2b48;
            text-align: center;
        }

        #storeman-auth-card p {
            text-align: center;
            color: #666;
            margin-bottom: 22px;
        }

        #storeman-auth-card input {
            width: 100%;
            box-sizing: border-box;
            padding: 13px;
            margin-bottom: 12px;
            border: 1px solid #ddd;
            border-radius: 8px;
            font-size: 15px;
        }

        #storeman-auth-login {
            width: 100%;
            padding: 13px;
            border: 0;
            border-radius: 8px;
            background: #0f2b48;
            color: white;
            font-weight: bold;
            font-size: 15px;
        }

        #storeman-auth-message {
            margin-top: 14px;
            text-align: center;
            font-size: 14px;
            min-height: 20px;
        }

        #storeman-user-bar {
            position: fixed;
            top: 8px;
            right: 8px;
            z-index: 999998;
            background: #0f2b48;
            color: white;
            padding: 7px 10px;
            border-radius: 8px;
            font-size: 12px;
            display: none;
        }

        #storeman-logout {
            margin-left: 8px;
            border: 0;
            border-radius: 5px;
            padding: 4px 7px;
            cursor: pointer;
        }
        `;

        document.head.appendChild(style);

        const screen = document.createElement("div");

        screen.id = "storeman-auth-screen";

        screen.innerHTML = `
            <div id="storeman-auth-card">

                <h2>Storeman Inventory</h2>

                <p>Secure Login</p>

                <input
                    id="storeman-auth-email"
                    type="email"
                    autocomplete="username"
                    placeholder="Email"
                >

                <input
                    id="storeman-auth-password"
                    type="password"
                    autocomplete="current-password"
                    placeholder="Password"
                >

                <button id="storeman-auth-login">
                    🔐 Login
                </button>

                <div id="storeman-auth-message"></div>

            </div>
        `;

        document.body.appendChild(screen);

        document
            .getElementById("storeman-auth-login")
            .addEventListener("click", login);

        document
            .getElementById("storeman-auth-password")
            .addEventListener("keydown", function (e) {
                if (e.key === "Enter") login();
            });
    }

    function createUserBar() {

        if (document.getElementById("storeman-user-bar")) {
            return;
        }

        const bar = document.createElement("div");

        bar.id = "storeman-user-bar";

        bar.innerHTML = `
            <span id="storeman-user-name"></span>
            <button id="storeman-logout">Logout</button>
        `;

        document.body.appendChild(bar);

        document
            .getElementById("storeman-logout")
            .addEventListener("click", logout);
    }

    function message(text, ok) {

        const box =
            document.getElementById("storeman-auth-message");

        if (!box) return;

        box.textContent = text;

        box.style.color = ok ? "#16803c" : "#c62828";
    }

    async function getProfile(userId) {

        const { data, error } = await client
            .from("profiles")
            .select("*")
            .eq("id", userId)
            .maybeSingle();

        if (error) {
            throw error;
        }

        return data;
    }

    function featureAllowed(profile, feature, action) {

        if (!profile) return false;

        const role =
            String(profile.role || "").toLowerCase();

        if (role === "admin" || role === "owner") {
            return true;
        }

        const permissions =
            profile.permissions || {};

        const item =
            permissions[feature] || {};

        return item[action] === true;
    }

    async function login() {

        const email =
            document
                .getElementById("storeman-auth-email")
                .value
                .trim()
                .toLowerCase();

        const password =
            document
                .getElementById("storeman-auth-password")
                .value;

        if (!email || !password) {
            message("Email and password are required.", false);
            return;
        }

        message("Signing in...", true);

        try {

            const { data, error } =
                await client.auth.signInWithPassword({
                    email,
                    password
                });

            if (error) {
                throw error;
            }

            currentUser = data.user;

            currentProfile =
                await getProfile(currentUser.id);

            if (!currentProfile) {

                await client.auth.signOut();

                throw new Error(
                    "No Storeman profile is assigned to this account."
                );
            }

            if (currentProfile.status !== "active") {

                await client.auth.signOut();

                throw new Error(
                    "This user account is disabled."
                );
            }

            if (!currentProfile.company_id) {

                await client.auth.signOut();

                throw new Error(
                    "This user has no company assigned."
                );
            }

            localStorage.setItem(
                "storeman_auth_user",
                currentUser.id
            );

            localStorage.setItem(
                "storeman_company_id",
                currentProfile.company_id
            );

            showApplication();

            updateUserBar();

            await updateLastSeen();

        } catch (e) {

            console.error("Storeman Login:", e);

            message(
                e.message || "Login failed.",
                false
            );
        }
    }

    async function updateLastSeen() {

        if (!currentUser) return;

        try {

            await client
                .from("profiles")
                .update({
                    last_seen_at: new Date().toISOString(),
                    last_login_at: new Date().toISOString()
                })
                .eq("id", currentUser.id);

        } catch (e) {
            console.warn(
                "Could not update last seen:",
                e
            );
        }
    }

    async function logout() {

        try {
            await client.auth.signOut();
        } catch (e) {
            console.warn(e);
        }

        currentUser = null;
        currentProfile = null;

        localStorage.removeItem(
            "storeman_auth_user"
        );

        localStorage.removeItem(
            "storeman_company_id"
        );

        location.reload();
    }

    function showApplication() {

        const screen =
            document.getElementById(
                "storeman-auth-screen"
            );

        if (screen) {
            screen.remove();
        }

        document.body.style.visibility = "visible";
    }

    function hideApplication() {

        document.body.style.visibility = "hidden";

        createLoginUI();

        const screen =
            document.getElementById(
                "storeman-auth-screen"
            );

        if (screen) {
            screen.style.display = "flex";
        }
    }

    function updateUserBar() {

        createUserBar();

        const bar =
            document.getElementById(
                "storeman-user-bar"
            );

        const name =
            document.getElementById(
                "storeman-user-name"
            );

        if (!bar || !name) return;

        name.textContent =
            (
                currentUser.email +
                " • " +
                String(
                    currentProfile.role || "user"
                )
            );

        bar.style.display = "block";
    }

    async function restoreSession() {

        try {

            const { data } =
                await client.auth.getSession();

            const session = data.session;

            if (!session || !session.user) {
                hideApplication();
                return;
            }

            currentUser = session.user;

            currentProfile =
                await getProfile(currentUser.id);

            if (!currentProfile ||
                currentProfile.status !== "active" ||
                !currentProfile.company_id) {

                await client.auth.signOut();

                hideApplication();
                return;
            }

            showApplication();

            updateUserBar();

            await updateLastSeen();

        } catch (e) {

            console.error(
                "Session restore failed:",
                e
            );

            hideApplication();
        }
    }

    window.StoremanAuth = {

        getUser: function () {
            return currentUser;
        },

        getProfile: function () {
            return currentProfile;
        },

        getCompanyId: function () {
            return currentProfile
                ? currentProfile.company_id
                : null;
        },

        isAdmin: function () {

            if (!currentProfile) return false;

            const role =
                String(
                    currentProfile.role || ""
                ).toLowerCase();

            return role === "admin" ||
                   role === "owner";
        },

        can: featureAllowed,

        logout: logout,

        client: function () {
            return client;
        }
    };

    async function boot() {

        document.body.style.visibility = "hidden";

        try {

            await waitForSupabase();

            await restoreSession();

        } catch (e) {

            console.error(
                "Storeman Auth Boot Error:",
                e
            );

            document.body.style.visibility = "visible";

            alert(
                "Storeman authentication could not start. " +
                "Please check your internet connection."
            );
        }
    }

    if (document.readyState === "loading") {

        document.addEventListener(
            "DOMContentLoaded",
            boot
        );

    } else {
        boot();
    }

})();
