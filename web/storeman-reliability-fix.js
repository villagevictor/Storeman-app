
(function () {

"use strict";

const STOREMAN_DEFAULTS = {

    receiverEmail:
        "ashenafihailay779@gmail.com",

    publicKey:
        "8JupT1wuqer_SMq3P",

    serviceId:
        "service_ojriqwn",

    lowStockTemplateId:
        "template_tbu1wdb"

};


function getConfig(key, storageKey) {

    try {

        const saved =
            localStorage.getItem(storageKey);

        if (saved && saved.trim()) {

            return saved.trim();

        }

    } catch (_) {}

    return STOREMAN_DEFAULTS[key];

}


function setStatus(target, type, text) {

    if (!target) return;

    target.className =
        "status-msg " + type;

    target.innerText =
        text;

}


async function sendLowStockAlert(
    params,
    target
) {

    const receiver =
        getConfig(
            "receiverEmail",
            "cfg_email"
        );

    const publicKey =
        getConfig(
            "publicKey",
            "cfg_passkey"
        );

    const serviceId =
        getConfig(
            "serviceId",
            "cfg_service_id"
        );

    const templateId =
        getConfig(
            "lowStockTemplateId",
            "cfg_low_template"
        );


    if (
        !window.emailjs ||

        typeof window.emailjs.send !==
        "function"
    ) {

        setStatus(
            target,
            "msg-error",
            "❌ EmailJS SDK is not loaded."
        );

        return false;

    }


    try {

        window.emailjs.init({

            publicKey:
                publicKey

        });

    } catch (_) {}


    const date =
        new Date().toLocaleString();


    const message =

        "⚠️ LOW STOCK ALERT\n\n" +

        "Material Name: " +
        (params.material_name || "") +
        "\n" +

        "Current Stock: " +
        (params.current_stock ?? "") +
        " " +
        (params.unit || "") +
        "\n" +

        "Minimum Stock: " +
        (params.minimum_stock ?? "") +
        " " +
        (params.unit || "") +
        "\n\n" +

        "Transaction Type: " +
        (params.type || "") +
        "\n" +

        "Quantity: " +
        (params.quantity ?? "") +
        "\n" +

        "Reference: " +
        (params.reference || "") +
        "\n" +

        "Date: " +
        date +
        "\n\n" +

        "Please restock this material as soon as possible.";


    setStatus(
        target,
        "msg-sending",
        "⏳ Sending Low Stock Alert Email..."
    );


    try {

        await window.emailjs.send(

            serviceId,

            templateId,

            {

                to_email:
                    receiver,

                material_name:
                    params.material_name || "",

                current_stock:
                    params.current_stock ?? "",

                unit:
                    params.unit || "",

                minimum_stock:
                    params.minimum_stock ?? "",

                type:
                    params.type || "",

                quantity:
                    params.quantity ?? "",

                reference:
                    params.reference || "",

                date:
                    date,

                message:
                    message,

                alert_text:
                    message

            }

        );


        setStatus(
            target,
            "msg-success",
            "✅ Low Stock Alert Email Sent!"
        );


        return true;


    } catch (error) {

        console.error(
            "[Storeman] Low Stock EmailJS Error:",
            error
        );


        setStatus(

            target,

            "msg-error",

            "❌ Email service unavailable. Reconnect EmailJS Gmail service and test again."

        );


        return false;

    }

}


/*
 * Make repaired function available
 * to existing Storeman inline handlers.
 */

window.triggerLowStockAlert =
    sendLowStockAlert;


window.StoremanReliability = {

    sendLowStockAlert

};


/*
 * Correct old receiver address.
 */

try {

    if (
        localStorage.getItem(
            "cfg_email"
        ) ===
        "ashenafihailay645@gmail.com"
    ) {

        localStorage.setItem(
            "cfg_email",
            STOREMAN_DEFAULTS.receiverEmail
        );

    }

} catch (_) {}


/*
 * Keep existing cloud backup module.
 */

function installBackupButtons() {

    if (
        !window.StoremanCloudBackup
    ) return;


    window.cloudBackupData =
        window.StoremanCloudBackup.backup;

    window.restoreCloudData =
        window.StoremanCloudBackup.restore;


    document
        .querySelectorAll("button")
        .forEach(function (button) {

            const text =
                (
                    button.textContent ||
                    ""
                )
                .replace(/\s+/g, " ")
                .trim()
                .toLowerCase();


            if (

                text.includes(
                    "save backup to cloud database"
                )

                &&

                button.dataset
                    .storemanBackupFix !==
                    "1"

            ) {

                button.dataset
                    .storemanBackupFix =
                    "1";


                button.removeAttribute(
                    "onclick"
                );


                button.addEventListener(
                    "click",
                    function (event) {

                        event.preventDefault();

                        window
                            .cloudBackupData()
                            .catch(
                                function (error) {

                                    console.error(
                                        "[Storeman] Backup:",
                                        error
                                    );

                                }
                            );

                    }
                );

            }


            if (

                text.includes(
                    "restore data from cloud database"
                )

                &&

                button.dataset
                    .storemanRestoreFix !==
                    "1"

            ) {

                button.dataset
                    .storemanRestoreFix =
                    "1";


                button.removeAttribute(
                    "onclick"
                );


                button.addEventListener(
                    "click",
                    function (event) {

                        event.preventDefault();

                        window
                            .restoreCloudData()
                            .catch(
                                function (error) {

                                    console.error(
                                        "[Storeman] Restore:",
                                        error
                                    );

                                }
                            );

                    }
                );

            }

        });

}


function install() {

    window.triggerLowStockAlert =
        sendLowStockAlert;

    installBackupButtons();

}


if (
    document.readyState ===
    "loading"
) {

    document.addEventListener(
        "DOMContentLoaded",
        install
    );

} else {

    install();

}


setTimeout(
    install,
    1000
);

setTimeout(
    install,
    3000
);


})();

