window.STOREMAN_EMAIL_CONFIG = {
  publicKey: "8JupT1wuqer_SMq3p",
  serviceId: "service_g810m8a",
  receiverEmail: "ashenafihailay645@gmail.com",
  lowStockTemplateId: "template_6tpdips",
  dailyReportTemplateId: "template_tqgxj1w",

  /*
   * IMPORTANT:
   * Create this template in EmailJS for administrator alerts.
   *
   * Example template variables:
   * {{to_email}}
   * {{admin_email}}
   * {{user_email}}
   * {{event_type}}
   * {{app_name}}
   * {{timestamp}}
   * {{message}}
   */
  authNotificationTemplateId:
    window.STOREMAN_AUTH_NOTIFICATION_TEMPLATE_ID ||
    "template_auth_admin"
};
