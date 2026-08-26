#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "============================================================"
echo "              STOREMAN MASTER PUBLISHER"
echo "============================================================"

PROJECT="$HOME/Storeman-app"
ANDROID_INDEX="$PROJECT/app/src/main/assets/index.html"
WEB_DIR="$PROJECT/web"
WEB_INDEX="$WEB_DIR/index.html"

cd "$PROJECT"

echo
echo "===== 1. CHECK PROJECT ====="

if [ ! -f "$ANDROID_INDEX" ]; then
    echo "❌ Android index.html not found:"
    echo "$ANDROID_INDEX"
    exit 1
fi

echo "✓ Android Storeman core found"
echo "✓ Size: $(wc -c < "$ANDROID_INDEX") bytes"

echo
echo "===== 2. CREATE WEB/PWA ====="

mkdir -p "$WEB_DIR"

cp "$ANDROID_INDEX" "$WEB_INDEX"

echo "✓ Web copy created"

echo
echo "===== 3. VERIFY STOREMAN FEATURES ====="

check() {
    NAME="$1"
    PATTERN="$2"

    if grep -Eiq "$PATTERN" "$WEB_INDEX"; then
        echo "✓ $NAME"
    else
        echo "✗ $NAME"
    fi
}

check "Warehouse" \
'addWarehouse|localWarehouses|warehouses_store'

check "Supplier" \
'addSupplier|localSuppliers|suppliers_store'

check "Customer" \
'so-customer|customer_name'

check "Invoice" \
'OFFICIAL INVOICE|activeReceiptData|r-inv'

check "Supabase" \
'supabaseClient|supabase\.createClient|supabaseUrl'

check "Cloud Backup" \
'cloudBackupData|store_backups'

check "Cloud Restore" \
'cloudRestoreData|store_backups'

check "WhatsApp" \
'sendWhatsAppReceipt|wa\.me'

check "Stock In" \
'processStockIn|type.*IN'

check "Stock Out" \
'type.*OUT'

check "Daily Report" \
'sendDailyReport|daily-report'

check "EmailJS" \
'emailjs|initEmailJS'

echo
echo "===== 4. CREATE PWA FILES ====="

cat > "$WEB_DIR/manifest.json" <<'EOF'
{
  "name": "Storeman Inventory",
  "short_name": "Storeman",
  "description": "Storeman Inventory and ERP Management System",
  "start_url": "./index.html",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#0f2b48",
  "orientation": "portrait",
  "icons": []
}
EOF

cat > "$WEB_DIR/sw.js" <<'EOF'
const CACHE_NAME = "storeman-v1";

const APP_FILES = [
  "./",
  "./index.html",
  "./manifest.json"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(APP_FILES))
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", event => {
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});
EOF

cat > "$WEB_DIR/404.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Storeman</title>
<meta http-equiv="refresh" content="0; url=./index.html">
</head>
<body>
Opening Storeman...
</body>
</html>
EOF

echo "✓ manifest.json"
echo "✓ sw.js"
echo "✓ 404.html"

echo
echo "===== 5. ADD PWA REGISTRATION ====="

python3 - <<'PY'
from pathlib import Path

p = Path("web/index.html")
s = p.read_text()

if "manifest.json" not in s:
    s = s.replace(
        "</head>",
        """<link rel="manifest" href="./manifest.json">
<meta name="theme-color" content="#0f2b48">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
</head>"""
    )

if "serviceWorker.register" not in s:
    s = s.replace(
        "</body>",
        """<script>
if ("serviceWorker" in navigator) {
    window.addEventListener("load", () => {
        navigator.serviceWorker.register("./sw.js")
            .then(() => console.log("Storeman PWA Service Worker Ready"))
            .catch(err => console.log("PWA Service Worker Error:", err));
    });
}
</script>
</body>"""
    )

p.write_text(s)
PY

echo "✓ PWA integration complete"

echo
echo "===== 6. CREATE WEB WORKFLOW ====="

mkdir -p .github/workflows

cat > .github/workflows/storeman-web.yml <<'EOF'
name: Publish Storeman Web PWA

on:
  push:
    branches:
      - main
      - master

  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:

  build:
    runs-on: ubuntu-latest

    steps:

      - name: Checkout
        uses: actions/checkout@v4

      - name: Prepare Storeman Web
        run: |
          mkdir -p public
          cp -r web/. public/

      - name: Upload Pages Artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: public

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    runs-on: ubuntu-latest

    needs: build

    steps:

      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
EOF

echo "✓ GitHub Pages workflow created"

echo
echo "===== 7. CHECK GIT ====="

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ This is not a Git repository"
    exit 1
fi

REMOTE="$(git remote get-url origin 2>/dev/null || true)"

if [ -z "$REMOTE" ]; then
    echo "❌ GitHub remote 'origin' not found."
    echo
    echo "Add your GitHub repository first:"
    echo "git remote add origin YOUR_GITHUB_REPOSITORY"
    exit 1
fi

echo "✓ GitHub remote found:"
echo "$REMOTE"

echo
echo "===== 8. DETECT GITHUB REPOSITORY ====="

REPO_PATH=""

if echo "$REMOTE" | grep -qE 'github.com[:/]'; then

    REPO_PATH=$(echo "$REMOTE" \
        | sed -E 's#.*github.com[:/]##' \
        | sed -E 's#\.git$##')

fi

if [ -z "$REPO_PATH" ]; then
    echo "❌ Could not detect GitHub owner/repository"
    exit 1
fi

OWNER="$(echo "$REPO_PATH" | cut -d/ -f1)"
REPO="$(echo "$REPO_PATH" | cut -d/ -f2)"

echo "✓ Owner: $OWNER"
echo "✓ Repository: $REPO"

PAGES_URL="https://${OWNER}.github.io/${REPO}/"

echo
echo "===== 9. GIT STATUS ====="

git status --short

echo
echo "===== 10. SAVE CHANGES ====="

git add web .github/workflows/storeman-web.yml

if git diff --cached --quiet; then
    echo "✓ No new changes to commit"
else
    git commit -m "feat: publish Storeman ERP Web PWA"
    echo "✓ Commit created"
fi

echo
echo "===== 11. PUSH TO GITHUB ====="

BRANCH="$(git branch --show-current)"

if [ -z "$BRANCH" ]; then
    BRANCH="main"
fi

echo "Branch: $BRANCH"

git push -u origin "$BRANCH"

echo
echo "============================================================"
echo "                 STOREMAN PUBLISHED"
echo "============================================================"

echo
echo "GitHub Repository:"
echo "https://github.com/$REPO_PATH"

echo
echo "Storeman Web/PWA:"
echo "$PAGES_URL"

echo
echo "============================================================"
echo "IMPORTANT:"
echo "GitHub Actions may need 1-3 minutes to finish deployment."
echo "Then open:"
echo "$PAGES_URL"
echo "============================================================"
