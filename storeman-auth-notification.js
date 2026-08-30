(function () {

  async function notify() {
    /*
     * FINAL SAFE ARCHITECTURE
     *
     * Signup notification is handled exclusively by:
     *
     * storeman-security.js
     *   -> notifyAdminNewUser()
     *   -> EmailJS AUTH template
     *
     * This compatibility bridge intentionally does NOT
     * send an email and does NOT call notifyPendingUser().
     */
    return false;
  }

  window.StoremanAuthNotification = {
    notify
  };

  /*
   * SAFE FIX:
   * Do not automatically send an admin notification on DOMContentLoaded.
   *
   * Signup notification is already handled by the Storeman security/
   * admin-management flow. Automatic execution here could send
   * duplicate EmailJS notifications.
   *
   * The bridge remains available through:
   * window.StoremanAuthNotification.notify()
   */


})();
