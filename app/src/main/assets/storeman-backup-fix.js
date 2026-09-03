(function () {
  "use strict";

  console.log("[Storeman Backup Fix] loaded");

  function getClient() {
    return (
      window.sb ||
      window.supabaseClient ||
      window.supabase ||
      window.storemanSupabase ||
      null
    );
  }

  function parseJSON(value, fallback) {
    try {
      return JSON.parse(value);
    } catch (_) {
      return fallback;
    }
  }

  function readLocal(key, fallback) {
    return parseJSON(
      localStorage.getItem(key) ||
      JSON.stringify(fallback),
      fallback
    );
  }

  async function getCurrentUser() {
    const client = getClient();

    if (!client || !client.auth) {
      throw new Error("Supabase client/auth is not available.");
    }

    const result = await client.auth.getUser();

    if (result.error) {
      throw result.error;
    }

    if (!result.data || !result.data.user) {
      throw new Error("No authenticated Supabase user.");
    }

    return result.data.user;
  }

  async function getProfile(userId) {
    const client = getClient();

    const result = await client
      .from("profiles")
      .select("id,email,role,status,company_id")
      .eq("id", userId)
      .maybeSingle();

    if (result.error) {
      throw result.error;
    }

    return result.data || null;
  }

  /*
   * Collect ALL important Storeman data.
   * LocalStorage is used only as a source for the
   * current ERP cache. Supabase remains the cloud source.
   */
  async function collectBackupData() {
    const client = getClient();
    const user = await getCurrentUser();
    const profile = await getProfile(user.id);

    const materialsLocal =
      readLocal("products_store", null) ||
      readLocal("materials", null) ||
      readLocal("storeman_materials", []);

    const suppliersLocal =
      readLocal("suppliers_store", []);

    const warehousesLocal =
      readLocal("warehouses_store", []);

    const transactionsLocal =
      readLocal("transactions_store", []);

    const fullData = {
      schema_version: 2,

      backup_source: "storeman-web",

      user: {
        id: user.id,
        email: user.email || profile?.email || ""
      },

      profile: profile || null,

      materials: materialsLocal,
      suppliers: suppliersLocal,
      warehouses: warehousesLocal,
      transactions: transactionsLocal,

      created_at: new Date().toISOString()
    };

    /*
     * If cloud tables are available, collect them too.
     * Local cache is retained as fallback.
     */
    if (client) {
      const queries = await Promise.allSettled([
        client.from("materials").select("*"),
        client.from("suppliers").select("*"),
        client.from("warehouses").select("*"),
        client.from("transactions").select("*"),
        client.from("sales_orders").select("*")
      ]);

      const names = [
        "materials",
        "suppliers",
        "warehouses",
        "transactions",
        "sales_orders"
      ];

      queries.forEach(function (q, i) {
        if (
          q.status === "fulfilled" &&
          !q.value.error &&
          Array.isArray(q.value.data)
        ) {
          fullData[names[i]] = q.value.data;
        }
      });
    }

    return fullData;
  }

  function showMessage(text, success) {
    const candidates = [
      "#backup-status",
      "#cloud-backup-status",
      ".backup-status"
    ];

    let box = null;

    for (const selector of candidates) {
      box = document.querySelector(selector);
      if (box) break;
    }

    if (!box) {
      box = document.createElement("div");
      box.id = "storeman-backup-status";
      box.style.cssText =
        "margin-top:12px;padding:12px;border-radius:10px;font-weight:700;text-align:center;";
      const card = [...document.querySelectorAll("div")].find(function (x) {
        return (x.textContent || "").includes("Cloud Database Backup");
      });

      if (card) {
        card.appendChild(box);
      } else {
        document.body.appendChild(box);
      }
    }

    box.textContent = text;

    if (success) {
      box.style.background = "#dcfce7";
      box.style.color = "#166534";
    } else {
      box.style.background = "#fee2e2";
      box.style.color = "#991b1b";
    }
  }

  async function cloudBackupData() {
    showMessage("☁️ Saving backup to Supabase...", true);

    try {
      const client = getClient();

      if (!client) {
        throw new Error(
          "Supabase client was not found. Check supabase-config.js/config."
        );
      }

      const user = await getCurrentUser();
      const profile = await getProfile(user.id);
      const fullData = await collectBackupData();

      const email =
        user.email ||
        profile?.email ||
        "";

      if (!email) {
        throw new Error("Authenticated user email is missing.");
      }

      const payload = {
        schema_version: 2,
        saved_by: user.id,
        email: email,
        saved_at: new Date().toISOString(),
        data: fullData
      };

      /*
       * IMPORTANT:
       * Use user_id as the conflict target.
       * This avoids the common "ON CONFLICT email"
       * failure when email has no UNIQUE constraint.
       */
      const row = {
        user_id: user.id,
        email: email,
        company_id: profile?.company_id || null,
        backup_version: 2,
        payload: payload,
        materials_data: JSON.stringify(fullData),
        updated_at: new Date().toISOString()
      };

      let result = await client
        .from("store_backups")
        .upsert(row, {
          onConflict: "user_id"
        })
        .select("*")
        .single();

      /*
       * Compatibility fallback for old rows/schema.
       */
      if (result.error) {
        console.warn(
          "[Storeman Backup] user_id upsert failed:",
          result.error
        );

        const fallback = await client
          .from("store_backups")
          .upsert(
            {
              email: email,
              materials_data: JSON.stringify(fullData),
              updated_at: new Date().toISOString()
            },
            {
              onConflict: "email"
            }
          )
          .select("*")
          .single();

        result = fallback;
      }

      if (result.error) {
        throw result.error;
      }

      localStorage.setItem(
        "storeman_last_cloud_backup",
        new Date().toISOString()
      );

      showMessage(
        "✅ Cloud Backup Successful — data saved to Supabase.",
        true
      );

      console.log(
        "[Storeman Backup] SUCCESS",
        result.data
      );

      return result.data;

    } catch (error) {
      console.error(
        "[Storeman Backup] FAILED:",
        error
      );

      showMessage(
        "❌ Cloud Backup Failed: " +
          (error?.message || String(error)),
        false
      );

      throw error;
    }
  }

  async function restoreCloudData() {
    showMessage("🔄 Restoring data from Supabase...", true);

    try {
      const client = getClient();
      const user = await getCurrentUser();

      const result = await client
        .from("store_backups")
        .select("*")
        .eq("user_id", user.id)
        .order("updated_at", {
          ascending: false
        })
        .limit(1)
        .maybeSingle();

      let backup = result.data;

      /*
       * Compatibility fallback for old email-based backups.
       */
      if (!backup) {
        const emailResult = await client
          .from("store_backups")
          .select("*")
          .eq("email", user.email || "")
          .order("updated_at", {
            ascending: false
          })
          .limit(1)
          .maybeSingle();

        if (emailResult.error) {
          throw emailResult.error;
        }

        backup = emailResult.data;
      }

      if (!backup) {
        throw new Error(
          "No cloud backup was found for this account."
        );
      }

      let fullData = null;

      if (backup.payload) {
        const p =
          typeof backup.payload === "string"
            ? parseJSON(backup.payload, null)
            : backup.payload;

        fullData = p?.data || p;
      }

      if (!fullData && backup.materials_data) {
        fullData = parseJSON(
          backup.materials_data,
          null
        );
      }

      if (!fullData) {
        throw new Error(
          "Backup exists, but its data format is invalid."
        );
      }

      /*
       * Restore local cache.
       */
      if (Array.isArray(fullData.materials)) {
        localStorage.setItem(
          "products_store",
          JSON.stringify(fullData.materials)
        );

        localStorage.setItem(
          "materials",
          JSON.stringify(fullData.materials)
        );
      }

      if (Array.isArray(fullData.suppliers)) {
        localStorage.setItem(
          "suppliers_store",
          JSON.stringify(fullData.suppliers)
        );
      }

      if (Array.isArray(fullData.warehouses)) {
        localStorage.setItem(
          "warehouses_store",
          JSON.stringify(fullData.warehouses)
        );
      }

      if (Array.isArray(fullData.transactions)) {
        localStorage.setItem(
          "transactions_store",
          JSON.stringify(fullData.transactions)
        );
      }

      /*
       * Optional sales order cache.
       */
      if (Array.isArray(fullData.sales_orders)) {
        localStorage.setItem(
          "sales_orders_store",
          JSON.stringify(fullData.sales_orders)
        );
      }

      localStorage.setItem(
        "storeman_last_cloud_restore",
        new Date().toISOString()
      );

      if (typeof window.renderUI === "function") {
        try {
          window.renderUI();
        } catch (_) {}
      }

      showMessage(
        "✅ Cloud Restore Successful.",
        true
      );

      return fullData;

    } catch (error) {
      console.error(
        "[Storeman Restore] FAILED:",
        error
      );

      showMessage(
        "❌ Cloud Restore Failed: " +
          (error?.message || String(error)),
        false
      );

      throw error;
    }
  }

  /*
   * Replace old buttons safely by cloning them.
   * This removes old click listeners/inline handlers
   * without changing the ERP UI.
   */
  function installButtons() {
    const allButtons = [
      ...document.querySelectorAll("button")
    ];

    allButtons.forEach(function (button) {
      const text =
        (button.textContent || "")
          .replace(/\s+/g, " ")
          .trim()
          .toLowerCase();

      if (
        text.includes("save backup to cloud database")
      ) {
        const clone = button.cloneNode(true);

        clone.removeAttribute("onclick");

        clone.addEventListener("click", function (event) {
          event.preventDefault();

          cloudBackupData().catch(function () {});
        });

        button.replaceWith(clone);
      }

      if (
        text.includes("restore data from cloud database")
      ) {
        const clone = button.cloneNode(true);

        clone.removeAttribute("onclick");

        clone.addEventListener("click", function (event) {
          event.preventDefault();

          restoreCloudData().catch(function () {});
        });

        button.replaceWith(clone);
      }
    });
  }

  window.StoremanCloudBackup = {
    backup: cloudBackupData,
    restore: restoreCloudData,
    collect: collectBackupData
  };

  window.cloudBackupData = cloudBackupData;
  window.restoreCloudData = restoreCloudData;

  function boot() {
    installButtons();

    setTimeout(installButtons, 500);
    setTimeout(installButtons, 1500);
    setTimeout(installButtons, 3000);
  }

  if (
    document.readyState === "loading"
  ) {
    document.addEventListener(
      "DOMContentLoaded",
      boot
    );
  } else {
    boot();
  }

})();
