(function () {

  async function notify() {

    try {

      const sb =
        window.supabaseClient ||
        window.supabase ||
        window.storemanSupabase;

      if (!sb) return;

      const { data } =
        await sb.auth.getUser();

      const user =
        data && data.user;

      if (!user || !user.email) return;

      /*
       * Only pending users need administrator approval.
       */

      const profileResult =
        await sb
          .from('profiles')
          .select('email,status,role')
          .eq('id', user.id)
          .maybeSingle();

      const profile =
        profileResult.data;

      if (
        profile &&
        profile.status === 'pending' &&
        window.StoremanAdminSecurity
      ) {
        await window.StoremanAdminSecurity
          .notifyPendingUser(user.email);
      }

    } catch (e) {
      console.warn(
        'Storeman auth notification bridge:',
        e
      );
    }
  }

  window.StoremanAuthNotification = {
    notify
  };

  document.addEventListener(
    'DOMContentLoaded',
    () => {
      setTimeout(notify, 1500);
    }
  );

})();
