(function () {
  'use strict';

  const ADMIN_EMAIL = 'ashenafihailay779@gmail.com';
  const RECEIVER_EMAIL = 'ashenafihailay645@gmail.com';

  const EMAILJS_PUBLIC_KEY = '8JupT1wuqer_SMq3p';
  const EMAILJS_SERVICE_ID = 'service_g810m8a';

  /*
   * IMPORTANT:
   * Use the existing Supabase client from the Storeman app.
   * We do not expose any Supabase secret/service-role key here.
   */

  function getSupabase() {
    return (
      window.supabaseClient ||
      window.supabase ||
      window.storemanSupabase ||
      null
    );
  }

  function isAdminProfile(profile) {
    return profile &&
      String(profile.role || '').toLowerCase() === 'admin' &&
      String(profile.status || '').toLowerCase() === 'active';
  }

  async function getCurrentProfile() {
    const sb = getSupabase();
    if (!sb) throw new Error('Supabase client not found.');

    const { data: authData, error: authError } =
      await sb.auth.getUser();

    if (authError) throw authError;

    const user = authData && authData.user;

    if (!user) return null;

    const { data, error } =
      await sb
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();

    if (error) throw error;

    return data;
  }

  function escapeHTML(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  const FEATURES = [
    'dashboard',
    'materials',
    'stock_in',
    'stock_out',
    'suppliers',
    'warehouses',
    'invoicing',
    'reports',
    'backup',
    'users',
    'settings'
  ];

  const ACTIONS = [
    'view',
    'create',
    'update',
    'delete'
  ];

  function defaultPermissions() {
    const p = {};
    FEATURES.forEach(feature => {
      p[feature] = {};
      ACTIONS.forEach(action => {
        p[feature][action] = feature === 'dashboard' && action === 'view';
      });
    });
    return p;
  }

  async function sendAdminNotification(userEmail, type) {
    try {
      if (!window.emailjs) {
        console.warn('EmailJS is not loaded.');
        return false;
      }

      if (!window.__storemanEmailJSInitialized) {
        emailjs.init({
          publicKey: EMAILJS_PUBLIC_KEY
        });
        window.__storemanEmailJSInitialized = true;
      }

      /*
       * The existing low-stock template is NOT reused for auth.
       * Admin notification needs an AUTH template.
       *
       * If the template is not yet created, this function records
       * the failure in console without breaking approval.
       */

      const authTemplate =
        window.STOREMAN_AUTH_NOTIFICATION_TEMPLATE_ID ||
        'template_cwrm4pc';

      const params = {
        to_email: RECEIVER_EMAIL,
        admin_email: ADMIN_EMAIL,
        user_email: userEmail,
        event_type: type,
        app_name: 'Storeman ERP',
        timestamp: new Date().toISOString(),
        message:
          'A Storeman user requires administrator attention: ' +
          userEmail
      };

      const result = await emailjs.send(
        'service_g810m8a',
        authTemplate,
        params
      );

      console.log('Admin notification sent:', result);

      return true;

    } catch (error) {
      console.error(
        'Admin notification failed:',
        error
      );

      return false;
    }
  }

  function renderPermissionEditor(existing) {

    const permissions =
      existing || defaultPermissions();

    return FEATURES.map(feature => {

      const fp = permissions[feature] || {};

      return `
        <div class="storeman-permission-card">
          <strong>${escapeHTML(feature)}</strong>

          <div class="storeman-permission-actions">

            ${ACTIONS.map(action => `
              <label>
                <input
                  type="checkbox"
                  data-permission-feature="${escapeHTML(feature)}"
                  data-permission-action="${escapeHTML(action)}"
                  ${fp[action] ? 'checked' : ''}
                >
                ${escapeHTML(action)}
              </label>
            `).join('')}

          </div>
        </div>
      `;
    }).join('');
  }

  async function loadCompaniesAndWarehouses() {

    const sb = getSupabase();

    const companies =
      await sb
        .from('companies')
        .select('id,name')
        .order('name');

    const warehouses =
      await sb
        .from('warehouses')
        .select('id,name,company_id')
        .order('name');

    return {
      companies: companies.data || [],
      warehouses: warehouses.data || []
    };
  }

  async function findUserByEmail(email) {

    const sb = getSupabase();

    const normalized =
      String(email || '').trim().toLowerCase();

    if (!normalized) {
      throw new Error('Enter the user email.');
    }

    const { data, error } =
      await sb
        .from('profiles')
        .select('*')
        .ilike('email', normalized)
        .limit(1)
        .maybeSingle();

    if (error) throw error;

    if (!data) {
      throw new Error(
        'No registered Storeman user was found with this email.'
      );
    }

    return data;
  }

  async function approveUser(form) {

    const sb = getSupabase();

    const profile =
      await findUserByEmail(form.email.value);

    const role =
      form.role.value;

    const status =
      form.status.value;

    const companyId =
      form.company_id.value || null;

    const warehouseId =
      form.warehouse_id.value || null;

    const permissions = defaultPermissions();

    document
      .querySelectorAll(
        '[data-permission-feature]'
      )
      .forEach(input => {

        const feature =
          input.dataset.permissionFeature;

        const action =
          input.dataset.permissionAction;

        if (!permissions[feature]) {
          permissions[feature] = {};
        }

        permissions[feature][action] =
          input.checked;
      });

    const { data, error } =
      await sb
        .from('profiles')
        .update({
          role,
          status,
          company_id: companyId,
          warehouse_id: warehouseId,
          permissions,
          updated_at: new Date().toISOString()
        })
        .eq('id', profile.id)
        .select('*')
        .single();

    if (error) throw error;

    await sb
      .from('activity_logs')
      .insert({
        user_id: profile.id,
        action: status === 'active'
          ? 'ADMIN_APPROVED_USER'
          : 'ADMIN_UPDATED_USER',
        entity: 'profiles',
        entity_id: profile.id,
        details: {
          email: profile.email,
          role,
          status,
          company_id: companyId,
          warehouse_id: warehouseId,
          permissions
        }
      });

    return data;
  }

  async function renderAdminPanel(container) {

    const profile =
      await getCurrentProfile();

    /*
     * FRONTEND GATE.
     *
     * RLS is the real security.
     * This gate only controls what is displayed.
     */

    if (!isAdminProfile(profile)) {
      container.innerHTML = '';
      container.hidden = true;
      return;
    }

    container.hidden = false;

    const lists =
      await loadCompaniesAndWarehouses();

    container.innerHTML = `
      <section
        id="storeman-admin-user-management"
        class="storeman-admin-panel"
      >

        <h2>👥 User Management</h2>

        <p>
          Administrator only.
          Approve users and assign access.
        </p>

        <form id="storeman-admin-user-form">

          <label>
            Email
            <input
              name="email"
              type="email"
              placeholder="user@example.com"
              autocomplete="off"
              required
            >
          </label>

          <button
            type="button"
            id="storeman-find-user"
          >
            Find User
          </button>

          <div
            id="storeman-user-result"
            style="margin-top:12px"
          ></div>

          <label>
            Role
            <select name="role">
              <option value="staff">Staff</option>
              <option value="manager">Manager</option>
              <option value="accountant">Accountant</option>
              <option value="storekeeper">Storekeeper</option>
              <option value="admin">Admin</option>
            </select>
          </label>

          <label>
            Status
            <select name="status">
              <option value="pending">Pending</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended</option>
              <option value="rejected">Rejected</option>
            </select>
          </label>

          <label>
            Company
            <select name="company_id">
              <option value="">No company</option>

              ${lists.companies.map(c => `
                <option value="${escapeHTML(c.id)}">
                  ${escapeHTML(c.name)}
                </option>
              `).join('')}

            </select>
          </label>

          <label>
            Warehouse
            <select name="warehouse_id">
              <option value="">No warehouse</option>

              ${lists.warehouses.map(w => `
                <option
                  value="${escapeHTML(w.id)}"
                  data-company="${escapeHTML(w.company_id || '')}"
                >
                  ${escapeHTML(w.name)}
                </option>
              `).join('')}

            </select>
          </label>

          <h3>🔐 Permissions</h3>

          <div id="storeman-permission-editor">
            ${renderPermissionEditor()}
          </div>

          <button
            type="submit"
            class="storeman-admin-save"
          >
            Approve / Save User
          </button>

          <div
            id="storeman-admin-message"
            role="status"
            style="margin-top:12px"
          ></div>

        </form>

      </section>
    `;

    const form =
      document.getElementById(
        'storeman-admin-user-form'
      );

    const findButton =
      document.getElementById(
        'storeman-find-user'
      );

    const result =
      document.getElementById(
        'storeman-user-result'
      );

    const message =
      document.getElementById(
        'storeman-admin-message'
      );

    findButton.addEventListener(
      'click',
      async () => {

        try {

          const user =
            await findUserByEmail(
              form.email.value
            );

          form.role.value =
            user.role || 'staff';

          form.status.value =
            user.status || 'pending';

          form.company_id.value =
            user.company_id || '';

          form.warehouse_id.value =
            user.warehouse_id || '';

          document
            .getElementById(
              'storeman-permission-editor'
            )
            .innerHTML =
              renderPermissionEditor(
                user.permissions || defaultPermissions()
              );

          result.innerHTML = `
            <div>
              <strong>User found:</strong>
              ${escapeHTML(user.email)}
            </div>
          `;

          message.textContent =
            'User loaded. Set role, company, warehouse and permissions.';

        } catch (error) {

          result.innerHTML =
            '<span style="color:#b00020">' +
            escapeHTML(error.message) +
            '</span>';

        }
      }
    );

    form.addEventListener(
      'submit',
      async event => {

        event.preventDefault();

        try {

          message.textContent =
            'Saving...';

          const saved =
            await approveUser(form);

          message.textContent =
            `Saved: ${saved.email} (${saved.status})`;

          await sendAdminNotification(
            saved.email,
            saved.status === 'active'
              ? 'USER_APPROVED'
              : 'USER_UPDATED'
          );

        } catch (error) {

          console.error(error);

          message.textContent =
            'ERROR: ' +
            error.message;

        }
      }
    );
  }

  async function installIntoSettings() {

    /*
     * We deliberately do not put User Management on the main
     * dashboard. It belongs inside Settings.
     */

    let settingsHost =
      document.querySelector(
        '#settings-user-management'
      );

    if (!settingsHost) {

      settingsHost =
        document.createElement('div');

      settingsHost.id =
        'settings-user-management';

      settingsHost.hidden = true;

      settingsHost.style.cssText =
        'margin-top:24px;';

      const settings =
        document.querySelector(
          '#settings, [data-page="settings"], [data-section="settings"]'
        );

      if (settings) {
        settings.appendChild(settingsHost);
      } else {
        return;
      }
    }

    await renderAdminPanel(settingsHost);
  }

  async function notifyPendingUser(userEmail) {

    /*
     * Called after signup by the app.
     *
     * The Supabase database trigger creates a pending profile.
     * This notification tells the administrator that approval
     * is required.
     */

    if (!userEmail) return;

    await sendAdminNotification(
      userEmail,
      'NEW_USER_SIGNUP'
    );
  }

  window.StoremanAdminSecurity = {
    getCurrentProfile,
    renderAdminPanel,
    installIntoSettings,
    notifyPendingUser,
    findUserByEmail,
    approveUser
  };

})();
