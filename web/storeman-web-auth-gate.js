(function () {
    "use strict";

    /*
     * STOREMAN WEB AUTH-FIRST MASTER
     *
     * LINK
     *   ↓
     * SIGN IN / SIGN UP
     *   ↓
     * SUPABASE AUTH
     *   ↓
     * PROFILE
     *   ↓
     * PENDING / ACTIVE
     *   ↓
     * DASHBOARD
     *
     * IMPORTANT:
     * Login form is shown immediately.
     * Network/session checks never block the form forever.
     */

    const APP_NAME = "Storeman ERP";

    let client = null;
    let currentUser = null;
    let currentProfile = null;
    let authReady = false;

    const TIMEOUT = 8000;

    // --------------------------------------------------------
    // TIMEOUT HELPER
    // --------------------------------------------------------

    function timeoutPromise(promise, ms, message) {

        return Promise.race([
            promise,

            new Promise(function (_, reject) {
                setTimeout(function () {
                    reject(new Error(message));
                }, ms);
            })
        ]);

    }

    // --------------------------------------------------------
    // SUPABASE CLIENT
    // --------------------------------------------------------

    function findSupabase() {

        const candidates = [
            window.supabaseClient,
            window.storemanSupabase,
            window.SUPABASE_CLIENT
        ];

        for (const item of candidates) {

            if (
                item &&
                item.auth &&
                typeof item.auth.getSession === "function"
            ) {
                return item;
            }
        }

        return null;
    }

    // --------------------------------------------------------
    // CSS
    // --------------------------------------------------------

    function injectCSS() {

        if (
            document.getElementById(
                "storeman-auth-first-css"
            )
        ) {
            return;
        }

        const style = document.createElement("style");

        style.id = "storeman-auth-first-css";

        style.textContent = `

        html.storeman-auth-lock,
        html.storeman-auth-lock body {
            overflow: hidden !important;
        }

        #storeman-auth-gate {

            position: fixed;
            inset: 0;

            z-index: 2147483647;

            display: flex;

            align-items: center;
            justify-content: center;

            padding: 18px;

            overflow-y: auto;

            background:
                radial-gradient(
                    circle at top left,
                    #eef4ff 0%,
                    #f8fafc 50%,
                    #eef2f7 100%
                );
        }

        #storeman-auth-gate * {
            box-sizing: border-box;
            font-family:
                Inter,
                system-ui,
                -apple-system,
                BlinkMacSystemFont,
                "Segoe UI",
                sans-serif;
        }

        .storeman-auth-card {

            width: min(440px, 100%);

            background: white;

            border-radius: 24px;

            padding: 28px 22px 24px;

            box-shadow:
                0 25px 70px rgba(15,23,42,.16),
                0 5px 20px rgba(15,23,42,.08);

            text-align: center;
        }

        .storeman-auth-logo {
            font-size: 60px;
            line-height: 1;
            margin-bottom: 10px;
        }

        .storeman-auth-title {

            margin: 0;

            color: #102a43;

            font-size: 31px;

            font-weight: 800;
        }

        .storeman-auth-subtitle {

            margin: 8px 0 20px;

            color: #64748b;

            font-size: 17px;
        }

        .storeman-auth-form {

            display: flex;

            flex-direction: column;

            gap: 10px;

            text-align: left;
        }

        .storeman-auth-form label {

            color: #334155;

            font-size: 14px;

            font-weight: 700;
        }

        .storeman-auth-form input {

            width: 100%;

            min-height: 52px;

            border:
                1px solid #cbd5e1;

            border-radius: 12px;

            padding: 0 15px;

            font-size: 16px;

            outline: none;

            background: white;
        }

        .storeman-auth-form input:focus {

            border-color: #24459b;

            box-shadow:
                0 0 0 3px
                rgba(36,69,155,.12);
        }

        .storeman-auth-button {

            width: 100%;

            min-height: 52px;

            border: 0;

            border-radius: 12px;

            background: #24459b;

            color: white;

            font-size: 17px;

            font-weight: 800;

            cursor: pointer;

            margin-top: 4px;
        }

        .storeman-auth-button:disabled {

            opacity: .6;

            cursor: wait;
        }

        .storeman-auth-link {

            border: 0;

            background: transparent;

            color: #24459b;

            font-size: 15px;

            font-weight: 700;

            cursor: pointer;

            padding: 10px;
        }

        .storeman-auth-message {

            display: none;

            border-radius: 12px;

            padding: 12px;

            margin-bottom: 12px;

            font-size: 14px;

            line-height: 1.5;

            text-align: left;
        }

        .storeman-auth-message.error {

            display: block;

            background: #fef2f2;

            color: #991b1b;
        }

        .storeman-auth-message.info {

            display: block;

            background: #eff6ff;

            color: #1e40af;
        }

        .storeman-auth-message.success {

            display: block;

            background: #f0fdf4;

            color: #166534;
        }

        .storeman-auth-hidden {

            display: none !important;
        }

        .storeman-pending-icon {

            font-size: 64px;

            margin-bottom: 10px;
        }

        `;

        document.head.appendChild(style);
    }

    // --------------------------------------------------------
    // CREATE AUTH SCREEN
    // --------------------------------------------------------

    function createGate() {

        let gate =
            document.getElementById(
                "storeman-auth-gate"
            );

        if (gate) return gate;

        document.documentElement.classList.add(
            "storeman-auth-lock"
        );

        gate = document.createElement("div");

        gate.id = "storeman-auth-gate";

        gate.innerHTML = `

            <div class="storeman-auth-card">

                <div class="storeman-auth-logo">
                    🔐
                </div>

                <h1 class="storeman-auth-title">
                    ${APP_NAME}
                </h1>

                <p
                    id="storeman-auth-subtitle"
                    class="storeman-auth-subtitle">
                    Sign In
                </p>

                <div
                    id="storeman-auth-message"
                    class="storeman-auth-message">
                </div>

                <form
                    id="storeman-signin-form"
                    class="storeman-auth-form">

                    <label>Email</label>

                    <input
                        id="storeman-login-email"
                        type="email"
                        autocomplete="email"
                        placeholder="Email"
                        required
                    >

                    <label>Password</label>

                    <input
                        id="storeman-login-password"
                        type="password"
                        autocomplete="current-password"
                        placeholder="Password"
                        required
                    >

                    <button
                        id="storeman-signin-button"
                        class="storeman-auth-button"
                        type="submit">
                        Sign In
                    </button>

                    <button
                        id="storeman-show-signup"
                        class="storeman-auth-link"
                        type="button">
                        Don't have an account? Sign Up
                    </button>

                </form>

                <form
                    id="storeman-signup-form"
                    class="storeman-auth-form storeman-auth-hidden">

                    <label>Full Name</label>

                    <input
                        id="storeman-signup-name"
                        type="text"
                        autocomplete="name"
                        placeholder="Full Name"
                        required
                    >

                    <label>Email</label>

                    <input
                        id="storeman-signup-email"
                        type="email"
                        autocomplete="email"
                        placeholder="Email"
                        required
                    >

                    <label>Password</label>

                    <input
                        id="storeman-signup-password"
                        type="password"
                        autocomplete="new-password"
                        placeholder="Password"
                        minlength="6"
                        required
                    >

                    <button
                        id="storeman-signup-button"
                        class="storeman-auth-button"
                        type="submit">
                        Sign Up
                    </button>

                    <button
                        id="storeman-show-signin"
                        class="storeman-auth-link"
                        type="button">
                        Already have an account? Sign In
                    </button>

                </form>

            </div>
        `;

        document.body.appendChild(gate);

        return gate;
    }

    // --------------------------------------------------------
    // MESSAGE
    // --------------------------------------------------------

    function message(text, type) {

        const box =
            document.getElementById(
                "storeman-auth-message"
            );

        if (!box) return;

        box.textContent = text || "";

        box.className =
            "storeman-auth-message " +
            (type || "info");
    }

    // --------------------------------------------------------
    // SHOW SIGN IN
    // --------------------------------------------------------

    function showSignIn() {

        const signin =
            document.getElementById(
                "storeman-signin-form"
            );

        const signup =
            document.getElementById(
                "storeman-signup-form"
            );

        const subtitle =
            document.getElementById(
                "storeman-auth-subtitle"
            );

        if (signin)
            signin.classList.remove(
                "storeman-auth-hidden"
            );

        if (signup)
            signup.classList.add(
                "storeman-auth-hidden"
            );

        if (subtitle)
            subtitle.textContent = "Sign In";
    }

    // --------------------------------------------------------
    // SHOW SIGN UP
    // --------------------------------------------------------

    function showSignUp() {

        const signin =
            document.getElementById(
                "storeman-signin-form"
            );

        const signup =
            document.getElementById(
                "storeman-signup-form"
            );

        const subtitle =
            document.getElementById(
                "storeman-auth-subtitle"
            );

        if (signin)
            signin.classList.add(
                "storeman-auth-hidden"
            );

        if (signup)
            signup.classList.remove(
                "storeman-auth-hidden"
            );

        if (subtitle)
            subtitle.textContent = "Sign Up";

        message("", "info");
    }

    // --------------------------------------------------------
    // PROFILE
    // --------------------------------------------------------

    async function getProfile(userId) {

        if (!client || !userId) {
            return null;
        }

        const result =
            await timeoutPromise(
                client
                    .from("profiles")
                    .select("*")
                    .eq("id", userId)
                    .maybeSingle(),

                TIMEOUT,

                "Profile request timed out."
            );

        if (result.error) {
            throw result.error;
        }

        return result.data || null;
    }

    // --------------------------------------------------------
    // ADMIN CHECK
    // --------------------------------------------------------

    function isAdmin(profile) {

        if (!profile) return false;

        return (
            String(profile.status || "")
                .toLowerCase() === "active"
            &&
            ["admin", "owner"].includes(
                String(profile.role || "")
                    .toLowerCase()
            )
        );
    }

    // --------------------------------------------------------
    // ADMIN UI
    // --------------------------------------------------------

    function applyPermissions(profile) {

        const admin = isAdmin(profile);

        document.body.dataset.storemanAdmin =
            admin ? "true" : "false";

        /*
         * Normal users must not see
         * Settings / User Management /
         * Manage Profile / Permissions.
         */

        if (!admin) {

            document
                .querySelectorAll(
                    ".btn-settings," +
                    "[data-admin-only]," +
                    ".admin-only," +
                    "[data-feature='users']," +
                    "[data-feature='permissions']," +
                    "[data-feature='user-management']," +
                    "[data-feature='manage-profile']," +
                    "#manage-profile," +
                    "#manageProfile"
                )
                .forEach(function (el) {

                    el.style.display = "none";
                    el.setAttribute(
                        "aria-hidden",
                        "true"
                    );
                });

        }

    }

    // --------------------------------------------------------
    // PENDING
    // --------------------------------------------------------

    function showPending(text) {

        const gate =
            document.getElementById(
                "storeman-auth-gate"
            );

        if (!gate) return;

        gate.innerHTML = `

            <div class="storeman-auth-card">

                <div class="storeman-pending-icon">
                    ⏳
                </div>

                <h1 class="storeman-auth-title">
                    Account Pending
                </h1>

                <p class="storeman-auth-subtitle">
                    ${text}
                </p>

                <button
                    id="storeman-pending-signout"
                    class="storeman-auth-button">
                    Sign Out
                </button>

            </div>
        `;

        const btn =
            document.getElementById(
                "storeman-pending-signout"
            );

        if (btn) {

            btn.onclick = async function () {

                try {

                    if (client)
                        await client.auth.signOut();

                } catch (_) {}

                location.reload();
            };
        }
    }

    // --------------------------------------------------------
    // UNLOCK DASHBOARD
    // --------------------------------------------------------

    function unlock(profile) {

        currentProfile = profile;

        applyPermissions(profile);

        authReady = true;

        const gate =
            document.getElementById(
                "storeman-auth-gate"
            );

        if (gate)
            gate.remove();

        document.documentElement.classList.remove(
            "storeman-auth-lock"
        );

        window.dispatchEvent(
            new CustomEvent(
                "storeman:authenticated",
                {
                    detail: {
                        user: currentUser,
                        profile: currentProfile
                    }
                }
            )
        );

        console.log(
            "STOREMAN AUTH ACTIVE:",
            currentUser &&
            currentUser.email
        );
    }

    // --------------------------------------------------------
    // CHECK CURRENT SESSION
    // --------------------------------------------------------

    async function checkSession() {

        if (!client) {

            message(
                "Storeman is ready. Supabase connection could not be checked. You can still see the Sign In form and try again.",
                "error"
            );

            return;
        }

        try {

            const result =
                await timeoutPromise(
                    client.auth.getSession(),

                    TIMEOUT,

                    "Supabase session check timed out."
                );

            if (
                result.error ||
                !result.data ||
                !result.data.session
            ) {

                /*
                 * IMPORTANT:
                 * Never leave user on spinner.
                 */

                showSignIn();

                if (result.error) {

                    message(
                        "Please sign in. Supabase session check failed.",
                        "error"
                    );
                }

                return;
            }

            currentUser =
                result.data.session.user;

            const profile =
                await getProfile(
                    currentUser.id
                );

            if (!profile) {

                showPending(
                    "Your account exists, but your Storeman profile is not ready yet."
                );

                return;
            }

            const status =
                String(
                    profile.status || "pending"
                ).toLowerCase();

            if (status !== "active") {

                showPending(
                    status === "pending"
                        ? "Your account is waiting for administrator approval."
                        : "Your account is not active. Please contact the administrator."
                );

                return;
            }

            unlock(profile);

        } catch (error) {

            console.error(
                "Storeman auth check:",
                error
            );

            /*
             * CRITICAL:
             * Show Sign In instead of infinite spinner.
             */

            showSignIn();

            message(
                "Please sign in. Connection check timed out; the login form is ready.",
                "error"
            );
        }
    }

    // --------------------------------------------------------
    // SIGN IN
    // --------------------------------------------------------

    async function signIn(event) {

        if (event)
            event.preventDefault();

        if (!client) {

            message(
                "Supabase is not connected. Please check your internet connection.",
                "error"
            );

            return;
        }

        const email =
            document
                .getElementById(
                    "storeman-login-email"
                )
                .value
                .trim();

        const password =
            document
                .getElementById(
                    "storeman-login-password"
                )
                .value;

        if (!email || !password) {

            message(
                "Please enter your email and password.",
                "error"
            );

            return;
        }

        const button =
            document.getElementById(
                "storeman-signin-button"
            );

        if (button) {

            button.disabled = true;
            button.textContent =
                "Signing In...";
        }

        message(
            "Connecting to Storeman...",
            "info"
        );

        try {

            const result =
                await timeoutPromise(

                    client.auth
                        .signInWithPassword({
                            email,
                            password
                        }),

                    TIMEOUT,

                    "Sign in request timed out."
                );

            if (result.error) {

                message(
                    result.error.message ||
                    "Sign in failed.",
                    "error"
                );

                return;
            }

            currentUser =
                result.data.user;

            if (!currentUser) {

                message(
                    "Sign in completed but no user session was returned.",
                    "error"
                );

                return;
            }

            message(
                "Checking your Storeman account...",
                "info"
            );

            const profile =
                await getProfile(
                    currentUser.id
                );

            if (!profile) {

                showPending(
                    "Your account was created, but your Storeman profile is not ready yet."
                );

                return;
            }

            const status =
                String(
                    profile.status || "pending"
                ).toLowerCase();

            if (status !== "active") {

                showPending(
                    status === "pending"
                        ? "Your account is waiting for administrator approval."
                        : "Your account is not active. Please contact the administrator."
                );

                return;
            }

            unlock(profile);

        } catch (error) {

            console.error(
                "Storeman sign in:",
                error
            );

            message(
                error.message ||
                "Unable to connect to Storeman.",
                "error"
            );

        } finally {

            if (button) {

                button.disabled = false;
                button.textContent =
                    "Sign In";
            }
        }
    }

    // --------------------------------------------------------
    // SIGN UP
    // --------------------------------------------------------

    async function signUp(event) {

        if (event)
            event.preventDefault();

        if (!client) {

            message(
                "Supabase is not connected.",
                "error"
            );

            return;
        }

        const name =
            document
                .getElementById(
                    "storeman-signup-name"
                )
                .value
                .trim();

        const email =
            document
                .getElementById(
                    "storeman-signup-email"
                )
                .value
                .trim();

        const password =
            document
                .getElementById(
                    "storeman-signup-password"
                )
                .value;

        if (!name || !email || !password) {

            message(
                "Please complete all fields.",
                "error"
            );

            return;
        }

        const button =
            document.getElementById(
                "storeman-signup-button"
            );

        if (button) {

            button.disabled = true;
            button.textContent =
                "Creating Account...";
        }

        message(
            "Creating your Storeman account...",
            "info"
        );

        try {

            const result =
                await timeoutPromise(

                    client.auth.signUp({

                        email: email,

                        password: password,

                        options: {
                            data: {
                                full_name: name
                            }
                        }
                    }),

                    TIMEOUT,

                    "Sign up request timed out."
                );

            if (result.error) {

                message(
                    result.error.message ||
                    "Sign up failed.",
                    "error"
                );

                return;
            }

            /*
             * Email confirmation enabled:
             */

            if (!result.data.session) {

                message(
                    "Account created successfully. Please verify your email, then Sign In. Your account will remain pending until administrator approval.",
                    "success"
                );

                return;
            }

            currentUser =
                result.data.user;

            const profile =
                await getProfile(
                    currentUser.id
                );

            if (!profile) {

                showPending(
                    "Account created successfully. Your profile is waiting for administrator processing."
                );

                return;
            }

            if (
                String(
                    profile.status || "pending"
                ).toLowerCase() !== "active"
            ) {

                showPending(
                    "Account created successfully. Your account is waiting for administrator approval."
                );

                return;
            }

            unlock(profile);

        } catch (error) {

            console.error(
                "Storeman sign up:",
                error
            );

            message(
                error.message ||
                "Unable to create account.",
                "error"
            );

        } finally {

            if (button) {

                button.disabled = false;
                button.textContent =
                    "Sign Up";
            }
        }
    }

    // --------------------------------------------------------
    // AUTH STATE
    // --------------------------------------------------------

    function listenAuth() {

        if (!client) return;

        client.auth.onAuthStateChange(
            async function (event, session) {

                console.log(
                    "STOREMAN AUTH EVENT:",
                    event
                );

                if (
                    event === "SIGNED_OUT"
                ) {

                    authReady = false;

                    location.reload();

                    return;
                }

                if (
                    event === "SIGNED_IN" &&
                    session &&
                    session.user &&
                    !authReady
                ) {

                    currentUser =
                        session.user;

                    try {

                        const profile =
                            await getProfile(
                                currentUser.id
                            );

                        if (!profile) {

                            showPending(
                                "Your account is waiting for administrator processing."
                            );

                            return;
                        }

                        if (
                            String(
                                profile.status || ""
                            ).toLowerCase() !==
                            "active"
                        ) {

                            showPending(
                                "Your account is waiting for administrator approval."
                            );

                            return;
                        }

                        unlock(profile);

                    } catch (error) {

                        console.error(
                            error
                        );

                        showSignIn();

                        message(
                            "Your login succeeded, but your profile could not be loaded.",
                            "error"
                        );
                    }
                }
            }
        );
    }

    // --------------------------------------------------------
    // EVENTS
    // --------------------------------------------------------

    function attachEvents() {

        const signin =
            document.getElementById(
                "storeman-signin-form"
            );

        const signup =
            document.getElementById(
                "storeman-signup-form"
            );

        const showSignup =
            document.getElementById(
                "storeman-show-signup"
            );

        const showSignin =
            document.getElementById(
                "storeman-show-signin"
            );

        if (signin)
            signin.addEventListener(
                "submit",
                signIn
            );

        if (signup)
            signup.addEventListener(
                "submit",
                signUp
            );

        if (showSignup)
            showSignup.addEventListener(
                "click",
                showSignUp
            );

        if (showSignin)
            showSignin.addEventListener(
                "click",
                showSignIn
            );
    }

    // --------------------------------------------------------
    // BOOT
    // --------------------------------------------------------

    function boot() {

        injectCSS();

        createGate();

        /*
         * SHOW LOGIN IMMEDIATELY.
         *
         * This prevents the exact problem shown
         * in the screenshot.
         */

        showSignIn();

        attachEvents();

        client = findSupabase();

        if (!client) {

            message(
                "Supabase connection was not found. Please check the app connection.",
                "error"
            );

            return;
        }

        listenAuth();

        /*
         * Session check happens AFTER
         * Sign In screen is already visible.
         */

        checkSession();
    }

    // --------------------------------------------------------
    // PUBLIC API
    // --------------------------------------------------------

    window.StoremanWebAuth = {

        getUser: function () {
            return currentUser;
        },

        getProfile: function () {
            return currentProfile;
        },

        isAuthenticated: function () {
            return authReady;
        },

        signOut: async function () {

            try {

                if (client)
                    await client.auth.signOut();

            } catch (_) {}

            location.reload();
        }
    };

    // --------------------------------------------------------
    // START
    // --------------------------------------------------------

    if (
        document.readyState === "loading"
    ) {

        document.addEventListener(
            "DOMContentLoaded",
            boot
        );

    } else {

        boot();

    }

})();
