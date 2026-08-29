/*
============================================================
STOREMAN FINAL FRONTEND SECURITY
============================================================

IMPORTANT:
This file is NOT the primary security layer.
Supabase RLS is the primary security layer.

This file:
1. Detects current profile.
2. Hides admin-only UI from normal users.
3. Blocks pending/blocked users from ERP UI.
4. Shows only authorized features.
5. Makes user-management UI admin-only.
============================================================
*/

(function () {
  "use strict";

  const ADMIN_EMAIL = "ashenafihailay779@gmail.com";

  const ADMIN_ONLY_IDS = [
    "users",
    "userManagement",
    "user-management",
    "users-section",
    "adminUsers",
    "admin-user-management",
    "userAdmin",
    "manageUsers",
    "usersManagement"
  ];

  const ADMIN_ONLY_CLASSES = [
    ".admin-only",
    ".adminOnly",
    ".admin-only-section",
    ".user-management",
    ".users-management",
    "[data-admin-only]"
  ];

  const SECURITY_FEATURES = [
    "dashboard",
    "materials",
    "stock_in",
    "stock_out",
    "suppliers",
    "warehouses",
    "invoicing",
    "reports",
    "backup",
    "users",
    "settings"
  ];

  function hideElement(el) {
    if (!el) return;

    el.style.display = "none";
    el.setAttribute("aria-hidden", "true");
    el.setAttribute("data-security-hidden", "true");
  }

  function showElement(el) {
    if (!el) return;

    el.style.removeProperty("display");
    el.removeAttribute("aria-hidden");
    el.removeAttribute("data-security-hidden");
  }

  function hideAdminOnlyUI() {
    ADMIN_ONLY_IDS.forEach(function (id) {
      hideElement(document.getElementById(id));
    });

    ADMIN_ONLY_CLASSES.forEach(function (selector) {
      document.querySelectorAll(selector).forEach(hideElement);
    });

    /*
     * Also hide common navigation items pointing to users.
     */
    document.querySelectorAll(
      '[data-feature="users"],' +
      '[data-section="users"],' +
      '[data-page="users"],' +
      '[data-nav="users"]'
    ).forEach(hideElement);
  }

  function showAdminOnlyUI() {
    ADMIN_ONLY_IDS.forEach(function (id) {
      showElement(document.getElementById(id));
    });

    ADMIN_ONLY_CLASSES.forEach(function (selector) {
      document.querySelectorAll(selector).forEach(showElement);
    });

    document.querySelectorAll(
      '[data-feature="users"],' +
      '[data-section="users"],' +
      '[data-page="users"],' +
      '[data-nav="users"]'
    ).forEach(showElement);
  }

  function getPermission(profile, feature, action) {
    if (!profile) return false;

    if (
      String(profile.role || "").toLowerCase() === "admin"
    ) {
      return true;
    }

    const permissions = profile.permissions || {};
    const featurePermissions = permissions[feature] || {};

    return featurePermissions[action] === true;
  }

  function applyFeaturePermissions(profile) {

    if (!profile) return;

    const isAdmin =
      String(profile.role || "").toLowerCase() === "admin";

    /*
     * USER MANAGEMENT IS ALWAYS ADMIN ONLY.
     */
    if (isAdmin) {
      showAdminOnlyUI();
    } else {
      hideAdminOnlyUI();
    }

    /*
     * Hide feature navigation according to permissions.
     */
    SECURITY_FEATURES.forEach(function (feature) {

      if (feature === "users") {
        return;
      }

      const allowed =
        isAdmin ||
        getPermission(profile, feature, "view");

      document.querySelectorAll(
        '[data-feature="' + feature + '"],' +
        '[data-section="' + feature + '"],' +
        '[data-page="' + feature + '"]'
      ).forEach(function (el) {

        if (allowed) {
          showElement(el);
        } else {
          hideElement(el);
        }

      });

    });
  }

  function blockInactiveUser(profile) {

    if (!profile) return;

    const status =
      String(profile.status || "").toLowerCase();

    if (status === "active") {
      return;
    }

    /*
     * Pending / blocked users should not use ERP.
     */
    document.body.classList.add(
      "storeman-account-not-active"
    );

    document.body.setAttribute(
      "data-account-status",
      status
    );

    /*
     * Hide application sections.
     */
    document.querySelectorAll(
      '[data-feature],' +
      '[data-section],' +
      '[data-page],' +
      'main .app-content'
    ).forEach(function (el) {
      hideElement(el);
    });

    /*
     * Hide admin controls regardless of status.
     */
    hideAdminOnlyUI();

    let message = document.getElementById(
      "storeman-security-message"
    );

    if (!message) {

      message = document.createElement("div");

      message.id =
        "storeman-security-message";

      message.style.padding = "24px";
      message.style.margin = "24px";
      message.style.borderRadius = "12px";
      message.style.background = "#fff3cd";
      message.style.color = "#664d03";
      message.style.fontSize = "16px";
      message.style.fontWeight = "600";

      document.body.prepend(message);
    }

    if (status === "pending") {

      message.textContent =
        "Your email has been registered, but your account is waiting for administrator approval.";

    } else if (status === "blocked") {

      message.textContent =
        "Your account has been blocked. Please contact the administrator.";

    } else {

      message.textContent =
        "Your account is not active. Please contact the administrator.";

    }
  }

  async function loadStoremanSecurity() {

    /*
     * The existing app should expose Supabase as:
     *
     * window.supabaseClient
     *
     * OR:
     * window.supabase
     *
     */

    const client =
      window.supabaseClient ||
      (
        window.supabase &&
        typeof window.supabase.from === "function"
          ? window.supabase
          : null
      );

    if (!client) {
      console.warn(
        "Storeman security: Supabase client not found."
      );
      return;
    }

    try {

      const result =
        await client.auth.getUser();

      const user =
        result && result.data
          ? result.data.user
          : null;

      if (!user) {
        hideAdminOnlyUI();
        return;
      }

      const profileResult =
        await client
          .from("profiles")
          .select(
            "id,email,full_name,role,status,company_id,warehouse_id,permissions"
          )
          .eq("id", user.id)
          .maybeSingle();

      if (profileResult.error) {
        console.error(
          "Storeman security profile error:",
          profileResult.error
        );

        hideAdminOnlyUI();
        return;
      }

      const profile =
        profileResult.data;

      if (!profile) {
        hideAdminOnlyUI();
        return;
      }

      /*
       * Extra client-side admin identity check.
       *
       * Real authorization remains RLS.
       */
      const isAdmin =
        String(profile.role || "").toLowerCase() === "admin" &&
        String(profile.email || "").toLowerCase() ===
          ADMIN_EMAIL.toLowerCase();

      profile.__storemanAdmin = isAdmin;

      window.storemanCurrentProfile = profile;

      if (isAdmin) {
        showAdminOnlyUI();
      } else {
        hideAdminOnlyUI();
      }

      blockInactiveUser(profile);

      if (
        String(profile.status || "").toLowerCase() ===
        "active"
      ) {
        applyFeaturePermissions(profile);
      }

      /*
       * Notify application code.
       */
      window.dispatchEvent(
        new CustomEvent(
          "storeman:security-ready",
          {
            detail: {
              user: user,
              profile: profile,
              isAdmin: isAdmin
            }
          }
        )
      );

    } catch (error) {

      console.error(
        "Storeman security initialization failed:",
        error
      );

      hideAdminOnlyUI();
    }
  }

  /*
   * Make functions available to existing application.
   */
  window.StoremanSecurity = {
    load: loadStoremanSecurity,
    hideAdminOnlyUI: hideAdminOnlyUI,
    showAdminOnlyUI: showAdminOnlyUI,
    getPermission: getPermission
  };

  /*
   * Start after DOM.
   */
  if (
    document.readyState === "loading"
  ) {

    document.addEventListener(
      "DOMContentLoaded",
      loadStoremanSecurity
    );

  } else {

    loadStoremanSecurity();

  }

})();
