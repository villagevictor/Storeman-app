#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/Storeman-app"
cd "$ROOT" || exit 1

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="backup_feature_completion_$STAMP"

echo "=================================================="
echo " STOREMAN FEATURE COMPLETION MASTER"
echo "=================================================="
echo "Time: $STAMP"
echo

echo "[1/9] Creating safety backup..."

mkdir -p "$BACKUP"

for f in \
  index.html \
  sw.js \
  manifest.json \
  storeman-auto-stock.js \
  storeman-auth-final.js \
  storeman-auth-flow-final.js \
  storeman-auth-final-guard.js \
  storeman-login-ui-final.js \
  storeman-pending-ui.js \
  storeman-admin-final.js
do
  [ -f "$f" ] && cp -p "$f" "$BACKUP/" || true
done

echo "Backup: $BACKUP"

echo
echo "[2/9] Checking current feature infrastructure..."

echo
echo "--- Core files ---"

for f in index.html storeman-auth-final.js storeman-auth-flow-final.js; do
  if [ -f "$f" ]; then
    echo "OK      $f"
  else
    echo "MISSING $f"
  fi
done

echo
echo "--- Existing PWA files ---"

[ -f manifest.json ] && echo "EXISTS  root manifest.json" || echo "MISSING root manifest.json"
[ -f sw.js ] && echo "EXISTS  root sw.js" || echo "MISSING root sw.js"

[ -f web/manifest.json ] && echo "EXISTS  web/manifest.json" || echo "MISSING web/manifest.json"
[ -f web/sw.js ] && echo "EXISTS  web/sw.js" || echo "MISSING web/sw.js"

echo
echo "[3/9] Creating canonical Storeman automatic stock engine..."

cat > storeman-auto-stock.js <<'JS'
(function () {
  "use strict";

  /*
   * STOREMAN AUTOMATIC STOCK ENGINE
   *
   * Formula:
   *
   * Current Stock =
   * Initial Stock + Total Stock IN - Total Stock OUT
   *
   * This module does NOT replace the existing ERP renderer.
   * It calculates stock safely from the existing localStorage
   * products_store and transactions_store structures.
   */

  function read(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
    } catch (_) {
      return fallback;
    }
  }

  function number(v) {
    const n = Number(v);
    return Number.isFinite(n) ? n : 0;
  }

  function idOf(item) {
    return String(
      item?.id ??
      item?.product_id ??
      item?.material_id ??
      item?.materialId ??
      item?.code ??
      item?.item_code ??
      item?.itemCode ??
      item?.name ??
      ""
    ).trim().toLowerCase();
  }

  function transactionType(t) {
    return String(
      t?.type ??
      t?.transaction_type ??
      t?.transactionType ??
      ""
    ).trim().toUpperCase();
  }

  function transactionQty(t) {
    return number(
      t?.quantity ??
      t?.qty ??
      t?.quantity_in ??
      t?.quantity_out ??
      0
    );
  }

  function calculateProduct(product, transactions) {
    const productId = idOf(product);

    const initial = number(
      product?.initial_stock ??
      product?.initialStock ??
      product?.opening_stock ??
      product?.openingStock ??
      product?.stock ??
      0
    );

    let stockIn = 0;
    let stockOut = 0;

    for (const t of transactions) {
      if (idOf(t) !== productId) continue;

      const type = transactionType(t);
      const qty = transactionQty(t);

      if (type === "IN" || type === "STOCK_IN" || type === "RECEIVE") {
        stockIn += qty;
      }

      if (type === "OUT" || type === "STOCK_OUT" || type === "ISSUE" || type === "SALE") {
        stockOut += qty;
      }
    }

    const current = initial + stockIn - stockOut;

    const reorder = number(
      product?.minimum_stock ??
      product?.minimumStock ??
      product?.reorder_level ??
      product?.reorderLevel ??
      product?.min_stock ??
      0
    );

    let status = "OK";

    if (current <= 0) {
      status = "OUT OF STOCK";
    } else if (current <= reorder) {
      status = "LOW STOCK";
    }

    return {
      initial,
      stockIn,
      stockOut,
      current,
      status
    };
  }

  function calculateAll() {
    const products = read("products_store", []);
    const transactions = read("transactions_store", []);

    if (!Array.isArray(products)) return [];

    return products.map(product => ({
      product,
      ...calculateProduct(product, Array.isArray(transactions) ? transactions : [])
    }));
  }

  function refresh() {
    const result = calculateAll();

    /*
     * Keep compatibility with existing Storeman renderer.
     * We expose calculated data without destroying existing records.
     */
    window.StoremanCalculatedStock = result;

    try {
      if (typeof window.renderUI === "function") {
        window.renderUI();
      }
    } catch (_) {}

    return result;
  }

  window.StoremanInventoryCalc = {
    calculate: calculateProduct,
    calculateAll,
    refresh
  };

  document.addEventListener("DOMContentLoaded", function () {
    try {
      refresh();
    } catch (_) {}
  });

})();
JS

echo "OK      storeman-auto-stock.js"

echo
echo "[4/9] Activating automatic stock engine in index.html..."

python - <<'PY'
from pathlib import Path
import re

p = Path("index.html")
text = p.read_text()

tag = '<script src="storeman-auto-stock.js"></script>'

if tag not in text:
    match = re.search(r'</head\s*>', text, flags=re.I)
    if match:
        text = text[:match.start()] + "  " + tag + "\n" + text[match.start():]
        print("ADDED   storeman-auto-stock.js")
    else:
        print("WARNING: </head> not found; stock engine tag not added")
else:
    print("OK      stock engine already active")

p.write_text(text)
PY

echo
echo "[5/9] Creating / normalizing PWA manifest..."

cat > manifest.json <<'JSON'
{
  "name": "Storeman ERP",
  "short_name": "Storeman",
  "description": "Inventory, Stock, Sales and Business Management ERP",
  "start_url": "./",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#0f172a",
  "orientation": "portrait-primary",
  "icons": []
}
JSON

echo "OK      manifest.json"

echo
echo "[6/9] Creating canonical Service Worker..."

cat > sw.js <<'JS'
const CACHE_NAME = "storeman-cache-v1";

const CORE_ASSETS = [
  "./",
  "./index.html",
  "./manifest.json"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(CORE_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(key => key !== CACHE_NAME)
          .map(key => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;

  event.respondWith(
    fetch(event.request)
      .then(response => {
        const copy = response.clone();

        caches.open(CACHE_NAME).then(cache => {
          cache.put(event.request, copy);
        });

        return response;
      })
      .catch(() =>
        caches.match(event.request).then(
          cached => cached || caches.match("./index.html")
        )
      )
  );
});
JS

echo "OK      sw.js"

echo
echo "[7/9] Activating PWA + Service Worker in index.html..."

python - <<'PY'
from pathlib import Path
import re

p = Path("index.html")
text = p.read_text()

manifest_tag = '<link rel="manifest" href="manifest.json">'

if manifest_tag not in text:
    match = re.search(r'</head\s*>', text, flags=re.I)
    if match:
        text = text[:match.start()] + "  " + manifest_tag + "\n" + text[match.start():]
        print("ADDED   manifest link")
    else:
        print("WARNING: </head> not found")
else:
    print("OK      manifest link already exists")

registration = r'''
<script>
(function () {
  "use strict";

  if ("serviceWorker" in navigator) {
    window.addEventListener("load", function () {
      navigator.serviceWorker.register("./sw.js")
        .then(function (registration) {
          console.log("[Storeman PWA] Service Worker active:",
            registration.scope);
        })
        .catch(function (error) {
          console.warn("[Storeman PWA] Service Worker registration failed:",
            error);
        });
    });
  }
})();
</script>
'''

if "navigator.serviceWorker.register" not in text:
    match = re.search(r'</body\s*>', text, flags=re.I)

    if match:
        text = text[:match.start()] + registration + "\n" + text[match.start():]
        print("ADDED   Service Worker registration")
    else:
        print("WARNING: </body> not found")
else:
    print("OK      Service Worker registration already exists")

p.write_text(text)
PY

echo
echo "[8/9] Protecting Auth architecture..."

echo "Auth policy:"
echo "  Canonical Auth = storeman-auth-final.js"
echo "  Legacy Auth scripts remain inactive"
echo "  No Auth rewrite"
echo "  No Auth deletion"
echo "  No blind StoremanAuth -> StoremanFinalAuth replacement"

if grep -q 'storeman-web-auth-gate.js' index.html; then
  echo "WARNING: legacy web auth gate is active!"
else
  echo "OK: legacy web auth gate is inactive."
fi

if grep -q 'storeman-auth.js' index.html; then
  echo "WARNING: legacy storeman-auth.js is active!"
else
  echo "OK: legacy storeman-auth.js is inactive."
fi

echo
echo "[9/9] Validation..."

FAIL=0

echo
echo "--- JavaScript syntax ---"

JS_FILES=(
  storeman-auto-stock.js
  storeman-auth-final.js
  storeman-auth-flow-final.js
  storeman-login-ui-final.js
  storeman-auth-final-guard.js
  storeman-pending-ui.js
  storeman-admin-final.js
  storeman-admin-management.js
  storeman-auth-notification.js
  storeman-final-security.js
  storeman-settings-security.js
)

if command -v node >/dev/null 2>&1; then
  for f in "${JS_FILES[@]}"; do
    if [ -f "$f" ]; then
      if node --check "$f" >/dev/null 2>&1; then
        echo "OK      $f"
      else
        echo "FAIL    $f"
        FAIL=1
      fi
    fi
  done
else
  echo "WARNING: Node.js not available."
fi

echo
echo "--- Required feature files ---"

for f in \
  index.html \
  storeman-auto-stock.js \
  manifest.json \
  sw.js \
  storeman-auth-final.js
do
  if [ -f "$f" ]; then
    echo "OK      $f"
  else
    echo "MISSING $f"
    FAIL=1
  fi
done

echo
echo "--- Active PWA configuration ---"

grep -nE 'manifest\.json|serviceWorker\.register|storeman-auto-stock' index.html || true

echo
echo "--- Active Auth scripts ---"

grep -nE '<script[^>]+src=' index.html |
grep -Ei 'auth|security|notification|admin|pending' || true

echo
echo "--- Git status ---"

git status --short

echo
echo "=================================================="

if [ "$FAIL" -eq 0 ]; then
  echo " FEATURE COMPLETION PREPARATION PASSED"
  echo
  echo "Added/activated:"
  echo "  1. Automatic Stock Calculation Engine"
  echo "  2. PWA Manifest"
  echo "  3. Service Worker"
  echo "  4. Offline fallback infrastructure"
  echo
  echo "Auth was NOT rewritten."
  echo "Legacy source files were NOT deleted."
  echo
  echo "Backup:"
  echo "  $BACKUP"
else
  echo " FEATURE COMPLETION HAS VALIDATION ERRORS"
  echo " DO NOT PUSH OR BUILD YET."
  echo "Backup:"
  echo "  $BACKUP"
fi

echo "=================================================="
