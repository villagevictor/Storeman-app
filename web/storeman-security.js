(() => {
'use strict';

/* ============================================================
   STOREMAN FINAL SECURITY FRONTEND
   ============================================================ */

const ADMIN_EMAIL =
  'ashenafihailay779@gmail.com';

const ADMIN_NOTIFICATION_EMAIL =
  (window.STOREMAN_EMAIL_CONFIG &&
   window.STOREMAN_EMAIL_CONFIG.receiverEmail) ||
  'ashenafihailay645@gmail.com';

const APP_URL =
  'https://villagevictor.github.io/Storeman-app/';

const EMAILJS_PUBLIC_KEY =
  '8JupT1wuqer_SMq3P';

const EMAILJS_SERVICE_ID =
  'service_ojriqwn';

const EMAILJS_LOW_STOCK_TEMPLATE =
  'template_tbu1wdb';

const EMAILJS_DAILY_TEMPLATE =
  '';

/*
 * Create an EmailJS template for admin approval notification
 * and put its template ID here.
 */
const EMAILJS_ADMIN_TEMPLATE =
  'template_5x25ogv';

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
  'settings'
];

const ACTIONS = [
  'view',
  'create',
  'update',
  'delete'
];

let client =
  window.supabaseClient ||
  (typeof supabaseClient !== 'undefined'
    ? supabaseClient
    : null);

let currentUser = null;
let currentProfile = null;

/* ============================================================
   BASIC GUARD
   ============================================================ */

function isAdmin() {
  return !!(
    currentProfile &&
    currentProfile.status === 'active' &&
    currentProfile.role === 'admin'
  );
}

function isActive() {
  return !!(
    currentProfile &&
    currentProfile.status === 'active'
  );
}

function hasPermission(feature, action='view') {

  if (isAdmin()) return true;

  if (!isActive()) return false;

  const p =
    currentProfile.permissions || {};

  return !!(
    p[feature] &&
    p[feature][action] === true
  );
}

/* ============================================================
   EMAILJS
   ============================================================ */

async function initEmailJS() {

  if (!window.emailjs) {
    console.warn(
      '[Storeman] EmailJS SDK not loaded.'
    );
    return false;
  }

  try {

    emailjs.init({
      publicKey: EMAILJS_PUBLIC_KEY
    });

    console.log(
      '[Storeman] EmailJS initialized successfully.'
    );

    return true;

  } catch (err) {

    console.error(
      '[Storeman] EmailJS init failed',
      err
    );

    return false;
  }
}

/* ============================================================
   ADMIN NOTIFICATION
   ============================================================ */

async function notifyAdminNewUser(user) {

  if (
    !window.emailjs ||
    !EMAILJS_ADMIN_TEMPLATE
  ) {
    console.warn(
      '[Storeman] Admin EmailJS template is not configured.'
    );

    return false;
  }

  try {

    await initEmailJS();

    await emailjs.send(
      EMAILJS_SERVICE_ID,
      EMAILJS_ADMIN_TEMPLATE,
      {
        to_email:
          ADMIN_NOTIFICATION_EMAIL,

        admin_email:
          ADMIN_NOTIFICATION_EMAIL,

        user_email:
          user.email || '',

        user_id:
          user.id || '',

        user_name:
          user.user_metadata?.full_name || '',

        status:
          'pending',

        role:
          'staff',

        company:
          'Storeman Main Company',

        message:
          'A new Storeman user has registered and is waiting for administrator approval.',

        app_url:
          APP_URL
      }
    );

    console.log(
      '[Storeman] Admin notification sent.'
    );

    return true;

  } catch (err) {

    console.error(
      '[Storeman] Admin notification failed',
      err
    );

    return false;
  }
}

/* ============================================================
   AUTH
   ============================================================ */

async function getProfile(userId) {

  if (!client || !userId)
    return null;

  const result =
    await client
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

  if (result.error) {

    console.error(
      '[Storeman] profile error',
      result.error
    );

    return null;
  }

  return result.data;
}

/* ============================================================
   AUTH GATE
   ============================================================ */

function createGate() {

  let gate =
    document.getElementById(
      'storeman-final-auth-gate'
    );

  if (gate) return gate;

  gate =
    document.createElement('div');

  gate.id =
    'storeman-final-auth-gate';

  gate.style.cssText = `
    position:fixed;
    inset:0;
    z-index:9999999;
    background:#f8fafc;
    display:flex;
    align-items:center;
    justify-content:center;
    padding:20px;
  `;

  gate.innerHTML = `
    <div style="
      max-width:420px;
      width:100%;
      background:white;
      padding:28px;
      border-radius:18px;
      box-shadow:0 20px 60px rgba(0,0,0,.15);
      text-align:center;
      font-family:Arial,sans-serif;
    ">
      <div style="font-size:42px">🔐</div>
      <h2>Storeman ERP</h2>
      <p id="storeman-final-auth-message">
        Checking secure session...
      </p>
    </div>
  `;

  document.body.appendChild(gate);

  return gate;
}

function gateMessage(message) {

  const gate =
    createGate();

  const p =
    gate.querySelector(
      '#storeman-final-auth-message'
    );

  if (p)
    p.textContent = message;
}

function hideGate() {

  const gate =
    document.getElementById(
      'storeman-final-auth-gate'
    );

  if (gate)
    gate.remove();
}

/* ============================================================
   HIDE ADMIN-ONLY UI FROM NORMAL USERS
   ============================================================ */

function hideAdminOnlyUI() {

  if (isAdmin())
    return;

  /*
   * Never allow normal users to see these areas.
   */

  const selectors = [
    '[data-admin-only]',
    '.admin-only',
    '#userManagement',
    '#user-management',
    '#users-management',
    '#adminUserManagement',
    '#admin-user-management'
  ];

  selectors.forEach(selector => {

    document
      .querySelectorAll(selector)
      .forEach(el => {

        el.style.display = 'none';

        el.setAttribute(
          'aria-hidden',
          'true'
        );
      });
  });

  /*
   * Hide common user-management labels
   * if the old UI does not have IDs.
   */

  document
    .querySelectorAll(
      'button,a,h1,h2,h3,h4,label,section,div'
    )
    .forEach(el => {

      const text =
        (el.textContent || '')
          .trim()
          .toLowerCase();

      if (
        text === 'user management' ||
        text === 'manage users' ||
        text === 'users management' ||
        text === 'role' ||
        text === 'permissions'
      ) {

        let parent =
          el.closest(
            '[data-admin-only],.admin-only,section,div'
          );

        if (
          parent &&
          parent !== document.body
        ) {
          parent.style.display =
            'none';
        }
      }
    });
}

/* ============================================================
   SETTINGS ADMIN USER MANAGEMENT ENTRY
   ============================================================ */

function ensureAdminUserManagement() {

  if (!isAdmin())
    return;

  const settings =
    document.querySelector(
      '#settings'
    ) ||
    document.querySelector(
      '[data-section="settings"]'
    );

  if (!settings)
    return;

  if (
    document.getElementById(
      'storeman-admin-user-management'
    )
  )
    return;

  const box =
    document.createElement('div');

  box.id =
    'storeman-admin-user-management';

  box.setAttribute(
    'data-admin-only',
    'true'
  );

  box.style.cssText = `
    margin:16px 0;
    padding:16px;
    border:1px solid #e2e8f0;
    border-radius:14px;
    background:#fff;
  `;

  box.innerHTML = `
    <h3 style="margin-top:0">
      👥 User Management
    </h3>

    <p style="color:#64748b">
      Administrator only.
      Manage user approval, role, company,
      warehouse and feature permissions.
    </p>

    <button
      id="storeman-open-admin-users"
      type="button"
      style="
        width:100%;
        padding:12px;
        border:0;
        border-radius:10px;
        background:#123456;
        color:#fff;
        font-weight:700;
      "
    >
      Manage Users
    </button>

    <div
      id="storeman-admin-users-panel"
      style="display:none;margin-top:15px"
    ></div>
  `;

  settings.appendChild(box);

  document
    .getElementById(
      'storeman-open-admin-users'
    )
    .addEventListener(
      'click',
      loadAdminUsers
    );
}

/* ============================================================
   ADMIN USER MANAGEMENT
   ============================================================ */

async function loadAdminUsers() {

  if (!isAdmin())
    return;

  const panel =
    document.getElementById(
      'storeman-admin-users-panel'
    );

  if (!panel)
    return;

  panel.style.display =
    'block';

  panel.innerHTML =
    '<p>Loading users...</p>';

  const result =
    await client
      .from('profiles')
      .select(`
        id,
        full_name,
        email,
        role,
        status,
        company_id,
        warehouse_id,
        permissions
      `)
      .order(
        'created_at',
        {ascending:false}
      );

  if (result.error) {

    panel.innerHTML =
      '<p style="color:red">Unable to load users.</p>';

    console.error(
      result.error
    );

    return;
  }

  const users =
    result.data || [];

  if (!users.length) {

    panel.innerHTML =
      '<p>No users found.</p>';

    return;
  }

  panel.innerHTML = '';

  users.forEach(user => {

    const card =
      document.createElement('div');

    card.style.cssText = `
      padding:15px;
      margin-bottom:12px;
      border:1px solid #e2e8f0;
      border-radius:12px;
    `;

    const isSelf =
      user.id === currentUser.id;

    card.innerHTML = `
      <strong>
        ${escapeHtml(
          user.full_name ||
          user.email ||
          'User'
        )}
      </strong>

      <div style="font-size:13px;color:#64748b">
        ${escapeHtml(
          user.email || ''
        )}
      </div>

      <label>Role</label>
      <select data-role style="width:100%;padding:9px">
        <option value="staff"
          ${user.role==='staff'?'selected':''}>
          Staff
        </option>

        <option value="manager"
          ${user.role==='manager'?'selected':''}>
          Manager
        </option>

        <option value="admin"
          ${user.role==='admin'?'selected':''}>
          Admin
        </option>
      </select>

      <label>Status</label>
      <select data-status style="width:100%;padding:9px">
        <option value="pending"
          ${user.status==='pending'?'selected':''}>
          Pending
        </option>

        <option value="active"
          ${user.status==='active'?'selected':''}>
          Active
        </option>

        <option value="blocked"
          ${user.status==='blocked'?'selected':''}>
          Blocked
        </option>
      </select>

      <button
        data-save
        style="
          width:100%;
          margin-top:10px;
          padding:10px;
          border:0;
          border-radius:8px;
          background:#059669;
          color:white;
          font-weight:700;
        "
      >
        Save User
      </button>

      <div
        data-msg
        style="margin-top:8px;font-size:13px"
      ></div>
    `;

    const role =
      card.querySelector(
        '[data-role]'
      );

    const status =
      card.querySelector(
        '[data-status]'
      );

    const save =
      card.querySelector(
        '[data-save]'
      );

    const msg =
      card.querySelector(
        '[data-msg]'
      );

    /*
     * Do not accidentally allow changing
     * your own admin account to staff.
     */

    if (isSelf) {

      role.disabled =
        true;

      status.disabled =
        true;
    }

    save.addEventListener(
      'click',
      async () => {

        if (isSelf) {

          msg.textContent =
            'Your admin account is protected.';

          return;
        }

        const update = {

          role:
            role.value,

          status:
            status.value
        };

        const r =
          await client
            .from('profiles')
            .update(update)
            .eq('id', user.id);

        if (r.error) {

          msg.style.color =
            '#dc2626';

          msg.textContent =
            r.error.message;

          return;
        }

        msg.style.color =
          '#059669';

        msg.textContent =
          'Saved successfully.';

        setTimeout(
          loadAdminUsers,
          700
        );
      }
    );

    panel.appendChild(card);
  });
}

/* ============================================================
   ESCAPE
   ============================================================ */

function escapeHtml(value) {

  return String(value || '')
    .replaceAll('&','&amp;')
    .replaceAll('<','&lt;')
    .replaceAll('>','&gt;')
    .replaceAll('"','&quot;')
    .replaceAll("'","&#039;");
}

/* ============================================================
   SIGNUP PATCH
   ============================================================ */

function patchSignup() {

  if (!client?.auth)
    return;

  if (
    client.auth.__storemanFinalSignupPatched
  )
    return;

  const original =
    client.auth.signUp.bind(
      client.auth
    );

  client.auth.signUp =
    async function(credentials={}) {

      const c =
        {...credentials};

      c.options = {
        ...(credentials.options || {}),
        emailRedirectTo:
          APP_URL
      };

      const result =
        await original(c);

      if (
        !result.error &&
        result.data?.user
      ) {

        /*
         * Notify administrator.
         * The database/RLS remains the
         * actual security authority.
         */

        await notifyAdminNewUser(
          result.data.user
        );
      }

      return result;
    };

  client.auth.__storemanFinalSignupPatched =
    true;
}

/* ============================================================
   FEATURE VISIBILITY
   ============================================================ */

function applyFeatureVisibility() {

  /*
   * Hide feature navigation when the user
   * does not have permission.
   */

  const featureSelectors = {

    dashboard: [
      '#dashboard',
      '[data-feature="dashboard"]'
    ],

    materials: [
      '#materials',
      '[data-feature="materials"]'
    ],

    stock_in: [
      '#stock-in',
      '#stock_in',
      '[data-feature="stock_in"]'
    ],

    stock_out: [
      '#stock-out',
      '#stock_out',
      '[data-feature="stock_out"]'
    ],

    suppliers: [
      '#suppliers',
      '[data-feature="suppliers"]'
    ],

    warehouses: [
      '#warehouses',
      '[data-feature="warehouses"]'
    ],

    invoicing: [
      '#invoicing',
      '[data-feature="invoicing"]'
    ],

    reports: [
      '#reports',
      '[data-feature="reports"]'
    ],

    backup: [
      '#backup',
      '[data-feature="backup"]'
    ]
  };

  Object.entries(
    featureSelectors
  ).forEach(
    ([feature, selectors]) => {

      if (
        isAdmin() ||
        hasPermission(feature,'view')
      )
        return;

      selectors.forEach(
        selector => {

          document
            .querySelectorAll(selector)
            .forEach(el => {

              el.style.display =
                'none';

              el.setAttribute(
                'aria-hidden',
                'true'
              );
            });
        }
      );
    }
  );

  hideAdminOnlyUI();
}

/* ============================================================
   SESSION
   ============================================================ */

async function handleSession(session) {

  currentUser =
    session?.user || null;

  if (!currentUser) {

    gateMessage(
      'Please sign in.'
    );

    return;
  }

  currentProfile =
    await getProfile(
      currentUser.id
    );

  if (!currentProfile) {

    gateMessage(
      'Your account profile is not available.'
    );

    return;
  }

  /*
   * IMPORTANT:
   * Email must be confirmed before ERP access.
   */

  if (
    !currentUser.email_confirmed_at
  ) {

    gateMessage(
      'Please confirm your email address first.'
    );

    return;
  }

  /*
   * Admin is immediately active.
   */

  if (
    currentProfile.role === 'admin'
  ) {

    hideGate();

    applyFeatureVisibility();

    setTimeout(
      ensureAdminUserManagement,
      500
    );

    return;
  }

  /*
   * Normal users require ADMIN approval.
   */

  if (
    currentProfile.status !== 'active'
  ) {

    if (
      currentProfile.status === 'pending'
    ) {

      gateMessage(
        'Email confirmed. Waiting for administrator approval.'
      );

    } else {

      gateMessage(
        'Your account is currently blocked.'
      );
    }

    return;
  }

  /*
   * Approved normal user.
   */

  hideGate();

  applyFeatureVisibility();
}

/* ============================================================
   BOOT
   ============================================================ */

async function boot() {

  createGate();

  if (!client) {

    gateMessage(
      'Supabase client was not found.'
    );

    return;
  }

  patchSignup();

  await initEmailJS();

  client.auth.onAuthStateChange(
    (event,session) => {

      setTimeout(
        () => handleSession(session),
        0
      );
    }
  );

  const sessionResult =
    await client.auth.getSession();

  await handleSession(
    sessionResult.data.session
  );

  /*
   * Protect against old UI being
   * dynamically rendered later.
   */

  const observer =
    new MutationObserver(
      () => {

        if (!isAdmin())
          hideAdminOnlyUI();

        if (isActive())
          applyFeatureVisibility();

        if (isAdmin())
          ensureAdminUserManagement();
      }
    );

  observer.observe(
    document.body,
    {
      childList:true,
      subtree:true
    }
  );
}

if (
  document.readyState === 'loading'
) {

  document.addEventListener(
    'DOMContentLoaded',
    boot
  );

} else {

  boot();
}

})();
