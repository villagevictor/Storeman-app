(() => {
  'use strict';

  // ==========================================================
  // STOREMAN SECURITY FRONTEND
  // ==========================================================

  const ADMIN_EMAIL = 'ashenafihailay779@gmail.com';

  // When the app is opened from localhost, confirmation links
  // must NOT return to a dead localhost server.
  // Change this if your real GitHub Pages URL is different.
  const PRODUCTION_URL = 'https://villagevictor.github.io/Storeman-app/';

  const APP_URL =
    (location.hostname === 'localhost' || location.hostname === '127.0.0.1')
      ? PRODUCTION_URL
      : (location.origin + location.pathname);

  const FEATURES = [
    'dashboard','materials','stock_in','stock_out','suppliers',
    'warehouses','invoicing','reports','backup','users','settings'
  ];

  const ACTIONS = ['view','create','update','delete'];

  const client =
    (typeof supabaseClient !== 'undefined' ? supabaseClient : window.supabaseClient);

  const rawFrom = client?.from?.bind(client);

  let currentSession = null;
  let currentUser = null;
  let currentProfile = null;
  let accountModal = null;
  let adminModal = null;

  if (!client) {
    console.error('[Storeman Security] supabaseClient not found.');
    return;
  }

  // ----------------------------------------------------------
  // CSS
  // ----------------------------------------------------------
  const css = document.createElement('style');
  css.textContent = `
    #storeman-auth-guard{
      position:fixed; inset:0; z-index:999999;
      background:rgba(241,245,249,.98);
      display:flex; align-items:center; justify-content:center;
      padding:18px; overflow:auto;
    }
    #storeman-auth-card{
      width:min(430px,100%);
      background:#fff; border-radius:18px;
      padding:24px; box-shadow:0 18px 55px rgba(15,43,72,.18);
      color:#172033;
    }
    #storeman-auth-card h2{margin:0 0 8px;color:#0f2b48}
    #storeman-auth-card p{color:#64748b;line-height:1.5}
    .sm-input,.sm-select{
      width:100%; padding:12px; margin:6px 0;
      border:1px solid #cbd5e1; border-radius:9px;
      font-size:14px; background:#fff;
    }
    .sm-btn{
      width:100%; border:0; border-radius:9px;
      padding:12px; margin-top:8px; font-weight:700;
      cursor:pointer;
    }
    .sm-primary{background:#123456;color:#fff}
    .sm-success{background:#059669;color:#fff}
    .sm-danger{background:#dc2626;color:#fff}
    .sm-muted{background:#eef2f7;color:#172033}
    .sm-link{background:none;border:0;color:#1d4ed8;cursor:pointer}
    .sm-msg{margin-top:10px;font-size:13px;font-weight:700}
    .sm-ok{color:#15803d}.sm-error{color:#dc2626}.sm-warn{color:#b45309}
    .sm-top-actions{
      display:flex;gap:6px;flex-wrap:wrap;margin:10px 0;
    }
    .sm-small{
      border:0;border-radius:8px;padding:8px 10px;
      cursor:pointer;font-weight:700;background:#eef2f7;color:#172033;
    }
    #storeman-account-btn{
      background:rgba(255,255,255,.15); color:#fff;
      border:1px solid rgba(255,255,255,.3);
      padding:6px 10px;border-radius:7px;
      font-size:12px;font-weight:700;cursor:pointer;
      margin-left:6px;
    }
    .sm-table-wrap{overflow:auto}
    .sm-admin-table{width:100%;border-collapse:collapse;font-size:12px}
    .sm-admin-table th,.sm-admin-table td{
      border-bottom:1px solid #e2e8f0;padding:7px;text-align:left;vertical-align:top
    }
    .sm-check-grid{
      display:grid;grid-template-columns:1fr 1fr;
      gap:6px;max-height:340px;overflow:auto;
      border:1px solid #e2e8f0;border-radius:9px;padding:8px;
    }
    .sm-perm{
      border:1px solid #e2e8f0;border-radius:8px;padding:8px;
      background:#f8fafc
    }
    .sm-perm-title{font-weight:800;margin-bottom:4px}
    .sm-perm label{font-size:11px;margin-right:5px}
    .sm-modal{
      position:fixed;inset:0;z-index:1000000;
      background:rgba(0,0,0,.58);
      display:flex;align-items:center;justify-content:center;
      padding:14px;
    }
    .sm-modal-card{
      width:min(760px,100%);max-height:92vh;overflow:auto;
      background:#fff;border-radius:16px;padding:18px;
    }
    .sm-modal-head{
      display:flex;justify-content:space-between;align-items:center;
      gap:10px;margin-bottom:10px
    }
    .sm-close{border:0;background:none;font-size:24px;cursor:pointer}
  `;
  document.head.appendChild(css);

  // ----------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------
  function esc(v) {
    return String(v ?? '').replace(/[&<>"']/g, c => ({
      '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
    }[c]));
  }

  function notify(text, type='ok') {
    const box = document.getElementById('storeman-security-message');
    if (!box) return;
    box.className = `sm-msg sm-${type}`;
    box.textContent = text;
  }

  function permissionsAll() {
    const p = {};
    FEATURES.forEach(f => {
      p[f] = {};
      ACTIONS.forEach(a => p[f][a] = true);
    });
    return p;
  }

  function hasPermission(feature, action='view') {
    if (!currentProfile) return false;
    if (currentProfile.role === 'admin') return true;
    return !!currentProfile?.permissions?.[feature]?.[action];
  }

  async function logActivity(action, entity='', entity_id='', details={}) {
    if (!currentUser || !rawFrom) return;
    try {
      await rawFrom('activity_logs').insert([{
        user_id: currentUser.id,
        action,
        entity,
        entity_id: entity_id ? String(entity_id) : null,
        details
      }]);
    } catch (e) {
      console.debug('[Storeman activity]', e?.message || e);
    }
  }

  // ----------------------------------------------------------
  // Auth guard
  // ----------------------------------------------------------
  function makeGuard() {
    let g = document.getElementById('storeman-auth-guard');
    if (g) return g;

    g = document.createElement('div');
    g.id = 'storeman-auth-guard';
    document.body.appendChild(g);
    return g;
  }

  function showGuard(html) {
    const g = makeGuard();
    g.style.display = 'flex';
    g.innerHTML = `<div id="storeman-auth-card">${html}</div>`;
  }

  function hideGuard() {
    const g = document.getElementById('storeman-auth-guard');
    if (g) g.style.display = 'none';
  }

  function showLogin() {
    showGuard(`
      <div style="font-size:42px;text-align:center">🔐</div>
      <h2>Storeman ERP</h2>
      <p>Sign in to continue. Your company, warehouse and feature permissions are enforced by Supabase.</p>
      <input class="sm-input" id="sm-login-email" type="email" placeholder="Email">
      <input class="sm-input" id="sm-login-password" type="password" placeholder="Password">
      <button class="sm-btn sm-primary" id="sm-login-btn">Sign In</button>
      <button class="sm-btn sm-muted" id="sm-show-signup">Create Account</button>
      <button class="sm-link" id="sm-forgot">Forgot password?</button>
      <div id="storeman-security-message" class="sm-msg"></div>
    `);

    document.getElementById('sm-login-btn').onclick = async () => {
      const email = document.getElementById('sm-login-email').value.trim();
      const password = document.getElementById('sm-login-password').value;
      if (!email || !password) return notify('Email and password are required.', 'error');

      notify('Signing in...', 'warn');
      const { error } = await client.auth.signInWithPassword({email,password});
      if (error) notify(error.message, 'error');
    };

    document.getElementById('sm-show-signup').onclick = showSignup;

    document.getElementById('sm-forgot').onclick = async () => {
      const email = document.getElementById('sm-login-email').value.trim();
      if (!email) return notify('Enter your email first.', 'error');
      const { error } = await client.auth.resetPasswordForEmail(email, {
        redirectTo: APP_URL
      });
      notify(error ? error.message : 'Password reset email sent.', error ? 'error' : 'ok');
    };
  }

  function showSignup() {
    showGuard(`
      <div style="font-size:42px;text-align:center">👤</div>
      <h2>Create Account</h2>
      <p>Your account requires email confirmation and then Admin approval.</p>
      <input class="sm-input" id="sm-signup-name" placeholder="Full name">
      <input class="sm-input" id="sm-signup-email" type="email" placeholder="Email">
      <input class="sm-input" id="sm-signup-password" type="password" placeholder="Password">
      <input class="sm-input" id="sm-signup-password2" type="password" placeholder="Confirm password">
      <button class="sm-btn sm-primary" id="sm-signup-btn">📝 Sign Up</button>
      <button class="sm-btn sm-muted" id="sm-back-login">← Back to Login</button>
      <div id="storeman-security-message" class="sm-msg"></div>
    `);

    document.getElementById('sm-back-login').onclick = showLogin;

    document.getElementById('sm-signup-btn').onclick = async () => {
      const full_name = document.getElementById('sm-signup-name').value.trim();
      const email = document.getElementById('sm-signup-email').value.trim();
      const password = document.getElementById('sm-signup-password').value;
      const password2 = document.getElementById('sm-signup-password2').value;

      if (!full_name || !email || !password)
        return notify('Please fill all required fields.', 'error');
      if (password.length < 6)
        return notify('Password must be at least 6 characters.', 'error');
      if (password !== password2)
        return notify('Passwords do not match.', 'error');

      notify('Creating account...', 'warn');

      const { data, error } = await client.auth.signUp({
        email,
        password,
        options: {
          data: { full_name },
          emailRedirectTo: APP_URL
        }
      });

      if (error) return notify(error.message, 'error');

      // Optional admin notification through the existing EmailJS setup.
      try {
        const serviceId = localStorage.getItem('cfg_service_id') || '';
        const templateId = localStorage.getItem('cfg_report_template') || '';
        const publicKey = localStorage.getItem('cfg_passkey') || '';
        if (serviceId && templateId && publicKey && window.emailjs) {
          window.emailjs.init(publicKey);
          await window.emailjs.send(serviceId, templateId, {
            to_email: ADMIN_EMAIL,
            user_name: full_name,
            user_email: email,
            message: `New Storeman account requires approval: ${full_name} (${email})`
          });
        }
      } catch (e) {
        console.debug('[Storeman admin notification]', e?.message || e);
      }

      notify(
        'Account created. Check the NEW USER email address for "Confirm your email address". After confirmation, the account will wait for Admin approval.',
        'ok'
      );
    };
  }

  function showConfirmationRequired(email) {
    showGuard(`
      <div style="font-size:42px;text-align:center">📧</div>
      <h2>Confirm your email</h2>
      <p>We sent a confirmation link to:</p>
      <p><b>${esc(email)}</b></p>
      <p>Open that email and tap <b>Confirm email address</b>. You will then return to Storeman ERP.</p>
      <button class="sm-btn sm-muted" id="sm-confirm-refresh">Refresh</button>
      <button class="sm-btn sm-danger" id="sm-confirm-logout">Logout</button>
      <div id="storeman-security-message" class="sm-msg sm-warn">
        Email confirmation is required before access.
      </div>
    `);

    document.getElementById('sm-confirm-refresh').onclick = () => location.reload();
    document.getElementById('sm-confirm-logout').onclick = () => client.auth.signOut();
  }

  function showPending() {
    showGuard(`
      <div style="font-size:42px;text-align:center">⏳</div>
      <h2>Waiting for Admin approval</h2>
      <p>Your email is confirmed, but your Storeman account is still <b>Pending</b>.</p>
      <p>An administrator must assign your company, warehouse, role and feature permissions before you can use the ERP.</p>
      <button class="sm-btn sm-primary" id="sm-pending-refresh">🔄 Refresh</button>
      <button class="sm-btn sm-danger" id="sm-pending-logout">Logout</button>
    `);
    document.getElementById('sm-pending-refresh').onclick = () => location.reload();
    document.getElementById('sm-pending-logout').onclick = () => client.auth.signOut();
  }

  function showBlocked(status) {
    showGuard(`
      <div style="font-size:42px;text-align:center">⛔</div>
      <h2>Access blocked</h2>
      <p>Your account status is <b>${esc(status)}</b>.</p>
      <p>Please contact the administrator.</p>
      <button class="sm-btn sm-primary" onclick="location.reload()">Refresh</button>
      <button class="sm-btn sm-danger" id="sm-block-logout">Logout</button>
    `);
    document.getElementById('sm-block-logout').onclick = () => client.auth.signOut();
  }

  // ----------------------------------------------------------
  // Existing ERP query hardening
  // ----------------------------------------------------------
  function hardenSupabaseQueries() {
    if (!rawFrom || window.__storemanFromHardened) return;
    window.__storemanFromHardened = true;

    const originalFrom = client.from.bind(window.supabaseClient);
    const scopedTables = new Set([
      'materials','suppliers','transactions','sales_orders'
    ]);

    client.from = function(table) {
      const builder = originalFrom(table);

      if (!scopedTables.has(table)) return builder;

      return new Proxy(builder, {
        get(target, prop, receiver) {
          if (prop === 'insert') {
            return (rows, ...rest) => {
              const safeRows = (Array.isArray(rows) ? rows : [rows]).map(row => ({
                ...row,
                company_id: currentProfile?.company_id ?? null,
                warehouse_id: currentProfile?.warehouse_id ?? null,
                created_by: currentUser?.id ?? null
              }));
              return target.insert(safeRows, ...rest);
            };
          }

          if (prop === 'update') {
            return (values, ...rest) => {
              const safeValues = {
                ...values,
                company_id: currentProfile?.company_id ?? values?.company_id,
                warehouse_id: currentProfile?.warehouse_id ?? values?.warehouse_id
              };
              let q = target.update(safeValues, ...rest);
              if (currentProfile?.company_id)
                q = q.eq('company_id', currentProfile.company_id);
              if (currentProfile?.warehouse_id)
                q = q.eq('warehouse_id', currentProfile.warehouse_id);
              return q;
            };
          }

          if (prop === 'delete') {
            let q = target.delete();
            if (currentProfile?.company_id)
              q = q.eq('company_id', currentProfile.company_id);
            if (currentProfile?.warehouse_id)
              q = q.eq('warehouse_id', currentProfile.warehouse_id);
            return q;
          }

          return Reflect.get(target, prop, receiver);
        }
      });
    };
  }

  // ----------------------------------------------------------
  // Local data isolation
  // ----------------------------------------------------------
  function isolateLocalStorage() {
    const key = 'storeman_security_uid';
    const oldUid = localStorage.getItem(key);

    if (oldUid && oldUid !== currentUser.id) {
      [
        'products_store',
        'warehouses_store',
        'suppliers_store',
        'transactions_store'
      ].forEach(k => localStorage.removeItem(k));
    }

    localStorage.setItem(key, currentUser.id);
  }

  // ----------------------------------------------------------
  // Cloud sync
  // ----------------------------------------------------------
  async function syncCloudToLocal() {
    if (!rawFrom || !currentProfile) return;

    try {
      const [m,s,w,t] = await Promise.all([
        rawFrom('materials').select('*').order('created_at',{ascending:false}),
        rawFrom('suppliers').select('*').order('created_at',{ascending:false}),
        rawFrom('warehouses').select('*').order('created_at',{ascending:false}),
        rawFrom('transactions').select('*').order('created_at',{ascending:false})
      ]);

      if (!m.error) localStorage.setItem('products_store', JSON.stringify(m.data || []));
      if (!s.error) localStorage.setItem('suppliers_store', JSON.stringify(s.data || []));
      if (!w.error) localStorage.setItem('warehouses_store', JSON.stringify(w.data || []));
      if (!t.error) localStorage.setItem('transactions_store', JSON.stringify(t.data || []));

      // Keep the existing ERP renderer if present.
      if (typeof window.renderUI === 'function') {
        try { window.renderUI(); } catch (_) {}
      }
    } catch (e) {
      console.debug('[Storeman cloud sync]', e?.message || e);
    }
  }

  // ----------------------------------------------------------
  // Feature visibility
  // ----------------------------------------------------------
  function applyFeatureVisibility() {
    const cards = [...document.querySelectorAll('.section-card')];

    cards.forEach(card => {
      const title = (card.querySelector('.section-title')?.textContent || '').toLowerCase();
      let feature = null;

      if (title.includes('warehouse') || title.includes('supplier')) feature = 'warehouses';
      else if (title.includes('register product') || title.includes('material')) feature = 'materials';
      else if (title.includes('stock in')) feature = 'stock_in';
      else if (title.includes('stock out') || title.includes('invoicing')) feature = 'stock_out';
      else if (title.includes('daily movement') || title.includes('report')) feature = 'reports';
      else if (title.includes('backup') || title.includes('restore')) feature = 'backup';

      if (feature) {
        card.style.display = hasPermission(feature,'view') ? '' : 'none';
      }
    });

    const settingsButton = document.querySelector('.btn-settings');
    if (settingsButton) {
      settingsButton.style.display = hasPermission('settings','view') ? '' : 'none';
    }
  }

  // ----------------------------------------------------------
  // Account menu
  // ----------------------------------------------------------
  function ensureAccountButton() {
    if (document.getElementById('storeman-account-btn')) return;

    const nav = document.querySelector('.navbar');
    if (!nav) return;

    const right = nav.lastElementChild;
    if (!right) return;

    const btn = document.createElement('button');
    btn.id = 'storeman-account-btn';
    btn.textContent = '👤 Account';
    btn.onclick = openAccount;
    right.appendChild(btn);
  }

  function openModal(title, body) {
    const modal = document.createElement('div');
    modal.className = 'sm-modal';
    modal.innerHTML = `
      <div class="sm-modal-card">
        <div class="sm-modal-head">
          <b style="font-size:18px;color:#0f2b48">${esc(title)}</b>
          <button class="sm-close">&times;</button>
        </div>
        ${body}
      </div>
    `;
    modal.querySelector('.sm-close').onclick = () => modal.remove();
    document.body.appendChild(modal);
    return modal;
  }

  async function openAccount() {
    if (!currentProfile) return;

    const companyName = currentProfile.company_id
      ? (await rawFrom('companies').select('name').eq('id',currentProfile.company_id).maybeSingle()).data?.name
      : 'Not assigned';

    const warehouseName = currentProfile.warehouse_id
      ? (await rawFrom('warehouses').select('name').eq('id',currentProfile.warehouse_id).maybeSingle()).data?.name
      : (currentProfile.role === 'admin' ? 'All warehouses (Admin)' : 'Not assigned');

    const activity = await rawFrom('activity_logs')
      .select('*')
      .eq('user_id',currentUser.id)
      .order('created_at',{ascending:false})
      .limit(20);

    accountModal = openModal('⚙️ Manage My Profile', `
      <div class="section-card">
        <p><b>Email:</b> ${esc(currentProfile.email || currentUser.email)}</p>
        <p><b>Role:</b> ${esc(currentProfile.role)}</p>
        <p><b>Status:</b> ${esc(currentProfile.status)}</p>
        <p><b>Company:</b> ${esc(companyName || 'Not assigned')}</p>
        <p><b>Warehouse:</b> ${esc(warehouseName || 'Not assigned')}</p>
        <p><b>Permissions:</b> ${FEATURES.filter(f => hasPermission(f,'view')).map(esc).join(', ') || 'None'}</p>
      </div>

      <div class="sm-top-actions">
        ${currentProfile.role === 'admin'
          ? '<button class="sm-small" id="sm-manage-users">👥 Manage Users</button>'
          : ''}
        <button class="sm-small" id="sm-refresh">🔄 Refresh</button>
        <button class="sm-small" id="sm-activity">📋 Activity Logs</button>
        <button class="sm-small" id="sm-logout">🚪 Logout</button>
      </div>

      <div id="sm-activity-box"></div>
    `);

    accountModal.querySelector('#sm-refresh').onclick = () => location.reload();
    accountModal.querySelector('#sm-logout').onclick = async () => {
      await logActivity('logout','auth',currentUser.id,{});
      await client.auth.signOut();
    };

    accountModal.querySelector('#sm-activity').onclick = () => {
      const rows = (activity.data || []).map(x => `
        <tr>
          <td>${esc(new Date(x.created_at).toLocaleString())}</td>
          <td>${esc(x.action)}</td>
          <td>${esc(x.entity || '')}</td>
        </tr>
      `).join('');

      accountModal.querySelector('#sm-activity-box').innerHTML = `
        <h3>Activity Logs</h3>
        <div class="sm-table-wrap">
          <table class="sm-admin-table">
            <tr><th>Time</th><th>Action</th><th>Entity</th></tr>
            ${rows || '<tr><td colspan="3">No activity yet.</td></tr>'}
          </table>
        </div>
      `;
    };

    const manage = accountModal.querySelector('#sm-manage-users');
    if (manage) manage.onclick = openAdminUsers;
  }

  // ----------------------------------------------------------
  // Admin user management
  // ----------------------------------------------------------
  async function openAdminUsers() {
    if (currentProfile?.role !== 'admin') return;

    const [usersRes, companiesRes, warehousesRes] = await Promise.all([
      rawFrom('profiles').select('*').order('created_at',{ascending:false}),
      rawFrom('companies').select('*').order('name'),
      rawFrom('warehouses').select('*').order('name')
    ]);

    const users = usersRes.data || [];
    const companies = companiesRes.data || [];
    const warehouses = warehousesRes.data || [];

    const modal = openModal('👥 Admin User Management', `
      <p>Approve users only after email confirmation. Assign role, company, warehouse and exact feature permissions.</p>
      <div class="sm-table-wrap">
        <table class="sm-admin-table">
          <thead>
            <tr>
              <th>User</th><th>Role</th><th>Status</th><th>Company</th><th>Warehouse</th><th>Permissions</th><th>Save</th>
            </tr>
          </thead>
          <tbody id="sm-users-body"></tbody>
        </table>
      </div>
      <hr>
      <h3>Companies / Warehouses</h3>
      <input class="sm-input" id="sm-company-name" placeholder="New company name">
      <button class="sm-btn sm-primary" id="sm-add-company">Add Company</button>
      <input class="sm-input" id="sm-wh-name" placeholder="New warehouse name">
      <input class="sm-input" id="sm-wh-location" placeholder="Warehouse location">
      <select class="sm-select" id="sm-wh-company">
        ${companies.map(c => `<option value="${esc(c.id)}">${esc(c.name)}</option>`).join('')}
      </select>
      <button class="sm-btn sm-success" id="sm-add-warehouse">Add Warehouse</button>
      <div id="sm-admin-msg" class="sm-msg"></div>
    `);

    const body = modal.querySelector('#sm-users-body');

    body.innerHTML = users.map(u => {
      const companyOptions = companies.map(c =>
        `<option value="${esc(c.id)}" ${u.company_id===c.id?'selected':''}>${esc(c.name)}</option>`
      ).join('');

      const whOptions = [
        `<option value="">-- No warehouse / all only for Admin --</option>`,
        ...warehouses
          .filter(w => !u.company_id || w.company_id === u.company_id)
          .map(w => `<option value="${esc(w.id)}" ${u.warehouse_id===w.id?'selected':''}>${esc(w.name)}</option>`)
      ].join('');

      const perms = u.permissions || {};
      const permHtml = FEATURES.map(f => `
        <div class="sm-perm">
          <div class="sm-perm-title">${esc(f)}</div>
          ${ACTIONS.map(a => `
            <label>
              <input type="checkbox"
                data-user="${esc(u.id)}"
                data-feature="${esc(f)}"
                data-action="${esc(a)}"
                ${perms?.[f]?.[a] ? 'checked' : ''}>
              ${esc(a)}
            </label>
          `).join('')}
        </div>
      `).join('');

      return `
        <tr data-user-row="${esc(u.id)}">
          <td>
            <b>${esc(u.full_name || 'Unnamed')}</b><br>
            ${esc(u.email || '')}
          </td>
          <td>
            <select class="sm-select" data-role="${esc(u.id)}">
              ${['admin','manager','staff','viewer'].map(r =>
                `<option ${u.role===r?'selected':''}>${r}</option>`
              ).join('')}
            </select>
          </td>
          <td>
            <select class="sm-select" data-status="${esc(u.id)}">
              ${['pending','active','suspended','rejected'].map(s =>
                `<option ${u.status===s?'selected':''}>${s}</option>`
              ).join('')}
            </select>
          </td>
          <td>
            <select class="sm-select" data-company="${esc(u.id)}">
              <option value="">-- None --</option>${companyOptions}
            </select>
          </td>
          <td>
            <select class="sm-select" data-warehouse="${esc(u.id)}">${whOptions}</select>
          </td>
          <td>
            <div class="sm-check-grid">${permHtml}</div>
          </td>
          <td>
            <button class="sm-small" data-save-user="${esc(u.id)}">💾 Save</button>
          </td>
        </tr>
      `;
    }).join('');

    body.querySelectorAll('[data-save-user]').forEach(btn => {
      btn.onclick = async () => {
        const uid = btn.getAttribute('data-save-user');
        const role = body.querySelector(`[data-role="${uid}"]`).value;
        const status = body.querySelector(`[data-status="${uid}"]`).value;
        const company_id = body.querySelector(`[data-company="${uid}"]`).value || null;
        const warehouse_id = body.querySelector(`[data-warehouse="${uid}"]`).value || null;

        const permissions = {};
        FEATURES.forEach(f => {
          permissions[f] = {};
          ACTIONS.forEach(a => {
            permissions[f][a] = !!body.querySelector(
              `[data-user="${uid}"][data-feature="${f}"][data-action="${a}"]`
            )?.checked;
          });
        });

        if (role === 'admin') {
          Object.assign(permissions, permissionsAll());
        }

        const { error } = await rawFrom('profiles')
          .update({role,status,company_id,warehouse_id,permissions})
          .eq('id',uid);

        const msg = modal.querySelector('#sm-admin-msg');
        msg.className = `sm-msg ${error ? 'sm-error':'sm-ok'}`;
        msg.textContent = error ? error.message : 'User permissions saved.';
        if (!error) {
          await logActivity('admin_update_user','profiles',uid,{role,status,company_id,warehouse_id});
        }
      };
    });

    modal.querySelector('#sm-add-company').onclick = async () => {
      const name = modal.querySelector('#sm-company-name').value.trim();
      if (!name) return;
      const {error} = await rawFrom('companies').insert([{name}]);
      modal.querySelector('#sm-admin-msg').textContent = error ? error.message : 'Company added. Refresh User Management.';
    };

    modal.querySelector('#sm-add-warehouse').onclick = async () => {
      const name = modal.querySelector('#sm-wh-name').value.trim();
      const location = modal.querySelector('#sm-wh-location').value.trim();
      const company_id = modal.querySelector('#sm-wh-company').value;
      if (!name || !company_id) return;
      const {error} = await rawFrom('warehouses').insert([{name,location,company_id}]);
      modal.querySelector('#sm-admin-msg').textContent = error ? error.message : 'Warehouse added. Refresh User Management.';
    };
  }

  // ----------------------------------------------------------
  // Auth event
  // ----------------------------------------------------------
  async function loadProfile(user) {
    const {data,error} = await rawFrom('profiles')
      .select('*')
      .eq('id',user.id)
      .maybeSingle();

    if (error) {
      console.error('[Storeman profile]', error);
      return null;
    }
    return data;
  }

  async function handleSession(session) {
    currentSession = session;
    currentUser = session?.user || null;

    if (!currentUser) {
      currentProfile = null;
      showLogin();
      return;
    }

    // Email confirmation gate.
    if (!currentUser.email_confirmed_at) {
      showConfirmationRequired(currentUser.email);
      return;
    }

    currentProfile = await loadProfile(currentUser);

    if (!currentProfile) {
      showGuard(`
        <div style="font-size:42px;text-align:center">⚙️</div>
        <h2>Preparing your account</h2>
        <p>Your profile is being created. Please wait a moment and refresh.</p>
        <button class="sm-btn sm-primary" onclick="location.reload()">Refresh</button>
        <button class="sm-btn sm-danger" id="sm-provision-logout">Logout</button>
      `);
      document.getElementById('sm-provision-logout').onclick = () => client.auth.signOut();
      return;
    }

    if (currentProfile.status === 'pending') {
      showPending();
      return;
    }

    if (currentProfile.status !== 'active') {
      showBlocked(currentProfile.status);
      return;
    }

    // Approved user.
    isolateLocalStorage();
    hardenSupabaseQueries();
    await logActivity('login','auth',currentUser.id,{email:currentUser.email});
    await syncCloudToLocal();

    hideGuard();
    ensureAccountButton();
    applyFeatureVisibility();
  }

  // ----------------------------------------------------------
  // Patch signup so the existing app also uses production URL.
  // This keeps compatibility with an older login/signup screen.
  // ----------------------------------------------------------
  function patchExistingSignup() {
    if (!client?.auth || window.__storemanSignupPatched) return;

    const auth = client.auth;
    if (typeof auth.signUp !== 'function') return;

    const original = auth.signUp.bind(auth);

    auth.signUp = async (credentials = {}) => {
      const c = {...credentials};
      c.options = {...(credentials.options || {}), emailRedirectTo: APP_URL};
      return original(c);
    };

    window.__storemanSignupPatched = true;
  }

  // ----------------------------------------------------------
  // Wrap common ERP actions with activity logging.
  // ----------------------------------------------------------
  function wrapActions() {
    if (window.__storemanActionsWrapped) return;
    window.__storemanActionsWrapped = true;

    [
      ['addMaterial','materials.create'],
      ['deleteMaterial','materials.delete'],
      ['processStockIn','stock_in.create'],
      ['processSalesOrder','stock_out.create'],
      ['addSupplier','suppliers.create'],
      ['addWarehouse','warehouses.create']
    ].forEach(([name,action]) => {
      const fn = window[name];
      if (typeof fn !== 'function') return;

      window[name] = async function(...args) {
        if (!hasPermission(action.split('.')[0], action.split('.')[1])) {
          alert('⛔ You do not have permission for this action.');
          return;
        }
        const result = await fn.apply(this,args);
        await logActivity(action, action.split('.')[0], '', {});
        return result;
      };
    });
  }

  // ----------------------------------------------------------
  // Boot
  // ----------------------------------------------------------
  async function boot() {
    patchExistingSignup();

    // Keep the existing app hidden until authorization is known.
    showGuard(`
      <div style="text-align:center">
        <div style="font-size:42px">🔐</div>
        <h2>Storeman ERP</h2>
        <p>Checking secure session...</p>
      </div>
    `);

    client.auth.onAuthStateChange((event, session) => {
      // Defer DB calls to avoid auth callback deadlocks.
      setTimeout(() => handleSession(session), 0);
    });

    const {data} = await client.auth.getSession();
    await handleSession(data.session);

    // Existing login pages can remain, but our secure gate is authoritative.
    setTimeout(() => {
      patchExistingSignup();
      wrapActions();
      if (currentProfile?.status === 'active') applyFeatureVisibility();
    }, 1200);
  }

  boot();
})();
