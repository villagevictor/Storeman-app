#!/data/data/com.termux/files/usr/bin/bash

set -e

echo
echo "============================================================"
echo "        STOREMAN WEB PUBLISH MASTER"
echo "============================================================"
echo

# ------------------------------------------------------------
# 1. PROJECT CHECK
# ------------------------------------------------------------

cd ~/Storeman-app

echo "[1/8] Checking project..."

if [ ! -d .git ]; then
    echo "ERROR: Not a Git repository."
    exit 1
fi

BRANCH="$(git branch --show-current)"

if [ "$BRANCH" != "main" ]; then
    echo "ERROR: Current branch is: $BRANCH"
    echo "Expected branch: main"
    exit 1
fi

echo "OK: branch = $BRANCH"


# ------------------------------------------------------------
# 2. REMOTE CHECK
# ------------------------------------------------------------

echo
echo "[2/8] Checking GitHub remote..."

REMOTE="$(git remote get-url origin 2>/dev/null || true)"

if [ -z "$REMOTE" ]; then
    echo "ERROR: origin remote not found."
    exit 1
fi

echo "Remote:"
echo "$REMOTE"


# ------------------------------------------------------------
# 3. REQUIRED FILE CHECK
# ------------------------------------------------------------

echo
echo "[3/8] Checking Storeman web files..."

if [ ! -f "app/src/main/assets/index.html" ]; then
    echo "ERROR: app/src/main/assets/index.html not found."
    exit 1
fi

if [ ! -f "app/src/main/assets/storeman-auth.js" ]; then
    echo "ERROR: app/src/main/assets/storeman-auth.js not found."
    exit 1
fi

if [ ! -f ".github/workflows/storeman-web.yml" ]; then
    echo "ERROR: storeman-web.yml not found."
    exit 1
fi

echo "OK: index.html"
echo "OK: storeman-auth.js"
echo "OK: storeman-web.yml"


# ------------------------------------------------------------
# 4. BACKUP CURRENT WEB INDEX
# ------------------------------------------------------------

echo
echo "[4/8] Creating safety backup..."

if [ -f "index.html" ]; then
    BACKUP="index.html.before-web-publish-$(date +%Y%m%d_%H%M%S)"
    cp index.html "$BACKUP"
    echo "Backup created: $BACKUP"
fi


# ------------------------------------------------------------
# 5. SYNC WEB SOURCE
# ------------------------------------------------------------

echo
echo "[5/8] Synchronizing Web files..."

cp app/src/main/assets/index.html index.html
cp app/src/main/assets/storeman-auth.js storeman-auth.js

echo "Web index synchronized."
echo "Auth JS synchronized."


# ------------------------------------------------------------
# 6. SECURITY CHECK
# ------------------------------------------------------------

echo
echo "[6/8] Running browser security check..."

WEB_FILES="index.html storeman-auth.js"

if grep -RniE \
    "service_role|sb_secret_|SUPABASE_SERVICE_ROLE|service-role" \
    $WEB_FILES 2>/dev/null; then

    echo
    echo "============================================================"
    echo "SECURITY ERROR"
    echo "============================================================"
    echo "A Supabase service-role/secret key was detected"
    echo "inside browser files."
    echo
    echo "Publish STOPPED."
    echo "Never put a service-role key in a browser application."
    echo "============================================================"

    exit 1
fi

echo "Security check passed."


# ------------------------------------------------------------
# 7. SHOW WHAT WILL BE PUSHED
# ------------------------------------------------------------

echo
echo "[7/8] Preparing Git commit..."

git add index.html
git add storeman-auth.js
git add .github/workflows/storeman-web.yml

echo
echo "Files staged:"
git diff --cached --name-status

echo
echo "Untracked files NOT included:"
git status --short


# ------------------------------------------------------------
# 8. COMMIT + PUSH
# ------------------------------------------------------------

echo
echo "[8/8] Committing and pushing..."

if git diff --cached --quiet; then
    echo "No web changes detected."
else
    git commit -m "Publish Storeman web auth and admin system"
fi

git push origin main

echo
echo "============================================================"
echo "             STOREMAN WEB PUBLISHED"
echo "============================================================"
echo
echo "GitHub:"
echo "https://github.com/villagevictor/Storeman-app"
echo
echo "Storeman Chrome URL:"
echo "https://villagevictor.github.io/Storeman-app/"
echo
echo "============================================================"
echo
echo "IMPORTANT:"
echo "GitHub Pages deployment may take a few minutes."
echo
echo "Open the URL in Chrome after the Pages workflow finishes."
echo "============================================================"
