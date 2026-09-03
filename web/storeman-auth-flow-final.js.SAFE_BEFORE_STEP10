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
