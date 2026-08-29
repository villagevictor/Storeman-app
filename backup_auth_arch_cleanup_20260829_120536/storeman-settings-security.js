(function () {

  async function applyGate() {

    try {

      if (!window.StoremanAdminSecurity) {
        return;
      }

      await window.StoremanAdminSecurity
        .installIntoSettings();

      const host =
        document.getElementById(
          'settings-user-management'
        );

      if (!host) return;

      /*
       * Non-admin:
       * completely hidden.
       */

      const profile =
        await window.StoremanAdminSecurity
          .getCurrentProfile();

      const admin =
        profile &&
        profile.status === 'active' &&
        String(profile.role).toLowerCase() === 'admin';

      if (!admin) {

        host.hidden = true;
        host.setAttribute(
          'aria-hidden',
          'true'
        );

        host.innerHTML = '';

      } else {

        host.hidden = false;
        host.setAttribute(
          'aria-hidden',
          'false'
        );
      }

    } catch (e) {

      console.warn(
        'Settings security gate:',
        e
      );

    }
  }

  window.StoremanSettingsSecurity = {
    applyGate
  };

  document.addEventListener(
    'DOMContentLoaded',
    () => setTimeout(applyGate, 1800)
  );

})();
