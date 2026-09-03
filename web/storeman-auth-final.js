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
