(function () {
  "use strict";

  /*
   * STOREMAN ALERT + DAILY REPORT RESILIENCE
   *
   * This module ADDS functionality.
   * It does not delete or replace existing Storeman features.
   */

  const LOW_STOCK_REFRESH_MS = 60000;

  function getSupabaseClient() {
    return (
      window.supabaseClient ||
      window.storemanSupabase ||
      window.SUPABASE_CLIENT ||
      null
    );
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  async function getLowStockItems() {
    const sb = getSupabaseClient();

    if (!sb || typeof sb.from !== "function") {
      return [];
    }

    try {
      const result = await sb
        .from("materials")
        .select("*");

      if (result.error) {
        console.warn(
          "Storeman Low Stock:",
          result.error.message || result.error
        );
        return [];
      }

      const rows = Array.isArray(result.data) ? result.data : [];

      return rows.filter(function (item) {
        const quantity = Number(
          item.quantity ??
          item.stock ??
          item.current_stock ??
          0
        );

        const minimum = Number(
          item.min_stock ??
          item.minimum_stock ??
          item.reorder_level ??
          0
        );

        return minimum > 0 && quantity <= minimum;
      });
    } catch (error) {
      console.warn("Storeman Low Stock error:", error);
      return [];
    }
  }

  function createAlertContainer() {
    let box = document.getElementById(
      "storeman-live-low-stock-alert"
    );

    if (box) return box;

    box = document.createElement("div");
    box.id = "storeman-live-low-stock-alert";

    box.style.cssText = [
      "position:fixed",
      "top:12px",
      "right:12px",
      "z-index:999999",
      "max-width:360px",
      "font-family:Arial,sans-serif"
    ].join(";");

    document.body.appendChild(box);

    return box;
  }

  async function refreshLowStockAlert() {
    const items = await getLowStockItems();

    const box = createAlertContainer();

    if (!items.length) {
      box.innerHTML = "";
      return;
    }

    const names = items
      .slice(0, 8)
      .map(function (item) {
        const name =
          item.name ||
          item.material_name ||
          "Unnamed material";

        const quantity = Number(
          item.quantity ??
          item.stock ??
          item.current_stock ??
          0
        );

        const minimum = Number(
          item.min_stock ??
          item.minimum_stock ??
          item.reorder_level ??
          0
        );

        return (
          "<div style='margin:4px 0'>" +
          "⚠️ <b>" +
          escapeHtml(name) +
          "</b> — Stock: " +
          escapeHtml(quantity) +
          " / Minimum: " +
          escapeHtml(minimum) +
          "</div>"
        );
      })
      .join("");

    const extra =
      items.length > 8
        ? "<div style='margin-top:5px'>+" +
          (items.length - 8) +
          " more low-stock items</div>"
        : "";

    box.innerHTML =
      "<div style='" +
      "background:#fff3cd;" +
      "border:2px solid #ff9800;" +
      "border-radius:12px;" +
      "padding:12px;" +
      "box-shadow:0 4px 18px rgba(0,0,0,.18);" +
      "color:#5f4300;" +
      "'>" +
      "<div style='font-size:17px;font-weight:bold;margin-bottom:7px'>" +
      "⚠️ Low Stock Alert (" +
      items.length +
      ")" +
      "</div>" +
      names +
      extra +
      "</div>";
  }

  async function buildDailyReport() {
    const sb = getSupabaseClient();

    if (!sb || typeof sb.from !== "function") {
      throw new Error("Supabase client unavailable.");
    }

    const today = new Date().toISOString().slice(0, 10);

    const materialResult = await sb
      .from("materials")
      .select("*");

    if (materialResult.error) {
      throw materialResult.error;
    }

    let transactionResult;

    try {
      transactionResult = await sb
        .from("transactions")
        .select("*")
        .gte("created_at", today + "T00:00:00.000Z");
    } catch (e) {
      transactionResult = { data: [], error: null };
    }

    const materials = Array.isArray(materialResult.data)
      ? materialResult.data
      : [];

    const transactions =
      transactionResult &&
      Array.isArray(transactionResult.data)
        ? transactionResult.data
        : [];

    let stockIn = 0;
    let stockOut = 0;

    transactions.forEach(function (tx) {
      const qty = Number(
        tx.quantity ??
        tx.qty ??
        0
      );

      const type = String(
        tx.type ??
        ""
      ).toUpperCase();

      if (type === "IN") stockIn += qty;
      if (type === "OUT") stockOut += qty;
    });

    const lowStock = materials.filter(function (item) {
      const quantity = Number(
        item.quantity ??
        item.stock ??
        item.current_stock ??
        0
      );

      const minimum = Number(
        item.min_stock ??
        item.minimum_stock ??
        item.reorder_level ??
        0
      );

      return minimum > 0 && quantity <= minimum;
    });

    let report = "";

    report += "STOREMAN ERP - DAILY MOVEMENT REPORT\n";
    report += "Date: " + today + "\n";
    report += "====================================\n\n";

    report += "SUMMARY\n";
    report += "Materials: " + materials.length + "\n";
    report += "Transactions: " + transactions.length + "\n";
    report += "Stock In: " + stockIn + "\n";
    report += "Stock Out: " + stockOut + "\n";
    report += "Low Stock Items: " + lowStock.length + "\n\n";

    report += "LOW STOCK\n";
    report += "------------------------------------\n";

    if (!lowStock.length) {
      report += "No low-stock items.\n";
    } else {
      lowStock.forEach(function (item) {
        const name =
          item.name ||
          item.material_name ||
          "Unnamed material";

        const quantity = Number(
          item.quantity ??
          item.stock ??
          item.current_stock ??
          0
        );

        const minimum = Number(
          item.min_stock ??
          item.minimum_stock ??
          item.reorder_level ??
          0
        );

        report +=
          "- " +
          name +
          " | Stock: " +
          quantity +
          " | Minimum: " +
          minimum +
          "\n";
      });
    }

    report += "\nCURRENT INVENTORY\n";
    report += "------------------------------------\n";

    materials.forEach(function (item) {
      const name =
        item.name ||
        item.material_name ||
        "Unnamed material";

      const quantity = Number(
        item.quantity ??
        item.stock ??
        item.current_stock ??
        0
      );

      const unit =
        item.unit ||
        "Unit";

      report +=
        "- " +
        name +
        " | " +
        quantity +
        " " +
        unit +
        "\n";
    });

    return {
      text: report,
      lowStockCount: lowStock.length,
      transactionCount: transactions.length
    };
  }

  function downloadReport(text) {
    const blob = new Blob(
      [text],
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
  }

  function openMailFallback(reportText) {
    const subject =
      "Storeman ERP Daily Movement Report - " +
      new Date().toISOString().slice(0, 10);

    const body = reportText;

    const mailto =
      "mailto:?subject=" +
      encodeURIComponent(subject) +
      "&body=" +
      encodeURIComponent(body);

    window.location.href = mailto;
  }

  async function resilientDailyReport() {
    try {
      const result = await buildDailyReport();

      /*
       * Preserve the existing EmailJS function.
       * If it exists, try it first.
       */
      const existingFunctions = [
        "sendDailyReport",
        "sendDailySummary",
        "sendDailyMovementReport"
      ];

      for (const fn of existingFunctions) {
        if (
          typeof window[fn] === "function" &&
          window[fn] !== resilientDailyReport
        ) {
          try {
            const oldResult = await window[fn]();

            /*
             * Existing function succeeded.
             */
            if (oldResult !== false) {
              return true;
            }
          } catch (error) {
            console.warn(
              "Existing daily email failed. Using fallback.",
              error
            );
          }
        }
      }

      /*
       * EmailJS quota/limit fallback.
       * Do NOT lose the report.
       */
      downloadReport(result.text);

      try {
        openMailFallback(result.text);
      } catch (mailError) {
        console.warn(
          "Mail fallback unavailable:",
          mailError
        );
      }

      alert(
        "Daily report was generated successfully.\n\n" +
        "EmailJS could not send the email, so the report was saved " +
        "and an email fallback was opened."
      );

      return true;

    } catch (error) {
      console.error(
        "Storeman Daily Report:",
        error
      );

      alert(
        "Daily report could not be generated.\n\n" +
        (error.message || error)
      );

      return false;
    }
  }

  function installDailyReportFallback() {
    const buttons = Array.from(
      document.querySelectorAll("button")
    );

    buttons.forEach(function (button) {
      const text =
        (button.innerText || button.textContent || "")
          .trim()
          .toLowerCase();

      if (
        text.includes("send today's daily report") ||
        text.includes("send daily report") ||
        text.includes("daily movement summary")
      ) {
        if (
          button.dataset.storemanReportResilience !== "1"
        ) {
          button.dataset.storemanReportResilience = "1";

          button.addEventListener(
            "click",
            function () {
              setTimeout(function () {
                const failed =
                  document.body.innerText.includes(
                    "Report Sending Failed!"
                  );

                if (failed) {
                  resilientDailyReport();
                }
              }, 800);
            }
          );
        }
      }
    });
  }

  function start() {
    setTimeout(function () {
      refreshLowStockAlert();
      installDailyReportFallback();
    }, 1500);

    setInterval(
      refreshLowStockAlert,
      LOW_STOCK_REFRESH_MS
    );

    setInterval(
      installDailyReportFallback,
      5000
    );
  }

  window.StoremanAlertReport = {
    refreshLowStockAlert,
    buildDailyReport,
    resilientDailyReport,
    downloadReport,
    openMailFallback
  };

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
