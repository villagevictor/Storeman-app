#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/Storeman-app"
cd "$ROOT" || exit 1

STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="STOREMAN_COMPLETE_FEATURE_AUDIT_$STAMP.txt"

exec > >(tee "$REPORT") 2>&1

echo "=============================================================="
echo "          STOREMAN ERP COMPLETE FEATURE AUDIT"
echo "=============================================================="
echo "Date: $(date)"
echo "Project: $ROOT"
echo
echo "IMPORTANT:"
echo "This audit ONLY READS/scans the project."
echo "NO source file will be modified."
echo "NO feature will be added."
echo "NO feature will be deleted."
echo "NO git commit/push will be performed."
echo "NO APK build will be performed."
echo

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

exists_text() {
    local label="$1"
    shift
    local found=0

    for pattern in "$@"; do
        if grep -RniE "$pattern" \
            --include='*.html' \
            --include='*.js' \
            --include='*.css' \
            --include='*.json' \
            --include='*.xml' \
            --include='*.gradle' \
            . 2>/dev/null \
            | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/'; then
            found=1
            break
        fi
    done

    if [ "$found" -eq 1 ]; then
        printf "[EXISTS ] %s\n" "$label"
    else
        printf "[MISSING] %s\n" "$label"
    fi
}

file_exists() {
    local label="$1"
    shift

    for f in "$@"; do
        if [ -e "$f" ]; then
            printf "[EXISTS ] %s -> %s\n" "$label" "$f"
            return
        fi
    done

    printf "[MISSING] %s\n" "$label"
}

count_matches() {
    local pattern="$1"

    grep -RniE "$pattern" \
        --include='*.html' \
        --include='*.js' \
        --include='*.css' \
        --include='*.json' \
        . 2>/dev/null \
        | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/' \
        | wc -l
}

# ============================================================
# 1. PROJECT STRUCTURE
# ============================================================

echo
echo "=============================================================="
echo "1. PROJECT STRUCTURE"
echo "=============================================================="

echo
echo "--- Root files ---"
find . -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

echo
echo "--- Root directories ---"
find . -maxdepth 1 -type d -printf '%f/\n' 2>/dev/null | sort

echo
echo "--- HTML files ---"
find . -type f -name "*.html" \
    -not -path "./.git/*" \
    -not -path "./backup*/*" \
    | sort

echo
echo "--- JavaScript files ---"
find . -type f -name "*.js" \
    -not -path "./.git/*" \
    -not -path "./backup*/*" \
    | sort

# ============================================================
# 2. DASHBOARD
# ============================================================

echo
echo "=============================================================="
echo "2. DASHBOARD"
echo "=============================================================="

exists_text "Dashboard UI" \
    'dashboard|Dashboard|overview|Overview'

exists_text "Total Materials / Products" \
    'total.*material|total.*product|materials.*count|products.*count'

exists_text "Total Stock" \
    'total.*stock|stock.*total'

exists_text "Low Stock KPI" \
    'low.*stock|stock.*alert'

exists_text "Today's Actions / Movement" \
    'today.*action|today.*movement|daily.*movement'

# ============================================================
# 3. PRODUCTS / MATERIALS
# ============================================================

echo
echo "=============================================================="
echo "3. PRODUCTS / MATERIALS"
echo "=============================================================="

exists_text "Add Material" \
    'add.*material|new.*material|material.*form'

exists_text "Product Management" \
    'product.*management|manage.*product|products'

exists_text "Material Name" \
    'material.*name|product.*name'

exists_text "Unit" \
    'unit'

exists_text "Initial Stock" \
    'initial.*stock|opening.*stock'

exists_text "Minimum Stock" \
    'minimum.*stock|min.*stock|reorder'

exists_text "Price / Unit Price" \
    'unit.*price|selling.*price|purchase.*price'

# ============================================================
# 4. INVENTORY
# ============================================================

echo
echo "=============================================================="
echo "4. INVENTORY"
echo "=============================================================="

exists_text "Inventory" \
    'inventory|stock.*inventory|current.*stock'

exists_text "Stock Balance" \
    'stock.*balance|balance.*stock|current.*quantity'

exists_text "Stock Calculation Logic" \
    'stock.*in.*stock.*out|quantity.*in|quantity.*out|balance.*='

exists_text "Stock In" \
    'stock.*in|receive.*stock|receiv.*stock'

exists_text "Stock Out" \
    'stock.*out|issue.*stock|dispatch.*stock'

exists_text "Transaction History" \
    'transaction.*history|transactions|movement.*history'

exists_text "Reference Number" \
    'reference|ref.*number|transaction.*reference'

# ============================================================
# 5. LOW STOCK
# ============================================================

echo
echo "=============================================================="
echo "5. LOW STOCK / ALERTS"
echo "=============================================================="

exists_text "Automatic Low Stock Detection" \
    'low.*stock|stock.*minimum|min.*stock|reorder.*level'

exists_text "Low Stock Alert" \
    'low.*stock.*alert|stock.*alert|alert.*low'

exists_text "Low Stock Email" \
    'low.*stock.*email|email.*low.*stock'

# ============================================================
# 6. WAREHOUSES
# ============================================================

echo
echo "=============================================================="
echo "6. WAREHOUSES"
echo "=============================================================="

exists_text "Warehouse Management" \
    'warehouse'

exists_text "Add Warehouse" \
    'addWarehouse|add.*warehouse|save.*warehouse'

exists_text "Warehouse Selection" \
    'warehouse.*select|select.*warehouse|warehouse_id'

# ============================================================
# 7. SUPPLIERS
# ============================================================

echo
echo "=============================================================="
echo "7. SUPPLIERS"
echo "=============================================================="

exists_text "Supplier Management" \
    'supplier'

exists_text "Add Supplier" \
    'addSupplier|add.*supplier|save.*supplier'

exists_text "Supplier Phone" \
    'supplier.*phone|phone.*supplier'

exists_text "Supplier Email" \
    'supplier.*email|email.*supplier'

# ============================================================
# 8. CUSTOMERS
# ============================================================

echo
echo "=============================================================="
echo "8. CUSTOMERS"
echo "=============================================================="

exists_text "Customer Management" \
    'customer'

exists_text "Add Customer" \
    'addCustomer|add.*customer|save.*customer'

# ============================================================
# 9. CATEGORIES
# ============================================================

echo
echo "=============================================================="
echo "9. CATEGORIES"
echo "=============================================================="

exists_text "Categories" \
    'categor'

exists_text "Category Management" \
    'add.*categor|category.*management'

# ============================================================
# 10. PURCHASING
# ============================================================

echo
echo "=============================================================="
echo "10. PURCHASING"
echo "=============================================================="

exists_text "Purchasing" \
    'purchas|purchase.*order|purchase.*invoice'

exists_text "Purchase Order" \
    'purchase.*order|po.*number'

exists_text "Purchase History" \
    'purchase.*history'

# ============================================================
# 11. SALES
# ============================================================

echo
echo "=============================================================="
echo "11. SALES"
echo "=============================================================="

exists_text "Sales" \
    'sales|sale.*order|sales.*management'

exists_text "Sales Order" \
    'sales.*order|so.*number'

exists_text "Sales History" \
    'sales.*history'

# ============================================================
# 12. POS
# ============================================================

echo
echo "=============================================================="
echo "12. POS"
echo "=============================================================="

exists_text "POS" \
    'point.*of.*sale|\bPOS\b|pos.*system'

exists_text "Cart" \
    'cart|shopping.*cart'

exists_text "Checkout" \
    'checkout'

exists_text "POS Payment" \
    'pos.*payment|payment.*pos'

# ============================================================
# 13. INVOICING
# ============================================================

echo
echo "=============================================================="
echo "13. INVOICING"
echo "=============================================================="

exists_text "Invoice Generation" \
    'invoice|invoicing'

exists_text "Invoice Number" \
    'invoice.*number|invoice.*no'

exists_text "Invoice Total" \
    'invoice.*total|total.*invoice'

exists_text "Automatic Invoice Generation" \
    'generate.*invoice|create.*invoice|invoice.*generate'

# ============================================================
# 14. RECEIPTS
# ============================================================

echo
echo "=============================================================="
echo "14. RECEIPTS"
echo "=============================================================="

exists_text "Receipt Generation" \
    'receipt'

exists_text "Receipt Preview" \
    'receipt.*preview|receipt.*modal|receipt.*window'

exists_text "WhatsApp Receipt" \
    'whatsapp.*receipt|receipt.*whatsapp|sendWhatsAppReceipt'

# ============================================================
# 15. PAYMENTS
# ============================================================

echo
echo "=============================================================="
echo "15. PAYMENTS"
echo "=============================================================="

exists_text "Payments" \
    'payment'

exists_text "Payment Method" \
    'payment.*method|method.*payment'

exists_text "Payment Status" \
    'payment.*status|paid|unpaid'

# ============================================================
# 16. EXPENSES
# ============================================================

echo
echo "=============================================================="
echo "16. EXPENSES"
echo "=============================================================="

exists_text "Expenses" \
    'expense|expenses'

exists_text "Expense Amount" \
    'expense.*amount|amount.*expense'

exists_text "Expense Category" \
    'expense.*categor|category.*expense'

# ============================================================
# 17. ACCOUNTING
# ============================================================

echo
echo "=============================================================="
echo "17. ACCOUNTING"
echo "=============================================================="

exists_text "Accounting" \
    'accounting|accounts'

exists_text "Revenue" \
    'revenue'

exists_text "Profit" \
    'profit'

exists_text "Cost" \
    'cost|cost.*of.*goods'

exists_text "Balance / Financial Summary" \
    'financial.*summary|balance.*sheet|financial.*balance'

# ============================================================
# 18. REPORTS
# ============================================================

echo
echo "=============================================================="
echo "18. REPORTS"
echo "=============================================================="

exists_text "Reports" \
    'reports|report'

exists_text "Daily Report" \
    'daily.*report'

exists_text "Daily Movement Summary" \
    'daily.*movement.*summary|movement.*summary'

exists_text "Export / Download Report" \
    'export|download.*report|csv|pdf'

# ============================================================
# 19. EMAIL
# ============================================================

echo
echo "=============================================================="
echo "19. EMAIL"
echo "=============================================================="

exists_text "EmailJS" \
    'emailjs|email\.min\.js'

exists_text "Email Configuration" \
    'email.*config|service.*id|public.*key'

exists_text "Low Stock Email Template" \
    'low.*stock.*template|low.*stock.*email'

exists_text "Auth/Admin Notification Template" \
    'auth.*notification|admin.*notification'

exists_text "Daily Report Email" \
    'daily.*report.*email|send.*daily.*report'

# ============================================================
# 20. WHATSAPP
# ============================================================

echo
echo "=============================================================="
echo "20. WHATSAPP"
echo "=============================================================="

exists_text "WhatsApp Integration" \
    'whatsapp'

exists_text "WhatsApp Send Function" \
    'send.*whatsapp|whatsapp.*send'

# ============================================================
# 21. SETTINGS
# ============================================================

echo
echo "=============================================================="
echo "21. SETTINGS"
echo "=============================================================="

exists_text "Settings" \
    'settings|configuration'

exists_text "EmailJS Settings" \
    'emailjs.*settings|email.*configuration'

exists_text "Save Configuration" \
    'saveSettings|save.*configuration'

# ============================================================
# 22. AUTHENTICATION
# ============================================================

echo
echo "=============================================================="
echo "22. AUTHENTICATION"
echo "=============================================================="

exists_text "Supabase Auth" \
    'supabase.*auth|auth\.getUser|auth\.signIn|auth\.signOut'

exists_text "Login" \
    'login|sign.*in'

exists_text "Signup / Registration" \
    'signup|sign.*up|register|registration'

exists_text "Email Confirmation" \
    'email.*confirm|confirm.*email|email.*verification|verify.*email'

exists_text "Session Management" \
    'session|onAuthStateChange'

exists_text "Sign Out" \
    'signOut|signed.*out'

exists_text "Canonical StoremanFinalAuth" \
    'StoremanFinalAuth'

# ============================================================
# 23. AUTH FLOW
# ============================================================

echo
echo "=============================================================="
echo "23. AUTHORIZATION FLOW"
echo "=============================================================="

exists_text "Admin Approval" \
    'admin.*approval|approval.*admin|pending.*approval|approve.*user'

exists_text "Pending Account" \
    'pending'

exists_text "Active Account Status" \
    'status.*active|active.*status'

exists_text "Role" \
    'role'

exists_text "Permissions" \
    'permission'

exists_text "Admin Management" \
    'admin.*management|manage.*users'

exists_text "Admin Panel" \
    'admin.*panel|admin.*dashboard'

# ============================================================
# 24. SECURITY
# ============================================================

echo
echo "=============================================================="
echo "24. SECURITY"
echo "=============================================================="

exists_text "Security Guard" \
    'security.*guard|auth.*guard|FinalSecurity'

exists_text "Permission Check" \
    'can\(.*feature|permission.*check|permissions'

exists_text "RLS Mention / Policy" \
    'RLS|row.*level.*security'

exists_text "Auth State Listener" \
    'onAuthStateChange'

echo
echo "--- Auth listeners ---"
grep -RniE \
    'onAuthStateChange|SIGNED_IN|SIGNED_OUT|USER_UPDATED' \
    --include='*.js' . 2>/dev/null \
    | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/' \
    || true

# ============================================================
# 25. SUPABASE
# ============================================================

echo
echo "=============================================================="
echo "25. SUPABASE / CLOUD DATABASE"
echo "=============================================================="

exists_text "Supabase CDN / SDK" \
    'supabase-js|@supabase'

exists_text "Supabase createClient" \
    'createClient'

exists_text "Global Supabase Client" \
    'window\.supabaseClient|window\.storemanSupabase|window\.SUPABASE_CLIENT'

exists_text "Profiles Table" \
    "from\(['\"]profiles['\"]"

exists_text "Products / Materials Table" \
    "from\(['\"]products['\"]|from\(['\"]materials['\"]"

exists_text "Transactions Table" \
    "from\(['\"]transactions['\"]"

exists_text "Warehouses Table" \
    "from\(['\"]warehouses['\"]"

exists_text "Suppliers Table" \
    "from\(['\"]suppliers['\"]"

# ============================================================
# 26. PWA
# ============================================================

echo
echo "=============================================================="
echo "26. PWA"
echo "=============================================================="

file_exists "PWA Manifest" \
    "./manifest.json" \
    "./web/manifest.json" \
    "./www/manifest.json"

exists_text "Manifest Link" \
    'manifest\.json'

file_exists "Service Worker" \
    "./sw.js" \
    "./web/sw.js" \
    "./www/sw.js"

exists_text "Service Worker Registration" \
    'serviceWorker\.register|navigator\.serviceWorker'

exists_text "PWA Install Prompt" \
    'beforeinstallprompt|appinstalled'

# ============================================================
# 27. OFFLINE
# ============================================================

echo
echo "=============================================================="
echo "27. OFFLINE SUPPORT"
echo "=============================================================="

exists_text "LocalStorage" \
    'localStorage'

exists_text "IndexedDB" \
    'indexedDB|openDatabase'

exists_text "Offline Detection" \
    'navigator\.onLine|offline|online'

exists_text "Offline Queue / Sync" \
    'offline.*queue|sync.*queue|background.*sync'

# ============================================================
# 28. ANDROID
# ============================================================

echo
echo "=============================================================="
echo "28. ANDROID"
echo "=============================================================="

file_exists "Android Gradle" \
    "./app/build.gradle" \
    "./build.gradle"

file_exists "Android Settings" \
    "./settings.gradle"

file_exists "Android Manifest" \
    "./app/src/main/AndroidManifest.xml"

file_exists "Android Assets Index" \
    "./app/src/main/assets/index.html"

file_exists "Supabase Config Asset" \
    "./app/src/main/assets/supabase-config.json"

file_exists "EmailJS Asset" \
    "./app/src/main/assets/email.min.js"

file_exists "Android Workflow" \
    "./.github/workflows/android.yml"

exists_text "Android WebView" \
    'WebView|android\.webkit\.WebView'

# ============================================================
# 29. GITHUB ACTIONS
# ============================================================

echo
echo "=============================================================="
echo "29. GITHUB ACTIONS"
echo "=============================================================="

file_exists "GitHub Actions Workflow" \
    "./.github/workflows/android.yml"

if [ -f ".github/workflows/android.yml" ]; then
    echo
    echo "--- Android workflow ---"
    cat ".github/workflows/android.yml"
fi

# ============================================================
# 30. JAVASCRIPT ARCHITECTURE
# ============================================================

echo
echo "=============================================================="
echo "30. JAVASCRIPT ARCHITECTURE"
echo "=============================================================="

echo
echo "--- Active scripts in index.html ---"
grep -nE '<script[^>]+src=' index.html 2>/dev/null || true

echo
echo "--- Auth / Security / Admin active scripts ---"
grep -nE '<script[^>]+src=' index.html 2>/dev/null \
    | grep -Ei 'auth|security|notification|admin|pending|email' \
    || true

echo
echo "--- Canonical Auth exports ---"
grep -RniE \
    'window\.(StoremanFinalAuth|StoremanAuthFinalFlow|StoremanLoginUI|StoremanFinalSecurity|StoremanAuthNotification)' \
    --include='*.js' . 2>/dev/null \
    | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/' \
    || true

echo
echo "--- Legacy Auth exports/references ---"
grep -RniE \
    'window\.(StoremanAuth|storemanAuth|StoremanWebAuth)' \
    --include='*.js' . 2>/dev/null \
    | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/' \
    || true

# ============================================================
# 31. JAVASCRIPT SYNTAX
# ============================================================

echo
echo "=============================================================="
echo "31. JAVASCRIPT SYNTAX"
echo "=============================================================="

SYNTAX_FAIL=0

if command -v node >/dev/null 2>&1; then

    while IFS= read -r f; do

        case "$f" in
            ./backup*/*|./node_modules/*|./.git/*|./app/src/main/assets/*)
                continue
                ;;
        esac

        if node --check "$f" >/dev/null 2>&1; then
            echo "[OK    ] $f"
        else
            echo "[FAIL  ] $f"
            SYNTAX_FAIL=1
        fi

    done < <(find . -type f -name "*.js" | sort)

else

    echo "[SKIP  ] Node.js not installed."

fi

# ============================================================
# 32. HTML / FEATURE COUNTS
# ============================================================

echo
echo "=============================================================="
echo "32. PROJECT COUNTS"
echo "=============================================================="

echo "HTML files : $(find . -type f -name '*.html' -not -path './.git/*' | wc -l)"
echo "JS files   : $(find . -type f -name '*.js' -not -path './.git/*' | wc -l)"
echo "CSS files  : $(find . -type f -name '*.css' -not -path './.git/*' | wc -l)"
echo "JSON files : $(find . -type f -name '*.json' -not -path './.git/*' | wc -l)"
echo "Buttons    : $(grep -Roi '<button' --include='*.html' . 2>/dev/null | wc -l)"
echo "Inputs     : $(grep -Roi '<input' --include='*.html' . 2>/dev/null | wc -l)"
echo "Forms      : $(grep -Roi '<form' --include='*.html' . 2>/dev/null | wc -l)"
echo "onclick    : $(grep -Roi 'onclick=' --include='*.html' . 2>/dev/null | wc -l)"

# ============================================================
# 33. IMPORTANT FUNCTIONS
# ============================================================

echo
echo "=============================================================="
echo "33. IMPORTANT BUSINESS FUNCTIONS"
echo "=============================================================="

echo
echo "--- Inventory / Sales functions ---"

grep -RniE \
    'function (addMaterial|addWarehouse|addSupplier|processStockIn|processStockOut|addProduct|saveProduct|createInvoice|generateInvoice|generateReceipt|saveSettings|sendWhatsAppReceipt|sendDailyReport|sendLowStock|sendEmail)' \
    --include='*.js' --include='*.html' . 2>/dev/null \
    | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/' \
    || true

echo
echo "--- Auth functions ---"

grep -RniE \
    'function (login|signIn|signup|signUp|register|signOut|logout|approve|reject|createUser)' \
    --include='*.js' --include='*.html' . 2>/dev/null \
    | grep -vE '/backup[^/]*/|/node_modules/|/\.git/|/app/src/main/assets/' \
    || true

# ============================================================
# 34. BROKEN / POSSIBLY BROKEN REFERENCES
# ============================================================

echo
echo "=============================================================="
echo "34. POSSIBLE BROKEN REFERENCES"
echo "=============================================================="

echo
echo "--- Script files referenced by index.html but missing ---"

grep -oE '<script[^>]+src=["'\''][^"'\'']+["'\'']' index.html 2>/dev/null \
| sed -E 's/.*src=["'\'']([^"'\'']+)["'\''].*/\1/' \
| while IFS= read -r src; do

    case "$src" in
        http://*|https://*|//*)
            continue
            ;;
    esac

    if [ ! -f "$src" ]; then
        echo "[MISSING SCRIPT] $src"
    fi

done

echo
echo "--- CSS files referenced by index.html but missing ---"

grep -oE '<link[^>]+href=["'\''][^"'\'']+\.css[^"'\'']*["'\'']' index.html 2>/dev/null \
| sed -E 's/.*href=["'\'']([^"'\'']+\.css[^"'\'']*)["'\''].*/\1/' \
| while IFS= read -r css; do

    case "$css" in
        http://*|https://*|//*)
            continue
            ;;
    esac

    if [ ! -f "$css" ]; then
        echo "[MISSING CSS] $css"
    fi

done

# ============================================================
# 35. GIT STATE
# ============================================================

echo
echo "=============================================================="
echo "35. GIT STATE"
echo "=============================================================="

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then

    echo
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
    git log --oneline -10

else

    echo "Not a Git repository."

fi

# ============================================================
# 36. FINAL SUMMARY
# ============================================================

echo
echo "=============================================================="
echo "36. FINAL AUDIT SUMMARY"
echo "=============================================================="

if [ "$SYNTAX_FAIL" -eq 0 ]; then
    echo "JavaScript syntax: OK"
else
    echo "JavaScript syntax: WARNINGS/FAILURES FOUND"
fi

echo
echo "AUDIT STATUS:"
echo "  READ ONLY"
echo "  NO FEATURES ADDED"
echo "  NO FEATURES DELETED"
echo "  NO SOURCE MODIFIED"
echo "  NO GIT PUSH"
echo "  NO APK BUILD"

echo
echo "REPORT:"
echo "$ROOT/$REPORT"

echo
echo "=============================================================="
echo "AUDIT COMPLETE"
echo "=============================================================="

