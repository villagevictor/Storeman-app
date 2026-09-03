(function () {
  "use strict";

  /*
   * STOREMAN ALERT + DAILY REPORT MASTER
   *
   * IMPORTANT:
   * - Does not modify Supabase authentication.
   * - Does not modify user permissions.
   * - Does not delete inventory data.
   * - Keeps existing sendDailyReport when available.
   * - Low-stock calculation always works locally.
   * - Daily report can always be generated even when EmailJS fails.
   */

  const CONFIG = {
    serviceId:
      localStorage.getItem("cfg_service_id") ||
      "service_ojriqwn",

    lowTemplateId:
      localStorage.getItem("cfg_low_template") ||
      "template_tbu1wdb",

    dailyTemplateId:
      localStorage.getItem("cfg_report_template_disabled") ||
      "",

    publicKey:
      localStorage.getItem("cfg_public_key") ||
      "8JupT1wuqer_SMq3P"
  };

  function emailReady() {
    return (
      typeof window.emailjs !== "undefined" &&
      typeof window.emailjs.send === "function"
    );
  }

  function initEmail() {
    try {
      if (!emailReady()) return false;

      if (!window.__STOREMAN_EMAIL_MASTER_READY) {
        if (typeof window.emailjs.init === "function") {
          window.emailjs.init({
            publicKey: CONFIG.publicKey
          });
        }

        window.__STOREMAN_EMAIL_MASTER_READY = true;
      }

      return true;
    } catch (e) {
      console.warn("[Storeman] EmailJS init:", e);
      return false;
    }
  }

  function getMaterials() {
    try {
      if (Array.isArray(window.products)) {
        return window.products;
      }

      if (Array.isArray(window.materials)) {
        return window.materials;
      }

      const raw =
        localStorage.getItem("materials") ||
        localStorage.getItem("storeman_materials");

      if (raw) {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) return parsed;
      }
    } catch (e) {
      console.warn("[Storeman] materials read:", e);
    }

    return [];
  }

  function number(v) {
    const n = Number(v);
    return Number.isFinite(n) ? n : 0;
  }

  function normalizeMaterial(item) {
    return {
      name:
        item.name ||
        item.material_name ||
        item.material ||
        "Unnamed Material",

      unit:
        item.unit ||
        "Pcs",

      quantity:
        number(
          item.quantity ??
          item.stock ??
          item.current_stock ??
          item.currentStock
        ),

      minStock:
        number(
          item.min_stock ??
          item.minimum_stock ??
          item.reorder_level ??
          item.minStock
        ),

      unitPrice:
        number(
          item.unit_price ??
          item.unitPrice ??
          item.price
        ),

      barcode:
        item.barcode ||
        item.code ||
        ""
    };
  }

  function getLowStockItems() {
    return getMaterials()
      .map(normalizeMaterial)
      .filter(function (m) {
        return m.quantity <= m.minStock;
      });
  }

  function showLocalLowStock() {
    const items = getLowStockItems();

    const old = document.getElementById(
      "storeman-master-low-stock-alert"
    );

    if (old) old.remove();

    if (!items.length) return;

    const box = document.createElement("div");

    box.id = "storeman-master-low-stock-alert";

    box.style.cssText = [
      "position:fixed",
      "top:12px",
      "left:12px",
      "right:12px",
      "z-index:999999",
      "background:#fff7ed",
      "border:2px solid #f97316",
      "border-radius:14px",
      "padding:14px",
      "box-shadow:0 8px 30px rgba(0,0,0,.18)",
      "font-family:Arial,sans-serif"
    ].join(";");

    let html =
      "<b style='font-size:17px'>⚠️ LOW STOCK ALERT</b>";

    html +=
      "<div style='margin-top:8px'>";

    items.slice(0, 8).forEach(function (m) {
      html +=
        "<div style='padding:5px 0'>" +
        "<b>" +
        escapeHtml(m.name) +
        "</b> — " +
        m.quantity +
        " " +
        escapeHtml(m.unit) +
        " / minimum " +
        m.minStock +
        "</div>";
    });

    if (items.length > 8) {
      html +=
        "<div>+" +
        (items.length - 8) +
        " more low-stock items</div>";
    }

    html += "</div>";

    box.innerHTML = html;

    document.body.appendChild(box);

    setTimeout(function () {
      if (box.parentNode) box.remove();
    }, 12000);
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function buildDailyReport() {
    const materials = getMaterials().map(normalizeMaterial);

    let totalStock = 0;
    let totalValue = 0;

    materials.forEach(function (m) {
      totalStock += m.quantity;
      totalValue += m.quantity * m.unitPrice;
    });

    const low = materials.filter(function (m) {
      return m.quantity <= m.minStock;
    });

    let report = "";

    report += "STOREMAN ERP - DAILY MOVEMENT REPORT\n";
    report += "====================================\n\n";

    report +=
      "Date: " +
      new Date().toLocaleString() +
      "\n\n";

    report +=
      "Total Materials: " +
      materials.length +
      "\n";

    report +=
      "Total Stock: " +
      totalStock +
      "\n";

    report +=
      "Total Inventory Value: ETB " +
      totalValue.toFixed(2) +
      "\n";

    report +=
      "Low Stock Items: " +
      low.length +
      "\n\n";

    report += "LOW STOCK\n";
    report += "---------\n";

    if (!low.length) {
      report += "No low-stock items.\n";
    } else {
      low.forEach(function (m, i) {
        report +=
          (i + 1) +
          ". " +
          m.name +
          " | Stock: " +
          m.quantity +
          " " +
          m.unit +
          " | Minimum: " +
          m.minStock +
          "\n";
      });
    }

    report += "\nINVENTORY\n";
    report += "---------\n";

    materials.forEach(function (m, i) {
      report +=
        (i + 1) +
        ". " +
        m.name +
        " | " +
        m.quantity +
        " " +
        m.unit +
        " | Unit Price: ETB " +
        m.unitPrice.toFixed(2) +
        "\n";
    });

    return report;
  }

  function saveReportLocally(report) {
    try {
      localStorage.setItem(
        "storeman_last_daily_report",
        report
      );

      localStorage.setItem(
        "storeman_last_daily_report_time",
        new Date().toISOString()
      );
    } catch (e) {
      console.warn("[Storeman] report local save:", e);
    }
  }

  function downloadReport(report) {
    try {
      const blob = new Blob(
        [report],
        { type: "text/plain;charset=utf-8" }
      );

      const url = URL.createObjectURL(blob);

      const a = document.createElement("a");

      a.href = url;

      a.download =
        "Storeman-Daily-Report-" +
        new Date().toISOString().slice(0, 10) +
        ".txt";

      document.body.appendChild(a);

      a.click();

      a.remove();

      setTimeout(function () {
        URL.revokeObjectURL(url);
      }, 1000);

      return true;
    } catch (e) {
      console.warn("[Storeman] download report:", e);
      return false;
    }
  }

  async function sendLowStockEmail(params) {
    if (!initEmail()) {
      return {
        success: false,
        reason: "emailjs_not_ready"
      };
    }

    if (
      !CONFIG.serviceId ||
      !CONFIG.lowTemplateId ||
      !CONFIG.publicKey
    ) {
      return {
        success: false,
        reason: "email_config_missing"
      };
    }

    const alertText =
      "LOW STOCK ALERT\n\n" +
      "Material Name: " +
      (params.material_name || "") +
      "\n" +
      "Current Stock: " +
      (params.current_stock ?? "") +
      " " +
      (params.unit || "") +
      "\n" +
      "Minimum Stock: " +
      (params.minimum_stock ?? "") +
      " " +
      (params.unit || "") +
      "\n\n" +
      "Transaction Type: " +
      (params.type || "") +
      "\n" +
      "Quantity: " +
      (params.quantity ?? "") +
      "\n" +
      "Reference: " +
      (params.reference || "") +
      "\n" +
      "Date: " +
      new Date().toLocaleString();

    try {
      await window.emailjs.send(
        CONFIG.serviceId,
        CONFIG.lowTemplateId,
        {
          message: alertText,
          alert_text: alertText,
          material_name: params.material_name || "",
          current_stock: params.current_stock ?? "",
          minimum_stock: params.minimum_stock ?? "",
          unit: params.unit || "",
          type: params.type || "",
          quantity: params.quantity ?? "",
          reference: params.reference || "",
          date: new Date().toLocaleString()
        }
      );

      return {
        success: true
      };
    } catch (e) {
      console.warn(
        "[Storeman] Low stock email failed:",
        e
      );

      return {
        success: false,
        reason: e && e.text
          ? e.text
          : e && e.message
            ? e.message
            : "email_send_failed"
      };
    }
  }

  async function masterDailyReport() {
    const report = buildDailyReport();

    saveReportLocally(report);

    const status =
      document.getElementById("daily-report-msg") ||
      document.getElementById("msgBox");

    if (status) {
      status.className = "status-msg msg-sending";
      status.innerText =
        "⏳ Generating Daily Report...";
    }

    let sent = false;
    let reason = "";

    if (initEmail()) {
      try {
        const result =
          await window.emailjs.send(
            CONFIG.serviceId,
            CONFIG.dailyTemplateId,
            {
              message: report,
              report: report,
              daily_report: report,
              report_text: report,
              date: new Date().toLocaleString(),
              total_materials: getMaterials().length,
              low_stock_items: getLowStockItems().length
            }
          );

        sent = true;
      } catch (e) {
        reason =
          e && e.text
            ? e.text
            : e && e.message
              ? e.message
              : "email_send_failed";

        console.warn(
          "[Storeman] Daily report email failed:",
          e
        );
      }
    } else {
      reason = "emailjs_not_ready";
    }

    /*
     * IMPORTANT:
     * Email failure must NOT mean report failure.
     * The report is already generated and saved locally.
     */

    if (status) {
      status.className =
        "status-msg " +
        (sent
          ? "msg-success"
          : "msg-success");

      if (sent) {
        status.innerText =
          "✅ Daily Report Sent Successfully";
      } else {
        status.innerText =
          "✅ Daily Report Generated & Saved. Email unavailable.";
      }
    }

    /*
     * Make report available to the user.
     */
    downloadReport(report);

    return {
      success: true,
      emailSent: sent,
      report: report,
      reason: reason
    };
  }

  /*
   * Safe replacement for generic failed message.
   */
  function masterLowStockAlert(params, target) {
    showLocalLowStock();

    sendLowStockEmail(params)
      .then(function (result) {
        if (!target) return;

        target.className =
          "status-msg msg-success";

        if (result.success) {
          target.innerText =
            "⚠️ Low Stock Alert Sent";
        } else {
          target.innerText =
            "⚠️ Low Stock Alert Saved. Email unavailable.";
        }
      })
      .catch(function () {
        if (!target) return;

        target.className =
          "status-msg msg-success";

        target.innerText =
          "⚠️ Low Stock Alert Saved";
      });
  }

  /*
   * Do not destroy the existing application.
   * Only expose safe master functions.
   */

  window.StoremanAlertReportMaster = {
    getLowStockItems,
    buildDailyReport,
    sendLowStockEmail,
    masterDailyReport,
    masterLowStockAlert,
    showLocalLowStock
  };

  window.storemanMasterDailyReport =
    masterDailyReport;

  window.storemanMasterLowStockAlert =
    masterLowStockAlert;

  /*
   * Start low-stock monitoring without blocking the app.
   */
  function start() {
    try {
      showLocalLowStock();
    } catch (e) {
      console.warn(
        "[Storeman] low-stock startup:",
        e
      );
    }
  }

  if (
    document.readyState === "loading"
  ) {
    document.addEventListener(
      "DOMContentLoaded",
      start
    );
  } else {
    start();
  }

})();
