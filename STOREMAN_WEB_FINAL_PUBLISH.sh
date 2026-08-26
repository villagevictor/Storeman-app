#!/data/data/com.termux/files/usr/bin/bash

set -e

echo
echo "============================================================"
echo "       STOREMAN FINAL WEB + AUTH PUBLISH"
echo "============================================================"
echo

cd ~/Storeman-app

# ------------------------------------------------------------
# 1. CHECK
# ------------------------------------------------------------

echo "[1/7] Checking project..."

test -d .git
test -f app/src/main/assets/index.html
test -f app/src/main/assets/storeman-auth.js
test -f .github/workflows/storeman-web.yml

echo "✓ Project OK"


# ------------------------------------------------------------
# 2. BACKUP CURRENT WEB
# ------------------------------------------------------------

echo
echo "[2/7] Backing up current web..."

mkdir -p backup_web_before_final_publish

if [ -f web/index.html ]; then
    cp web/index.html \
       backup_web_before_final_publish/index.html.$(date +%Y%m%d_%H%M%S)
fi

if [ -f web/storeman-auth.js ]; then
    cp web/storeman-auth.js \
       backup_web_before_final_publish/storeman-auth.js.$(date +%Y%m%d_%H%M%S)
fi

echo "✓ Backup complete"


# ------------------------------------------------------------
# 3. SYNC CURRENT AUTH VERSION
# ------------------------------------------------------------

echo
echo "[3/7] Publishing CURRENT Storeman Auth version..."

mkdir -p web

cp app/src/main/assets/index.html web/index.html
cp app/src/main/assets/storeman-auth.js web/storeman-auth.js

echo "✓ Current index.html copied"
echo "✓ Current storeman-auth.js copied"


# ------------------------------------------------------------
# 4. VERIFY AUTH IS CONNECTED
# ------------------------------------------------------------

echo
echo "[4/7] Verifying Auth connection..."

if ! grep -q 'storeman-auth.js' web/index.html; then
    echo
    echo "ERROR: index.html does not load storeman-auth.js"
    exit 1
fi

if ! grep -q 'storeman-login-page' web/storeman-auth.js; then
    echo
    echo "ERROR: Current Auth system was not found"
    exit 1
fi

if ! grep -q 'admin-users' web/storeman-auth.js; then
    echo
    echo "ERROR: Admin User Management was not found"
    exit 1
fi

if ! grep -q 'permissions' web/storeman-auth.js; then
    echo
    echo "ERROR: Permissions system was not found"
    exit 1
fi

echo "✓ Login system found"
echo "✓ Admin system found"
echo "✓ User management found"
echo "✓ Permissions found"


# ------------------------------------------------------------
# 5. SECURITY CHECK
# ------------------------------------------------------------

echo
echo "[5/7] Security check..."

if grep -RniE \
    'service_role|sb_secret_|SUPABASE_SERVICE_ROLE|service-role' \
    web/index.html web/storeman-auth.js 2>/dev/null
then
    echo
    echo "============================================================"
    echo "SECURITY ERROR"
    echo "============================================================"
    echo "Supabase service-role secret detected in browser files."
    echo "Publish stopped."
    echo "============================================================"
    exit 1
fi

echo "✓ Browser security check passed"


# ------------------------------------------------------------
# 6. SHOW FINAL WEB FILES
# ------------------------------------------------------------

echo
echo "[6/7] Final Web files..."

ls -lh \
    web/index.html \
    web/storeman-auth.js \
    web/manifest.json \
    web/sw.js 2>/dev/null || true

echo
echo "Git changes:"
git status --short


# ------------------------------------------------------------
# 7. COMMIT + PUSH
# ------------------------------------------------------------

echo
echo "[7/7] Commit + Push..."

git add web/index.html
git add web/storeman-auth.js

git commit -m "Publish Storeman final Auth and Admin web system" \
    || echo "No new commit required."

git push origin main

echo
echo "============================================================"
echo "       STOREMAN FINAL WEB PUSH COMPLETE"
echo "============================================================"
echo
echo "Chrome URL:"
echo "https://villagevictor.github.io/Storeman-app/"
echo
echo "============================================================"
echo
echo "IMPORTANT:"
echo "Wait for GitHub Actions / Pages deployment."
echo "Then open Chrome in Incognito mode for the first test."
echo "============================================================"
