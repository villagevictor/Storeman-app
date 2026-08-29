/*
 * ============================================================
 * STOREMAN EMAIL MASTER FINAL ENGINE
 * ============================================================
 * Purpose:
 *   1. Low Stock Alert -> EmailJS
 *   2. Daily Movement Report -> EmailJS
 *   3. Preserve existing Storeman features
 *   4. Show real EmailJS errors
 * ============================================================
 */

(function () {
  "use strict";

  const STOREMAN_EMAIL_CONFIG = {
    publicKey: "8JupT1wuqer_SMq3P",
    serviceId: "service_ojriqwn",

    lowStockTemplateId: "template_tbu1wdb",
    dailyReportTemplateId: "template_tqgxj1w",

    adminEmail: "ashenafihailay779@gmail.com"
  };

  function log() {
    try {
      console.log.apply(console, ["[STOREMAN EMAIL]"].concat(
        Array.prototype.slice.call(arguments)
      ));
    } catch (_) {}
  }

  function getAdminEmail() {
    return (
      localStorage.getItem("storeman_admin_email") ||
      localStorage.getItem("cfg_admin_email") ||
      STOREMAN_EMAIL_CONFIG.adminEmail
    ).trim();
  }

  function emailJsReady() {
    return (
      typeof window.emailjs !== "undefined" &&
      typeof window.emailjs.send === "function"
    );
  }

  function initEmailJSFinal() {
    if (!emailJsReady()) {
      throw new Error("EmailJS SDK is not loaded.");
    }

    try {
      window.emailjs.init({
        publicKey: STOREMAN_EMAIL_CONFIG.publicKey
      });

      window.__STOREMAN_EMAIL_MASTER_READY__ = true;

      log("EmailJS initialized successfully.");
      return true;
    } catch (err) {
      log("EmailJS initialization failed:", err);
      throw err;
    }
  }

  function setMessage(el, type, text) {
    if (!el) return;

    el.className = "status-msg " + (
      type === "success"
        ? "msg-success"
        : type === "sending"
        ? "msg-sending"
        : "msg-error"
    );

    el.innerText = text;
  }

  function getTodayRange() {
    const now = new Date();

    const start = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
      0, 0, 0, 0
    );

    const end = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
      23, 59, 59, 999
    );

    return {
      start: start.toISOString(),
      end: end.toISOString()
    };
  }

  async function getSupabaseClient() {
    const candidates = [
      window.supabaseClient,
      window.storemanSupabase,
      window.SUPABASE_CLIENT
    ];

    for (const candidate of candidates) {
      if (
        candidate &&
        typeof candidate.from === "function"
      ) {
        return candidate;
      }
    }

    /*
     * Fallback: create a client directly from the existing
     * Storeman public Supabase configuration.
     */
    if (
      typeof window.supabase !== "undefined" &&
      typeof window.supabase.createClient === "function"
    ) {
      const url =
        "https://cfnrbgfczqfpmdjzzbia.supabase.co";

      const key =
        "sb_publishable_AN3kSG6xIx38ThIMg4o28w_u6kPIrn2";

      const client = window.supabase.createClient(url, key);

      window.supabaseClient = client;
      window.storemanSupabase = client;

      log("Created fallback Supabase client.");
      return client;
    }

    throw new Error("Supabase client was not found.");
  }

  async function getTodayTransactions() {
    const sb = await getSupabaseClient();
    const range = getTodayRange();

    const result = await sb
      .from("transactions")
      .select("*")
      .gte("created_at", range.start)
      .lte("created_at", range.end)
      .order("created_at", { ascending: true });

    if (result.error) {
      throw result.error;
    }

    return result.data || [];
  }

  async function getMaterials() {
    const sb = await getSupabaseClient();

    const result = await sb
      .from("materials")
      .select("*")
      .order("name", { ascending: true });

    if (result.error) {
      throw result.error;
    }

    return result.data || [];
  }

  function buildReportDetails(transactions) {
    if (!transactions.length) {
      return "No stock movement recorded today.";
    }

    return transactions.map(function (t, index) {
      const type =
        String(t.type || "").toUpperCase() === "IN"
          ? "STOCK IN"
          : "STOCK OUT";

      return (
        (index + 1) +
        ". " +
        type +
        " | Material: " +
        (t.material_name || "N/A") +
        " | Quantity: " +
        (t.quantity ?? 0) +
        " | Unit Price: " +
        (t.unit_price ?? 0) +
        " | Reference: " +
        (t.reference || "N/A")
      );
    }).join("\n");
  }

  async function sendDailyReportFinal() {
    let button = null;

    try {
      button = document.querySelector(
        'button[onclick="sendDailyReport()"]'
      );

      if (button) {
        button.disabled = true;
        button.dataset.originalText = button.innerText;
        button.innerText = "⏳ Sending Daily Report...";
      }

      initEmailJSFinal();

      const transactions = await getTodayTransactions();
      const materials = await getMaterials();

      let totalIn = 0;
      let totalOut = 0;

      transactions.forEach(function (t) {
        const qty = Number(t.quantity || 0);

        if (String(t.type || "").toUpperCase() === "IN") {
          totalIn += qty;
        }

        if (String(t.type || "").toUpperCase() === "OUT") {
          totalOut += qty;
        }
      });

      const lowStock = materials.filter(function (m) {
        return Number(m.quantity || 0) <= Number(m.min_stock || 0);
      });

      const reportDate = new Date().toLocaleDateString();

      const reportDetails = buildReportDetails(transactions);

      const lowStockDetails = lowStock.length
        ? lowStock.map(function (m) {
            return (
              (m.name || "N/A") +
              " | Current: " +
              (m.quantity ?? 0) +
              " | Minimum: " +
              (m.min_stock ?? 0) +
              " " +
              (m.unit || "")
            );
          }).join("\n")
        : "No low-stock materials.";

      const params = {
        to_email: getAdminEmail(),
        email: getAdminEmail(),

        report_date: reportDate,

        total_in: totalIn,
        total_out: totalOut,
        total_items: materials.length,

        report_details: reportDetails,

        low_stock_items: lowStock.length,
        low_stock_details: lowStockDetails
      };

      log("Sending daily report:", params);

      const result = await window.emailjs.send(
        STOREMAN_EMAIL_CONFIG.serviceId,
        STOREMAN_EMAIL_CONFIG.dailyReportTemplateId,
        params
      );

      log("Daily report sent:", result);

      const msg =
        document.getElementById("daily-report-msg") ||
        document.getElementById("report-msg");

      setMessage(
        msg,
        "success",
        "✅ Daily Report Sent Successfully!"
      );

      /*
       * Existing UI may not have a dedicated message element.
       * Therefore update the existing failure message if present.
       */
      document
        .querySelectorAll(".status-msg")
        .forEach(function (el) {
          if (
            el.innerText.includes("Report Sending Failed") ||
            el.innerText.includes("Daily Report")
          ) {
            el.className = "status-msg msg-success";
            el.innerText = "✅ Daily Report Sent Successfully!";
          }
        });

      alert("✅ Daily Movement Report sent successfully.");

      return result;

    } catch (err) {

      console.error("[STOREMAN EMAIL] Daily report failed:", err);

      const errorText =
        err && (
          err.text ||
          err.message ||
          err.status
        )
          ? String(
              err.text ||
              err.message ||
              ("EmailJS status: " + err.status)
            )
          : "Unknown EmailJS error";

      document
        .querySelectorAll(".status-msg")
        .forEach(function (el) {
          if (
            el.innerText.includes("Report") ||
            el.innerText.includes("Failed")
          ) {
            el.className = "status-msg msg-error";
            el.innerText =
              "❌ Daily Report Failed: " + errorText;
          }
        });

      alert(
        "❌ Daily Report Failed\n\n" +
        errorText +
        "\n\nCheck EmailJS service/template settings."
      );

      throw err;

    } finally {

      if (button) {
        button.disabled = false;
        button.innerText =
          button.dataset.originalText ||
          "📩 Send Today's Daily Report";
      }
    }
  }

  async function sendLowStockAlertFinal(params, targetMsgDiv) {

    try {

      initEmailJSFinal();

      if (!params) {
        throw new Error("Low stock alert data is missing.");
      }

      const adminEmail = getAdminEmail();

      const alertDate =
        params.date ||
        new Date().toLocaleString();

      const emailParams = {

        to_email: adminEmail,
        email: adminEmail,

        material_name:
          params.material_name || "Unknown Material",

        current_stock:
          params.current_stock ?? 0,

        unit:
          params.unit || "Pcs",

        minimum_stock:
          params.minimum_stock ?? 0,

        type:
          params.type || "LOW STOCK",

        quantity:
          params.quantity ?? 0,

        reference:
          params.reference || "N/A",

        date:
          alertDate
      };

      setMessage(
        targetMsgDiv,
        "sending",
        "⏳ Sending Low Stock Alert Email..."
      );

      log("Sending low stock alert:", emailParams);

      const result = await window.emailjs.send(
        STOREMAN_EMAIL_CONFIG.serviceId,
        STOREMAN_EMAIL_CONFIG.lowStockTemplateId,
        emailParams
      );

      log("Low stock alert sent:", result);

      setMessage(
        targetMsgDiv,
        "success",
        "⚠️ Low Stock Alert Email Sent!"
      );

      return result;

    } catch (err) {

      console.error(
        "[STOREMAN EMAIL] Low stock alert failed:",
        err
      );

      const errorText =
        err && (
          err.text ||
          err.message ||
          err.status
        )
          ? String(
              err.text ||
              err.message ||
              ("EmailJS status: " + err.status)
            )
          : "Unknown EmailJS error";

      setMessage(
        targetMsgDiv,
        "error",
        "❌ Low Stock Email Failed: " + errorText
      );

      /*
       * IMPORTANT:
       * Do not throw here after an inventory transaction.
       * Email failure must NOT destroy/rollback the stock operation.
       */
      return null;
    }
  }

  /*
   * Override the existing functions only after the whole
   * original Storeman page has loaded.
   */
  window.sendDailyReport = sendDailyReportFinal;

  window.triggerLowStockAlert = sendLowStockAlertFinal;

  /*
   * Expose safe diagnostic function.
   */
  window.StoremanEmailMaster = {
    config: STOREMAN_EMAIL_CONFIG,
    init: initEmailJSFinal,
    sendDailyReport: sendDailyReportFinal,
    sendLowStockAlert: sendLowStockAlertFinal
  };

  /*
   * Initialize EmailJS once after page load.
   */
  function boot() {
    try {
      initEmailJSFinal();
      log("STOREMAN EMAIL MASTER FINAL READY.");
      log("Admin:", getAdminEmail());
    } catch (err) {
      console.warn(
        "[STOREMAN EMAIL] Boot warning:",
        err
      );
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

})();
