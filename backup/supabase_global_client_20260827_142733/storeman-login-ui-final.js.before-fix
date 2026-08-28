(function () {
  "use strict";

  function getSB() {
    return window.supabaseClient || window.storemanSupabase || null;
  }

  function createAuthUI() {
    if (document.getElementById("storeman-auth-root")) return;

    const root = document.createElement("div");
    root.id = "storeman-auth-root";

    root.innerHTML = `
      <div style="
        min-height:100vh;
        display:flex;
        align-items:center;
        justify-content:center;
        background:#f1f5f9;
        padding:20px;
        font-family:Arial,sans-serif;
      ">
        <div style="
          width:100%;
          max-width:420px;
          background:white;
          padding:30px;
          border-radius:18px;
          box-shadow:0 10px 35px rgba(0,0,0,.12);
        ">
          <div style="text-align:center;margin-bottom:22px">
            <div style="font-size:48px">🔐</div>
            <h1 style="margin:8px 0;color:#0f2b48">Storeman ERP</h1>
            <p id="auth-title">Sign In</p>
          </div>

          <div id="signup-name-box" style="display:none">
            <input id="auth-name" type="text"
              placeholder="Full Name"
              style="width:100%;padding:13px;margin-bottom:10px;box-sizing:border-box">
          </div>

          <input id="auth-email" type="email"
            placeholder="Email"
            style="width:100%;padding:13px;margin-bottom:10px;box-sizing:border-box">

          <input id="auth-password" type="password"
            placeholder="Password"
            style="width:100%;padding:13px;margin-bottom:10px;box-sizing:border-box">

          <button id="auth-submit"
            style="
              width:100%;
              padding:13px;
              border:0;
              border-radius:8px;
              background:#1e3a8a;
              color:white;
              font-weight:bold;
              cursor:pointer;
            ">
            Sign In
          </button>

          <button id="auth-toggle"
            style="
              width:100%;
              margin-top:12px;
              padding:11px;
              border:1px solid #cbd5e1;
              border-radius:8px;
              background:white;
              cursor:pointer;
            ">
            Don't have an account? Sign Up
          </button>

          <div id="auth-message"
            style="margin-top:15px;text-align:center;font-size:14px">
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(root);

    let signup = false;

    const title = document.getElementById("auth-title");
    const nameBox = document.getElementById("signup-name-box");
    const submit = document.getElementById("auth-submit");
    const toggle = document.getElementById("auth-toggle");
    const message = document.getElementById("auth-message");

    toggle.onclick = function () {
      signup = !signup;

      title.textContent = signup ? "Create Account" : "Sign In";
      nameBox.style.display = signup ? "block" : "none";
      submit.textContent = signup ? "Sign Up" : "Sign In";

      toggle.textContent = signup
        ? "Already have an account? Sign In"
        : "Don't have an account? Sign Up";

      message.textContent = "";
    };

    submit.onclick = async function () {
      const sb = getSB();

      if (!sb) {
        message.textContent = "❌ Supabase is not connected.";
        return;
      }

      const email = document.getElementById("auth-email").value.trim();
      const password = document.getElementById("auth-password").value;
      const name = document.getElementById("auth-name").value.trim();

      if (!email || !password || (signup && !name)) {
        message.textContent = "⚠️ Please fill all required fields.";
        return;
      }

      submit.disabled = true;
      message.textContent = "⏳ Please wait...";

      try {
        if (signup) {
          const { data, error } = await sb.auth.signUp({
            email: email,
            password: password,
            options: {
              data: {
                full_name: name
              }
            }
          });

          if (error) throw error;

          message.textContent =
            "✅ Account created. Your account is waiting for admin approval.";

          signup = false;
          title.textContent = "Sign In";
          nameBox.style.display = "none";
          submit.textContent = "Sign In";
          toggle.textContent = "Don't have an account? Sign Up";
        } else {
          const { data, error } = await sb.auth.signInWithPassword({
            email: email,
            password: password
          });

          if (error) throw error;

          const user = data.user;

          const result = await sb
            .from("profiles")
            .select("*")
            .eq("id", user.id)
            .maybeSingle();

          if (result.error) throw result.error;

          if (!result.data) {
            await sb.auth.signOut();
            throw new Error("Profile not found.");
          }

          if (String(result.data.status).toLowerCase() !== "active") {
            await sb.auth.signOut();

            message.textContent =
              "⏳ Your account is waiting for administrator approval.";

            return;
          }

          message.textContent = "✅ Login successful...";

          setTimeout(function () {
            root.style.display = "none";
            location.reload();
          }, 500);
        }
      } catch (err) {
        console.error(err);
        message.textContent =
          "❌ " + (err.message || "Authentication failed.");
      } finally {
        submit.disabled = false;
      }
    };
  }

  function init() {
    createAuthUI();

    const sb = getSB();
    if (!sb) return;

    sb.auth.getUser().then(function (result) {
      if (result.data && result.data.user) {
        const root = document.getElementById("storeman-auth-root");
        if (root) root.style.display = "none";
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    setTimeout(init, 500);
  });

  window.StoremanLoginUI = {
    init: init
  };
})();
