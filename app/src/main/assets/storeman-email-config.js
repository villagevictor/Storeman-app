(function () {
  "use strict";

  window.STOREMAN_EMAIL_CONFIG = Object.freeze({
    receiverEmail: "ashenafihailay779@gmail.com",
    publicKey: "8JupT1wuqer_SMq3P",
    serviceId: "service_ojriqwn",
    lowStockTemplateId: "template_tbu1wdb",
    authNotificationTemplateId:
      localStorage.getItem("cfg_auth_template") ||
      "template_5x25ogv"
  });

  console.log("[STOREMAN EMAIL] FINAL CONFIG LOADED");
})();
