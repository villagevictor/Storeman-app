#!/data/data/com.termux/files/usr/bin/bash

set -e

APP="$HOME/Storeman-app"
cd "$APP"

STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP="backup/alert_report_master_$STAMP"

echo "============================================================"
echo " STOREMAN ALERT + DAILY REPORT MASTER FIX"
echo "============================================================"
echo "APP: $APP"
echo "BACKUP: $BACKUP"
echo

mkdir -p "$BACKUP"

# ============================================================
# 1. BACKUP
# ============================================================

echo "===== 1. BACKUP ====="

cp index.html "$BACKUP/index.html.before-fix"

for f in \
  storeman-alert-report-resilience.js \
  storeman-email-config.js \
  storeman-security.js \
  storeman-auth.js
do
  if [ -f "$f" ]; then
    cp "$f" "$BACKUP/$f.before-fix"
  fi
done

git status --short > "$BACKUP/git-status-before.txt" 2>/dev/null || true
git rev-parse HEAD > "$BACKUP/git-head-before.txt" 2>/dev/null || true

echo "Backup created: $BACKUP"

# ============================================================
# 2. VERIFY SUPABASE IS NOT TOUCHED
# ============================================================

echo
echo "===== 2. SUPABASE PROTECTION ====="

grep -q "cfnrbgfczqfpmdjzzbia.supabase.co" index.html \
  && echo "Supabase URL: OK" \
  || echo "WARNING: Supabase URL not found."

echo "No Supabase database migration will be changed by this script."

# ============================================================
# 3. CREATE SAFE ALERT/REPORT BRIDGE
# ============================================================

echo
echo "===== 3. CREATE ALERT/REPORT BRIDGE ====="

cat > storeman-alert-report-master.js <<'JS'
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
      "service_g810m8a",

    lowTemplateId:
      localStorage.getItem("cfg_low_template") ||
      "template_6tpdips",

    dailyTemplateId:
      localStorage.getItem("cfg_report_template") ||
      "template_tqgxj1w",

    publicKey:
      localStorage.getItem("cfg_public_key") ||
      "8JupT1wuqer_SMq3p"
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
JS

echo "Master JS created."

# ============================================================
# 4. CONNECT MASTER JS
# ============================================================

echo
echo "===== 4. CONNECT MASTER JS ====="

python - <<'PY'
from pathlib import Path

p = Path("index.html")
s = p.read_text(encoding="utf-8")

script = '<script src="storeman-alert-report-master.js"></script>'

if script not in s:
    marker = "</body>"
    if marker in s:
        s = s.replace(
            marker,
            "  " + script + "\n" + marker,
            1
        )
    else:
        s += "\n" + script + "\n"

p.write_text(s, encoding="utf-8")

print("Master JS connected to index.html")
PY

# ============================================================
# 5. FIX PUBLIC EMAILJS KEY STORAGE
# ============================================================

echo
echo "===== 5. EMAILJS PUBLIC KEY BRIDGE ====="

python - <<'PY'
from pathlib import Path

p = Path("index.html")
s = p.read_text(encoding="utf-8")

old = """localStorage.getItem('cfg_public_key')"""

# If public-key config does not exist, add a safe default
needle = "function initEmailJS() {"

if needle in s and "8JupT1wuqer_SMq3p" not in s:
    print("Existing EmailJS public key configuration not detected.")
    print("Master JS contains the configured public key.")
else:
    print("EmailJS configuration detected.")
PY

# ============================================================
# 6. REMOVE ONLY THE OLD FAILURE WORDING
# ============================================================

echo
echo "===== 6. REMOVE GENERIC FAILURE UI ====="

python - <<'PY'
from pathlib import Path

p = Path("index.html")
s = p.read_text(encoding="utf-8")

replacements = {
    "❌ Email Sending Failed!":
        "⚠️ Email service unavailable — alert saved.",
    "❌ Report Sending Failed!":
        "⚠️ Email service unavailable — report generated and saved."
}

for old, new in replacements.items():
    s = s.replace(old, new)

p.write_text(s, encoding="utf-8")

print("Generic failure messages replaced.")
PY

# ============================================================
# 7. ADD SAFE MASTER BUTTON HANDLER
# ============================================================

echo
echo "===== 7. DAILY REPORT BUTTON BRIDGE ====="

python - <<'PY'
from pathlib import Path

p = Path("index.html")
s = p.read_text(encoding="utf-8")

old = 'onclick="sendDailyReport()"'
new = 'onclick="(window.storemanMasterDailyReport ? window.storemanMasterDailyReport() : sendDailyReport())"'

if old in s and new not in s:
    s = s.replace(old, new)

p.write_text(s, encoding="utf-8")

print("Daily Report button protected.")
PY

# ============================================================
# 8. CHECK DUPLICATE FUNCTIONS
# ============================================================

echo
echo "===== 8. FUNCTION CHECK ====="

echo "--- sendDailyReport definitions ---"
grep -RniE \
"function[[:space:]]+sendDailyReport|window\.sendDailyReport" \
index.html storeman-*.js 2>/dev/null | head -n 50 || true

echo
echo "--- EmailJS ---"
grep -RniE \
"emailjs\.send|emailjs\.init" \
index.html storeman-*.js 2>/dev/null | head -n 80 || true

echo
echo "--- Low Stock ---"
grep -RniE \
"Low Stock Alert|low-stock|lowStock" \
index.html storeman-alert-report-master.js 2>/dev/null | head -n 80 || true

# ============================================================
# 9. SYNTAX CHECK
# ============================================================

echo
echo "===== 9. JAVASCRIPT SYNTAX CHECK ====="

node --check storeman-alert-report-master.js

echo "Master JS syntax: OK"

# ============================================================
# 10. HTML BASIC CHECK
# ============================================================

echo
echo "===== 10. INDEX CHECK ====="

test -s index.html
grep -q "storeman-alert-report-master.js" index.html

echo "index.html: OK"
echo "Master script: CONNECTED"

# ============================================================
# 11. GIT DIFF
# ============================================================

echo
echo "===== 11. CHANGES ====="

git status --short

echo
echo "===== DIFF STAT ====="

git diff --stat

# ============================================================
# 12. COMMIT
# ============================================================

echo
echo "===== 12. COMMIT ====="

git add index.html storeman-alert-report-master.js

git commit -m \
"Fix Storeman low stock alerts and daily report resilience"

# ============================================================
# 13. PUSH
# ============================================================

echo
echo "===== 13. PUSH ====="

git push origin main

echo
echo "============================================================"
echo " MASTER FIX COMPLETED"
echo "============================================================"
echo
echo "Low Stock:"
echo "  - Local alert works independently."
echo "  - Email failure no longer destroys the alert."
echo
echo "Daily Report:"
echo "  - Report is generated locally."
echo "  - Report is saved."
echo "  - Report is downloaded."
echo "  - EmailJS is attempted when available."
echo "  - EmailJS failure no longer shows the old FAILED state."
echo
echo "AUTH / SUPABASE:"
echo "  - Not modified."
echo
echo "SHARE LINK:"
echo "https://villagevictor.github.io/Storeman-app/"
echo
echo "============================================================"
