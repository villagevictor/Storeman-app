(function () {

    "use strict";

    /*
     * STOREMAN SIMPLE AUTH ARCHITECTURE
     *
     * ADMIN:
     *   role=admin + status=active
     *   -> Login
     *   -> ERP
     *
     * NORMAL USER:
     *   Sign Up
     *   -> profile status=pending
     *   -> Admin notification
     *   -> Admin approval + permissions
     *   -> status=active
     *   -> Login
     *   -> ERP
     */

    function getSB() {

        return (
            window.storemanSupabase ||
            window.supabaseClient ||
            window.SUPABASE_CLIENT ||
            null
        );

    }

    async function getSessionUser() {

        const sb = getSB();

        if (!sb || !sb.auth)
            return null;

        const result =
            await sb.auth.getUser();

        if (result.error)
            throw result.error;

        return result.data?.user || null;
    }

    async function getProfile(userId) {

        const sb = getSB();

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

    function isAdmin(profile) {

        if (!profile)
            return false;

        return (
            String(profile.role || "")
                .trim()
                .toLowerCase() === "admin"
            &&
            String(profile.status || "")
                .trim()
                .toLowerCase() === "active"
        );
    }

    function isActive(profile) {

        return (
            String(profile?.status || "")
                .trim()
                .toLowerCase() === "active"
        );
    }

    function showAuthScreen() {

        const root =
            document.getElementById(
                "storeman-auth-root"
            );

        if (root)
            root.style.display = "flex";
    }

    function notify(message, error) {

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
            "[Storeman Auth]",
            message
        );
    }

    async function enforceSession() {

        const sb = getSB();

        if (!sb || !sb.auth)
            return;

        const user =
            await getSessionUser();

        /*
         * No login
         */
        if (!user) {

            showAuthScreen();

            return;
        }

        const profile =
            await getProfile(user.id);

        /*
         * Profile missing
         */
        if (!profile) {

            await sb.auth.signOut();

            showAuthScreen();

            notify(
                "Your Storeman profile was not found.",
                true
            );

            return;
        }

        /*
         * ADMIN
         *
         * Only role=admin AND status=active
         * can enter ERP immediately.
         */
        if (isAdmin(profile)) {

            notify(
                "Admin access granted.",
                false
            );

            return;
        }

        /*
         * NORMAL USER
         *
         * Must be active after administrator
         * approval.
         */
        if (!isActive(profile)) {

            await sb.auth.signOut();

            showAuthScreen();

            const status =
                String(
                    profile.status || "pending"
                )
                .trim()
                .toLowerCase();

            if (status === "pending") {

                notify(
                    "Your account is waiting for administrator approval.",
                    true
                );

            } else {

                notify(
                    "Your account is not active. Please contact the administrator.",
                    true
                );
            }

            return;
        }

        /*
         * Approved normal user.
         *
         * status=active -> ERP allowed.
         */
        notify(
            "Account approved. Access granted.",
            false
        );
    }

    async function init() {

        try {

            const sb = getSB();

            if (!sb || !sb.auth)
                return;

            await enforceSession();

            /*
             * Avoid registering the listener twice.
             */
            if (
                sb.auth.__storemanFinalFlowListener
            )
                return;

            sb.auth.__storemanFinalFlowListener =
                true;

            sb.auth.onAuthStateChange(
                async function (
                    event,
                    session
                ) {

                    try {

                        if (
                            event ===
                            "SIGNED_OUT"
                        ) {

                            showAuthScreen();

                            return;
                        }

                        if (
                            event ===
                            "SIGNED_IN"
                        ) {

                            if (
                                !session?.user
                            )
                                return;

                            await enforceSession();
                        }

                    } catch (error) {

                        console.error(
                            "Storeman auth state error:",
                            error
                        );

                    }

                }
            );

        } catch (error) {

            console.error(
                "Storeman final auth flow:",
                error
            );

            showAuthScreen();
        }
    }

    window.StoremanAuthFinalFlow = {

        init,
        enforceSession,
        getProfile,
        isAdmin,
        isActive
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
