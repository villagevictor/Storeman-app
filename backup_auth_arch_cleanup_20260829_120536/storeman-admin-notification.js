/*
============================================================
STOREMAN ADMIN SIGNUP NOTIFICATION
============================================================

This notification is NOT the authorization mechanism.

Authorization:
Supabase RLS + profiles.status

Notification:
EmailJS, if configured.

The new user's confirmation email remains sent by
Supabase Auth to the NEW USER.

The administrator receives a separate notification.
============================================================
*/

(function () {

  "use strict";

  const ADMIN_EMAIL =
    "ashenafihailay779@gmail.com";

  async function notifyAdminNewUser(user, profile) {

    try {

      if (!window.emailjs) {
        console.warn(
          "EmailJS is not configured. Admin notification skipped."
        );

        return {
          ok: false,
          reason: "emailjs_not_configured"
        };
      }

      /*
       * These values can be connected to the existing
       * Storeman EmailJS settings.
       */
      const publicKey =
        localStorage.getItem(
          "storeman_emailjs_public_key"
        );

      const serviceId =
        localStorage.getItem(
          "storeman_emailjs_service_id"
        );

      const templateId =
        localStorage.getItem(
          "storeman_admin_signup_template_id"
        );

      if (
        !publicKey ||
        !serviceId ||
        !templateId
      ) {

        console.warn(
          "Storeman admin notification settings are incomplete."
        );

        return {
          ok: false,
          reason: "emailjs_settings_missing"
        };
      }

      if (
        typeof window.emailjs.init === "function"
      ) {

        window.emailjs.init({
          publicKey: publicKey
        });

      }

      const params = {

        to_email: ADMIN_EMAIL,

        admin_email: ADMIN_EMAIL,

        user_email:
          user && user.email
            ? user.email
            : "",

        user_id:
          user && user.id
            ? user.id
            : "",

        full_name:
          profile && profile.full_name
            ? profile.full_name
            : "",

        status:
          profile && profile.status
            ? profile.status
            : "pending",

        role:
          profile && profile.role
            ? profile.role
            : "staff",

        company:
          profile && profile.company_id
            ? profile.company_id
            : "",

        warehouse:
          profile && profile.warehouse_id
            ? profile.warehouse_id
            : "",

        message:
          "A new Storeman user registered and is waiting for administrator approval."

      };

      const response =
        await window.emailjs.send(
          serviceId,
          templateId,
          params
        );

      console.log(
        "Storeman admin notification sent:",
        response
      );

      return {
        ok: true
      };

    } catch (error) {

      console.error(
        "Storeman admin notification failed:",
        error
      );

      return {
        ok: false,
        reason: "send_failed",
        error: error
      };
    }
  }

  window.StoremanAdminNotification = {
    notifyNewUser: notifyAdminNewUser
  };

})();
