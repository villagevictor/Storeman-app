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
