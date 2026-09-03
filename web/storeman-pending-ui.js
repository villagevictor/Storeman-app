(function () {

    'use strict';


    function createPendingScreen() {

        if (
            document.getElementById(
                'storeman-pending-screen'
            )
        ) {
            return;
        }


        const box =
            document.createElement('div');

        box.id =
            'storeman-pending-screen';

        box.style.cssText = `
            position:fixed;
            inset:0;
            z-index:999999;
            display:none;
            align-items:center;
            justify-content:center;
            background:#f5f7fa;
            padding:20px;
            box-sizing:border-box;
        `;


        box.innerHTML = `

            <div style="
                max-width:520px;
                width:100%;
                background:white;
                border-radius:18px;
                padding:28px;
                box-shadow:0 10px 35px rgba(0,0,0,.12);
                text-align:center;
                font-family:Arial,sans-serif;
            ">

                <div style="
                    font-size:48px;
                    margin-bottom:12px;
                ">
                    ⏳
                </div>

                <h2>
                    Account Pending Approval
                </h2>

                <p>
                    Your Storeman ERP account has been
                    created successfully.
                </p>

                <p>
                    An administrator must approve your
                    account before you can use the ERP.
                </p>

                <button
                    id="storeman-pending-signout"
                    style="
                        padding:12px 20px;
                        border:0;
                        border-radius:10px;
                        cursor:pointer;
                    "
                >
                    Sign Out
                </button>

            </div>
        `;


        document.body.appendChild(box);


        const signout =
            document.getElementById(
                'storeman-pending-signout'
            );


        if (signout) {

            signout.addEventListener(
                'click',
                async function () {

                    try {

                        await window
                            .StoremanFinalAuth
                            .signOut();

                    } catch (e) {

                        console.error(e);

                    }

                }
            );

        }

    }


    async function check() {

        if (
            !window.StoremanFinalAuth
        ) {
            return;
        }


        const state =
            await window
                .StoremanFinalAuth
                .enforce();


        createPendingScreen();


        const screen =
            document.getElementById(
                'storeman-pending-screen'
            );


        if (!screen) {
            return;
        }


        if (
            state.state === 'pending' ||
            state.state === 'blocked'
        ) {

            screen.style.display =
                'flex';

        } else {

            screen.style.display =
                'none';

        }

    }


    document.addEventListener(
        'DOMContentLoaded',
        function () {

            setTimeout(
                check,
                1600
            );

        }
    );


    window.StoremanPendingUI = {
        check
    };

})();
