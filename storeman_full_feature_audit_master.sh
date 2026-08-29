#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/Storeman-app"
cd "$ROOT" || exit 1

REPORT="STOREMAN_FEATURE_AUDIT_$(date +%Y%m%d_%H%M%S).txt"

exec > >(tee "$REPORT") 2>&1

echo "=============================================================="
echo "        STOREMAN ERP — FULL FEATURE AUDIT MASTER"
echo "=============================================================="
echo "Project : $ROOT"
echo "Date    : $(date)"
echo "Report  : $REPORT"
echo

section() {
  echo
  echo "=============================================================="
  echo " $1"
  echo "=============================================================="
}

exists() {
  local label="$1"
  shift
  local found=0
  for x in "$@"; do
    if grep -RniE "$x" \
      --include='*.html' \
      --include='*.js' \
      --include='*.css' \
      --include='*.json' \
      --include='*.sql' \
      . 2>/dev/null \
      | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/|/web/' \
      | head -1 | grep -q .; then
        found=1
        break
    fi
  done

  if [ "$found" -eq 1 ]; then
    printf "  [EXISTS ] %-32s\n" "$label"
  else
    printf "  [MISSING] %-32s\n" "$label"
  fi
}

count_matches() {
  local pattern="$1"
  grep -RniE "$pattern" \
    --include='*.html' \
    --include='*.js' \
    --include='*.css' \
    --include='*.json' \
    --include='*.sql' \
    . 2>/dev/null \
    | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/|/web/' \
    | wc -l
}

# ==============================================================
section "1. PROJECT STRUCTURE"

echo "--- Root files ---"
find . -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

echo
echo "--- Important directories ---"
for d in app app/src app/src/main app/src/main/assets web www .github backup; do
  if [ -d "$d" ]; then
    echo "  EXISTS : $d"
  fi
done

echo
echo "--- File counts ---"
echo "HTML : $(find . -type f -name '*.html' | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' | wc -l)"
echo "JS   : $(find . -type f -name '*.js'   | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' | wc -l)"
echo "CSS  : $(find . -type f -name '*.css'  | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' | wc -l)"
echo "SQL  : $(find . -type f -name '*.sql'  | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' | wc -l)"

# ==============================================================
section "2. CORE ERP FEATURES"

exists "Dashboard" \
  'Dashboard|dashboard|dashboard\.overview'

exists "Products / Materials" \
  'Add Material|Add Product|products|materials|product'

exists "Inventory / Stock" \
  'Stock In|Stock Out|Current Stock|stock|inventory'

exists "Stock In" \
  'Stock In|stock.?in|transaction.*IN'

exists "Stock Out" \
  'Stock Out|stock.?out|transaction.*OUT'

exists "Stock Balance" \
  'stock balance|current stock|stockBalance|stock_balance'

exists "Low Stock Alert" \
  'Low Stock|low.?stock|minimum.?stock|reorder'

exists "Transaction History" \
  'Transaction History|transaction history|transactions'

exists "Warehouses" \
  'Warehouse|warehouses'

exists "Suppliers" \
  'Supplier|suppliers'

exists "Customers" \
  'Customer|customers'

exists "Categories" \
  'Category|categories'

exists "Units" \
  'unit|units|measurement'

exists "Purchasing" \
  'Purchase|Purchasing|purchase.?order|purchase_order'

exists "Sales" \
  'Sales|sale|sales.?order|sale_order'

exists "POS" \
  'POS|Point of Sale|point.?of.?sale'

exists "Invoicing" \
  'Invoice|invoicing|invoice'

exists "Receipts" \
  'Receipt|receipt'

exists "Payments" \
  'Payment|payments'

exists "Expenses" \
  'Expense|expenses'

exists "Accounting" \
  'Accounting|accounting|journal|ledger'

exists "Reports" \
  'Report|Reports|report'

exists "Daily Movement Report" \
  'Daily Movement|daily.?summary|movement.?summary'

exists "Notifications" \
  'Notification|notification|alert'

exists "WhatsApp Integration" \
  'WhatsApp|whatsapp'

exists "Email Integration" \
  'EmailJS|emailjs|sendEmail|email'

exists "Settings" \
  'Settings|settings'

# ==============================================================
section "3. AUTHENTICATION & USER MANAGEMENT"

exists "Supabase Auth" \
  'supabase.*auth|auth\.getUser|auth\.signIn|auth\.signOut'

exists "Final Auth Core" \
  'StoremanFinalAuth|storeman-auth-final\.js'

exists "Auth Flow" \
  'StoremanAuthFinalFlow|storeman-auth-flow-final\.js'

exists "Login UI" \
  'StoremanLoginUI|storeman-login-ui-final\.js'

exists "Session Guard" \
  'StoremanFinalSecurity|storeman-auth-final-guard\.js'

exists "Admin Management" \
  'admin-management|StoremanAdmin|USER_UPDATED'

exists "Role System" \
  'role.*admin|role.*owner|role.*manager|role'

exists "Permission System" \
  'permissions|hasPermission|can\('

exists "Active / Pending Status" \
  'status.*active|status.*pending|pending'

exists "Sign Out" \
  'signOut|logout|SIGNED_OUT'

echo
echo "--- AUTH LISTENERS ---"
grep -RniE \
'onAuthStateChange|SIGNED_IN|SIGNED_OUT|USER_UPDATED' \
--include='*.js' . 2>/dev/null \
| grep -vE '/backup[^/]*/|/app/src/main/assets/|/web/|/node_modules/|/\.git/' \
|| true

# ==============================================================
section "4. SUPABASE / DATABASE"

echo "--- Supabase client creation ---"
grep -RniE \
'createClient\(' \
--include='*.js' \
--include='*.html' \
. 2>/dev/null \
| grep -vE '/backup[^/]*/|/app/src/main/assets/|/web/|/node_modules/|/\.git/' \
|| true

echo
echo "--- Supabase global bridge ---"
grep -RniE \
'window\.(supabaseClient|storemanSupabase|SUPABASE_CLIENT)' \
--include='*.js' \
--include='*.html' \
. 2>/dev/null \
| grep -vE '/backup[^/]*/|/app/src/main/assets/|/web/|/node_modules/|/\.git/' \
|| true

echo
echo "--- Database tables referenced ---"
grep -RhoE \
"\.from\(['\"][A-Za-z0-9_-]+" \
--include='*.js' \
--include='*.html' \
. 2>/dev/null \
| sed -E "s/.*\.from\(['\"]//" \
| grep -vE '^(undefined|null)$' \
| sort -u

echo
echo "--- SQL CREATE TABLE statements ---"
grep -RniE \
'CREATE TABLE|CREATE TABLE IF NOT EXISTS' \
--include='*.sql' \
. 2>/dev/null \
| grep -vE '/backup[^/]*/|/node_modules/|/\.git/' \
|| true

# ==============================================================
section "5. FRONTEND UI / NAVIGATION"

echo "--- Navigation / menu items ---"
grep -RniE \
'(nav|sidebar|menu|tab|section).*?(dashboard|inventory|stock|sales|purchase|supplier|customer|warehouse|accounting|report|setting|admin)' \
--include='*.html' \
--include='*.js' \
. 2>/dev/null \
| grep -vE '/backup[^/]*/|/node_modules/|/\.git/' \
| head -120

echo
echo "--- Buttons / forms count ---"
echo "Buttons : $(grep -Roi '<button' --include='*.html' . 2>/dev/null | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' | wc -l)"
echo "Forms   : $(grep -Roi '<form'   --include='*.html' . 2>/dev/null | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' | wc -l)"
echo "Inputs  : $(grep -Roi '<input'  --include='*.html' . 2>/dev/null | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' | wc -l)"

# ==============================================================
section "6. AUTOMATION / BUSINESS LOGIC"

exists "Automatic Stock Calculation" \
  'stock.*=.*in.*-.*out|stock.*balance|calculate.*stock|stockBalance'

exists "Automatic Low Stock Detection" \
  'low.?stock|minimum.?stock|reorder.?level'

exists "Automatic Total Calculation" \
  'total.*amount|calculate.*total|quantity.*price|price.*quantity'

exists "Invoice Generation" \
  'generate.*invoice|invoice.*modal|invoice.*number|createInvoice'

exists "Receipt Generation" \
  'receipt.*modal|generate.*receipt|receiptData|r-total'

exists "Daily Report Automation" \
  'daily.*report|daily.*summary|movement.*summary'

exists "Email Sending" \
  'emailjs|sendEmail|send.*email'

exists "WhatsApp Sending" \
  'sendWhatsApp|whatsapp'

exists "LocalStorage Backup/Data" \
  'localStorage\.getItem|localStorage\.setItem'

exists "Cloud Database Operations" \
  '\.from\(.*\)\.(select|insert|update|delete|upsert)'

# ==============================================================
section "7. PWA / MOBILE"

exists "PWA Manifest" \
  'manifest\.json|rel=["'\'']manifest'

exists "Service Worker" \
  'serviceWorker|service-worker|sw\.js'

exists "Offline Support" \
  'offline|navigator\.onLine|serviceWorker'

exists "Installable PWA" \
  'beforeinstallprompt|appinstalled'

echo
echo "--- Manifest files ---"
find . -type f \( -name '*manifest*.json' -o -name 'manifest.json' \) \
  | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' || true

echo
echo "--- Service worker files ---"
find . -type f \( -iname '*service-worker*' -o -name 'sw.js' \) \
  | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' || true

# ==============================================================
section "8. ANDROID BUILD"

echo "--- Gradle files ---"
find . -type f \( -name 'build.gradle' -o -name 'build.gradle.kts' -o -name 'settings.gradle' -o -name 'gradle.properties' \) \
  | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' || true

echo
echo "--- Android workflow ---"
if [ -f ".github/workflows/android.yml" ]; then
  echo "  EXISTS: .github/workflows/android.yml"
  sed -n '1,220p' .github/workflows/android.yml
else
  echo "  MISSING: .github/workflows/android.yml"
fi

echo
echo "--- APK files ---"
find . -type f -name '*.apk' \
  | grep -vE '/backup[^/]*/|/node_modules/|/\.git/' || true

echo
echo "--- Android assets ---"
if [ -d "app/src/main/assets" ]; then
  find app/src/main/assets -maxdepth 2 -type f | sort
else
  echo "MISSING: app/src/main/assets"
fi

# ==============================================================
section "9. ACTIVE INDEX SCRIPT ARCHITECTURE"

echo "--- Active scripts ---"
grep -nE '<script[^>]+src=' index.html || true

echo
echo "--- Active auth/security/admin scripts ---"
grep -nE '<script[^>]+src=' index.html \
| grep -Ei 'auth|security|notification|admin|pending|email' || true

echo
echo "--- Legacy active Auth check ---"
if grep -nE '<script[^>]+src=["'\''][^"'\'']*(storeman-auth\.js|storeman-web-auth-gate\.js)' index.html; then
  echo "  WARNING: Legacy Auth script appears ACTIVE."
else
  echo "  OK: No legacy Auth script active in index.html."
fi

# ==============================================================
section "10. AUTH API ARCHITECTURE"

echo "--- Public window APIs ---"
grep -RniE \
'window\.(StoremanAuth|StoremanFinalAuth|StoremanAuthFinalFlow|StoremanWebAuth|StoremanLoginUI|StoremanFinalSecurity|StoremanAuthNotification)' \
--include='*.js' . 2>/dev/null \
| grep -vE '/backup[^/]*/|/app/src/main/assets/|/web/|/node_modules/|/\.git/' \
|| true

echo
echo "--- Remaining legacy StoremanAuth references ---"
grep -RniE \
'window\.StoremanAuth([^A-Za-z]|$)' \
--include='*.js' . 2>/dev/null \
| grep -vE '/backup[^/]*/|/app/src/main/assets/|/web/|/node_modules/|/\.git/' \
|| true

# ==============================================================
section "11. JAVASCRIPT SYNTAX"

if command -v node >/dev/null 2>&1; then
  FAIL=0

  while IFS= read -r f; do
    case "$f" in
      ./backup*|./app/src/main/assets/*|./web/*|./node_modules/*|./.git/*)
        continue
        ;;
    esac

    if ! node --check "$f" >/dev/null 2>&1; then
      echo "  FAIL : $f"
      FAIL=1
    fi
  done < <(find . -type f -name '*.js')

  if [ "$FAIL" -eq 0 ]; then
    echo "  ALL ACTIVE JS FILES: SYNTAX OK"
  else
    echo "  WARNING: JS syntax failures detected."
  fi
else
  echo "Node.js unavailable — syntax check skipped."
fi

# ==============================================================
section "12. GITHUB / GIT STATE"

if [ -d ".git" ]; then
  echo "--- Branch ---"
  git branch --show-current

  echo
  echo "--- Remote ---"
  git remote -v

  echo
  echo "--- Status ---"
  git status --short

  echo
  echo "--- Recent commits ---"
  git log --oneline -8
else
  echo "WARNING: Git repository not detected."
fi

# ==============================================================
section "13. FEATURE INVENTORY SUMMARY"

echo
echo "The following categories were scanned:"
echo
echo "  01 Dashboard"
echo "  02 Products / Materials"
echo "  03 Inventory"
echo "  04 Stock In"
echo "  05 Stock Out"
echo "  06 Stock Balance"
echo "  07 Low Stock Alerts"
echo "  08 Transaction History"
echo "  09 Warehouses"
echo "  10 Suppliers"
echo "  11 Customers"
echo "  12 Categories"
echo "  13 Units"
echo "  14 Purchasing"
echo "  15 Sales"
echo "  16 POS"
echo "  17 Invoicing"
echo "  18 Receipts"
echo "  19 Payments"
echo "  20 Expenses"
echo "  21 Accounting"
echo "  22 Reports"
echo "  23 Notifications"
echo "  24 Email"
echo "  25 WhatsApp"
echo "  26 Settings"
echo "  27 Authentication"
echo "  28 Roles"
echo "  29 Permissions"
echo "  30 Admin"
echo "  31 Pending Approval"
echo "  32 Supabase"
echo "  33 PWA"
echo "  34 Offline"
echo "  35 Android"
echo "  36 GitHub Actions"
echo

# ==============================================================
section "14. IMPORTANT DECISION"

echo "THIS AUDIT DID NOT MODIFY THE PROJECT."
echo
echo "No feature was added."
echo "No Auth code was added."
echo "No existing source was deleted."
echo "No Git push was performed."
echo "No APK build was started."
echo
echo "NEXT:"
echo "  1. Review this report."
echo "  2. Mark features as EXISTS / MISSING / PARTIAL / BROKEN."
echo "  3. Create ONE controlled Master Fix/Feature script."
echo "  4. Validate."
echo "  5. Git commit + push."
echo "  6. Build APK."
echo
echo "=============================================================="
echo "                 AUDIT COMPLETE"
echo "=============================================================="
echo
echo "REPORT FILE:"
echo "$ROOT/$REPORT"
echo

