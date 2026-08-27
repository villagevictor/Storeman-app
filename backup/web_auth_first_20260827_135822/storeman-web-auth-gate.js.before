/*
 STOREMAN WEB AUTH-FIRST GATE
 ---------------------------------------------------------------
 Flow:

 LINK
   ↓
 AUTH CHECK
   ↓
 SIGN IN / SIGN UP
   ↓
 SUPABASE AUTH
   ↓
 PROFILE
   ↓
 pending / inactive
   ↓
 ADMIN APPROVAL
   ↓
 ACTIVE
   ↓
 DASHBOARD

 Dashboard is NEVER shown before authentication.
*/

(function () {
    "use strict";

    const APP_NAME = "Storeman ERP";

    let authReady = false;
    let currentUser = null;
    let currentProfile = null;

    // ---------------------------------------------------------
    // CSS
    // ---------------------------------------------------------

    const css = `
    html.storeman-auth-lock body {
        overflow: hidden !important;
    }

    #storeman-auth-gate {
        position: fixed;
        inset: 0;
        z-index: 2147483647;
        background:
            radial-gradient(circle at top left, #eef4ff 0%, #f8fafc 45%, #eef2f7 100%);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
        box-sizing: border-box;
        overflow-y: auto;
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
        width: min(430px, 100%);
        background: white;
        border-radius: 24px;
        padding: 30px 24px 24px;
        box-shadow:
            0 25px 70px rgba(15,23,42,.16),
            0 5px 20px rgba(15,23,42,.08);
        text-align: center;
    }

    .storeman-auth-logo {
        font-size: 62px;
        line-height: 1;
        margin-bottom: 12px;
    }

    .storeman-auth-title {
        margin: 0;
        color: #102a43;
        font-size: 32px;
        font-weight: 800;
    }

    .storeman-auth-subtitle {
        margin: 8px 0 22px;
        color: #64748b;
        font-size: 17px;
    }

    .storeman-auth-form {
        display: flex;
        flex-direction: column;
        gap: 12px;
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
        border: 1px solid #cbd5e1;
        border-radius: 12px;
        padding: 0 15px;
        font-size: 16px;
        outline: none;
        background: #fff;
    }

    .storeman-auth-form input:focus {
        border-color: #24459b;
        box-shadow: 0 0 0 3px rgba(36,69,155,.12);
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

    .storeman-auth-secondary {
        background: #eef2ff;
        color: #24459b;
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
        margin-bottom: 12px;
    }

    .storeman-spinner {
        width: 36px;
        height: 36px;
        border: 4px solid #e2e8f0;
        border-top-color: #24459b;
        border-radius: 50%;
        animation: storeman-spin .8s linear infinite;
        margin: 15px auto;
    }

    @keyframes storeman-spin {
        to { transform: rotate(360deg); }
    }

    @media (max-width: 480px) {
        .storeman-auth-card {
            border-radius: 20px;
            padding: 25px 18px 20px;
        }

        .storeman-auth-title {
            font-size: 28px;
        }
    }
    `;

    function injectCSS() {
        if (document.getElementById("storeman-auth-gate-css")) return;

        const style = document.createElement("style");
        style.id = "storeman-auth-gate-css";
        style.textContent = css;
        document.head.appendChild(style);
    }

    // ---------------------------------------------------------
    // SUPABASE CLIENT DISCOVERY
    // ---------------------------------------------------------

    function getSupabaseClient() {

        const candidates = [
            window.supabaseClient,
            window.supabase,
            window.storemanSupabase,
            window.SUPABASE_CLIENT
        ];

        for (const candidate of candidates) {
            if (
                candidate &&
                candidate.auth &&
                typeof candidate.auth.getSession === "function"
            ) {
                return candidate;
            }
        }

        // Search common globals without assuming a specific name.
        for (const key of Object.keys(window)) {
            try {
                const value = window[key];

                if (
                    value &&
                    value.auth &&
                    typeof value.auth.getSession === "function" &&
                    typeof value.auth.signInWithPassword === "function"
                ) {
                    return value;
                }
            } catch (_) {}
        }

        return null;
    }

    // ---------------------------------------------------------
    // CREATE GATE
    // ---------------------------------------------------------

    function createGate() {

        if (document.getElementById("storeman-auth-gate")) {
            return document.getElementById("storeman-auth-gate");
        }

        document.documentElement.classList.add("storeman-auth-lock");

        const gate = document.createElement("div");
        gate.id = "storeman-auth-gate";

        gate.innerHTML = `
            <div class="storeman-auth-card">

                <div id="storeman-auth-content">

                    <div class="storeman-auth-logo">🔐</div>

                    <h1 class="storeman-auth-title">
                        ${APP_NAME}
                    </h1>

                    <p class="storeman-auth-subtitle">
                        Secure access
                    </p>

                    <div id="storeman-auth-message"
                         class="storeman-auth-message">
                    </div>

                    <form id="storeman-signin-form"
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

                    <form id="storeman-signup-form"
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

            </div>
        `;

        document.body.appendChild(gate);

        return gate;
    }

    // ---------------------------------------------------------
    // MESSAGE
    // ---------------------------------------------------------

    function showMessage(text, type) {

        const box = document.getElementById("storeman-auth-message");

        if (!box) return;

        box.textContent = text || "";
        box.className =
            "storeman-auth-message " +
            (type || "info");
    }

    // ---------------------------------------------------------
    // LOADING
    // ---------------------------------------------------------

    function showLoading(text) {

        const content =
            document.getElementById("storeman-auth-content");

        if (!content) return;

        content.innerHTML = `
            <div class="storeman-auth-logo">🔐</div>

            <h1 class="storeman-auth-title">
                ${APP_NAME}
            </h1>

            <div class="storeman-spinner"></div>

            <p class="storeman-auth-subtitle">
                ${text || "Checking secure access..."}
            </p>
        `;
    }

    // ---------------------------------------------------------
    // SIGN IN
    // ---------------------------------------------------------

    async function signIn() {

        const client = getSupabaseClient();

        if (!client) {
            showMessage(
                "Supabase is not connected. Please check the Supabase URL, anon key, and internet connection.",
                "error"
            );
            return;
        }

        const email =
            document.getElementById("storeman-login-email").value.trim();

        const password =
            document.getElementById("storeman-login-password").value;

        if (!email || !password) {
            showMessage(
                "Please enter your email and password.",
                "error"
            );
            return;
        }

        showMessage("Signing in...", "info");

        const { data, error } =
            await client.auth.signInWithPassword({
                email,
                password
            });

        if (error) {

            showMessage(
                error.message || "Sign in failed.",
                "error"
            );

            return;
        }

        currentUser = data.user;

        await checkProfile(currentUser);

    }

    // ---------------------------------------------------------
    // SIGN UP
    // ---------------------------------------------------------

    async function signUp() {

        const client = getSupabaseClient();

        if (!client) {
            showMessage(
                "Supabase is not connected. Please check the Supabase configuration.",
                "error"
            );
            return;
        }

        const name =
            document.getElementById("storeman-signup-name").value.trim();

        const email =
            document.getElementById("storeman-signup-email").value.trim();

        const password =
            document.getElementById("storeman-signup-password").value;

        if (!name || !email || !password) {
            showMessage(
                "Please complete all fields.",
                "error"
            );
            return;
        }

        showMessage("Creating your account...", "info");

        const { data, error } =
            await client.auth.signUp({
                email,
                password,
                options: {
                    data: {
                        full_name: name
                    }
                }
            });

        if (error) {

            showMessage(
                error.message || "Sign up failed.",
                "error"
            );

            return;
        }

        /*
         * Depending on Supabase email confirmation settings,
         * session may be null after signup.
         */

        if (!data.session) {

            showMessage(
                "Account created successfully. Please verify your email, then Sign In. Your account will remain pending until an administrator approves it.",
                "success"
            );

            return;
        }

        currentUser = data.user;

        await checkProfile(currentUser);
    }

    // ---------------------------------------------------------
    // PROFILE CHECK
    // ---------------------------------------------------------

    async function checkProfile(user) {

        const client = getSupabaseClient();

        if (!client || !user) {
            showLogin();
            return;
        }

        showLoading("Checking your account...");

        try {

            const { data: profile, error } =
                await client
                    .from("profiles")
                    .select("*")
                    .eq("id", user.id)
                    .maybeSingle();

            if (error) {

                console.error(
                    "Storeman profile error:",
                    error
                );

                showMessage(
                    "Your login succeeded, but your Storeman profile could not be loaded. Please contact the administrator.",
                    "error"
                );

                return;
            }

            if (!profile) {

                showPending(
                    "Your account was created, but your Storeman profile has not been created yet."
                );

                return;
            }

            currentProfile = profile;

            const status =
                String(profile.status || "pending")
                    .toLowerCase();

            if (status !== "active") {

                showPending(
                    status === "pending"
                        ? "Your account is waiting for administrator approval."
                        : "Your account is not active. Please contact the administrator."
                );

                return;
            }

            // ------------------------------------------------
            // ACTIVE USER
            // ------------------------------------------------

            unlockDashboard();

        } catch (err) {

            console.error(err);

            showMessage(
                "Unable to connect to Storeman. Please check your internet connection and Supabase configuration.",
                "error"
            );
        }
    }

    // ---------------------------------------------------------
    // PENDING
    // ---------------------------------------------------------

    function showPending(message) {

        const content =
            document.getElementById("storeman-auth-content");

        if (!content) return;

        content.innerHTML = `

            <div class="storeman-pending-icon">
                ⏳
            </div>

            <h1 class="storeman-auth-title">
                Account Pending
            </h1>

            <p class="storeman-auth-subtitle">
                ${message}
            </p>

            <button
                id="storeman-pending-signout"
                class="storeman-auth-button">
                Sign Out
            </button>
        `;

        document
            .getElementById("storeman-pending-signout")
            .addEventListener("click", signOut);
    }

    // ---------------------------------------------------------
    // SIGN OUT
    // ---------------------------------------------------------

    async function signOut() {

        const client = getSupabaseClient();

        if (client && client.auth) {

            try {
                await client.auth.signOut();
            } catch (err) {
                console.error(err);
            }
        }

        currentUser = null;
        currentProfile = null;

        location.reload();
    }

    // ---------------------------------------------------------
    // SHOW LOGIN
    // ---------------------------------------------------------

    function showLogin() {

        const gate =
            document.getElementById("storeman-auth-gate");

        if (!gate) return;

        gate.style.display = "flex";

        document.documentElement
            .classList.add("storeman-auth-lock");

        const signin =
            document.getElementById("storeman-signin-form");

        const signup =
            document.getElementById("storeman-signup-form");

        if (signin) {
            signin.classList.remove("storeman-auth-hidden");
        }

        if (signup) {
            signup.classList.add("storeman-auth-hidden");
        }

        const title =
            document.querySelector(".storeman-auth-title");

        if (title) {
            title.textContent = APP_NAME;
        }

        const subtitle =
            document.querySelector(".storeman-auth-subtitle");

        if (subtitle) {
            subtitle.textContent = "Sign In";
        }
    }

    // ---------------------------------------------------------
    // UNLOCK DASHBOARD
    // ---------------------------------------------------------

    function unlockDashboard() {

        authReady = true;

        const gate =
            document.getElementById("storeman-auth-gate");

        if (gate) {
            gate.remove();
        }

        document.documentElement
            .classList.remove("storeman-auth-lock");

        /*
         * Give existing Storeman application code time to
         * initialize after authentication.
         */

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
            "STOREMAN AUTH:",
            "ACTIVE USER",
            currentUser?.email
        );
    }

    // ---------------------------------------------------------
    // FORM EVENTS
    // ---------------------------------------------------------

    function attachEvents() {

        const signin =
            document.getElementById("storeman-signin-form");

        const signup =
            document.getElementById("storeman-signup-form");

        const showSignup =
            document.getElementById("storeman-show-signup");

        const showSignin =
            document.getElementById("storeman-show-signin");

        if (signin) {

            signin.addEventListener(
                "submit",
                async function (event) {

                    event.preventDefault();

                    await signIn();

                }
            );
        }

        if (signup) {

            signup.addEventListener(
                "submit",
                async function (event) {

                    event.preventDefault();

                    await signUp();

                }
            );
        }

        if (showSignup) {

            showSignup.addEventListener(
                "click",
                function () {

                    signin.classList.add(
                        "storeman-auth-hidden"
                    );

                    signup.classList.remove(
                        "storeman-auth-hidden"
                    );

                    showMessage("", "info");

                }
            );
        }

        if (showSignin) {

            showSignin.addEventListener(
                "click",
                function () {

                    signup.classList.add(
                        "storeman-auth-hidden"
                    );

                    signin.classList.remove(
                        "storeman-auth-hidden"
                    );

                    showMessage("", "info");

                }
            );
        }
    }

    // ---------------------------------------------------------
    // HIDE APP BEFORE AUTH
    // ---------------------------------------------------------

    function lockApplication() {

        document.documentElement
            .classList.add("storeman-auth-lock");

        /*
         * Keep the existing application underneath the gate.
         * Nothing is deleted.
         */
    }

    // ---------------------------------------------------------
    // AUTH STATE LISTENER
    // ---------------------------------------------------------

    async function listenForAuthChanges() {

        const client = getSupabaseClient();

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

                    if (authReady) {
                        location.reload();
                    }

                    return;
                }

                if (
                    session &&
                    session.user
                ) {

                    currentUser =
                        session.user;

                    if (!authReady) {
                        await checkProfile(
                            session.user
                        );
                    }
                }
            }
        );
    }

    // ---------------------------------------------------------
    // BOOT
    // ---------------------------------------------------------

    async function boot() {

        injectCSS();

        lockApplication();

        const gate =
            createGate();

        showLoading(
            "Checking secure access..."
        );

        const client =
            getSupabaseClient();

        if (!client) {

            showLogin();

            showMessage(
                "Storeman could not find the Supabase connection. Make sure the Supabase client is loaded before this authentication module.",
                "error"
            );

            return;
        }

        attachEvents();

        await listenForAuthChanges();

        try {

            const {
                data,
                error
            } =
                await client.auth.getSession();

            if (error) {

                console.error(error);

                showLogin();

                showMessage(
                    "Unable to check your session.",
                    "error"
                );

                return;
            }

            if (
                data &&
                data.session &&
                data.session.user
            ) {

                currentUser =
                    data.session.user;

                await checkProfile(
                    currentUser
                );

            } else {

                showLogin();

            }

        } catch (err) {

            console.error(err);

            showLogin();

            showMessage(
                "Not connected. Please check your internet connection and Supabase configuration.",
                "error"
            );
        }
    }

    // ---------------------------------------------------------
    // PUBLIC API
    // ---------------------------------------------------------

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

        signOut: signOut
    };

    // ---------------------------------------------------------
    // START AFTER DOM
    // ---------------------------------------------------------

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
