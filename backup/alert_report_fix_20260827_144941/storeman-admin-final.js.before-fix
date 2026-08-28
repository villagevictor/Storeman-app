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
