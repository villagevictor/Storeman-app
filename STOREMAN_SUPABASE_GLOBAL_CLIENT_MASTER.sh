#!/data/data/com.termux/files/usr/bin/bash

set -u

APP="$HOME/Storeman-app"
cd "$APP" || exit 1

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="backup/supabase_global_client_$STAMP"

echo "============================================================"
echo " STOREMAN SUPABASE GLOBAL CLIENT MASTER FIX"
echo "============================================================"
echo "APP: $APP"
echo "TIME: $STAMP"
echo "============================================================"

# ------------------------------------------------------------
# 1. SAFETY BACKUP
# ------------------------------------------------------------

echo
echo "===== 1. SAFETY BACKUP ====="

mkdir -p "$BACKUP"

cp -f index.html "$BACKUP/index.html.before-fix" 2>/dev/null || true

for f in \
  storeman-auth-final.js \
  storeman-auth-flow-final.js \
  storeman-web-auth-gate.js \
  storeman-login-ui-final.js \
  storeman-admin-final.js \
  storeman-admin-management.js \
  storeman-auth-final.css \
  storeman-pending-ui.js
do
  if [ -f "$f" ]; then
    cp -f "$f" "$BACKUP/$f.before-fix"
  fi
done

echo "Backup created: $BACKUP"

# ------------------------------------------------------------
# 2. CHECK SUPABASE LIBRARY
# ------------------------------------------------------------

echo
echo "===== 2. CHECK SUPABASE LIBRARY ====="

if ! grep -q '@supabase/supabase-js@2' index.html; then
  echo "ERROR: Supabase JS library was not found."
  exit 1
fi

echo "Supabase JS library: FOUND"

# ------------------------------------------------------------
# 3. CHECK SUPABASE CLIENT
# ------------------------------------------------------------

echo
echo "===== 3. CHECK SUPABASE CLIENT ====="

if ! grep -q 'supabase.createClient' index.html; then
  echo "ERROR: supabase.createClient was not found."
  exit 1
fi

echo "Supabase createClient: FOUND"

# ------------------------------------------------------------
# 4. FIX CLIENT SCOPE
#
# IMPORTANT:
# Keep the existing local variable because the original app
# uses supabaseClient throughout index.html.
#
# ALSO expose the SAME client globally so all auth/security
# modules can use window.supabaseClient.
# ------------------------------------------------------------

echo
echo "===== 4. GLOBAL SUPABASE CLIENT BRIDGE ====="

python - <<'PY'
from pathlib import Path

p = Path("index.html")
s = p.read_text(encoding="utf-8")

old = """const supabaseClient = supabase.createClient(supabaseUrl, supabaseKey);"""

new = """const supabaseClient = supabase.createClient(supabaseUrl, supabaseKey);

// STOREMAN GLOBAL SUPABASE BRIDGE
// The same client is exposed globally for Auth, Security,
// Admin, Permissions and multi-device modules.
window.supabaseClient = supabaseClient;
window.storemanSupabase = supabaseClient;
window.SUPABASE_CLIENT = supabaseClient;"""

if old in s:
    s = s.replace(old, new, 1)
    p.write_text(s, encoding="utf-8")
    print("GLOBAL SUPABASE BRIDGE: ADDED")
elif "window.supabaseClient = supabaseClient;" in s:
    print("GLOBAL SUPABASE BRIDGE: ALREADY PRESENT")
else:
    print("ERROR: Expected Supabase client declaration was not found.")
    raise SystemExit(1)
PY

# ------------------------------------------------------------
# 5. VERIFY CLIENT BRIDGE
# ------------------------------------------------------------

echo
echo "===== 5. VERIFY BRIDGE ====="

grep -n -A8 -B4 \
  "window.supabaseClient = supabaseClient" \
  index.html || {
    echo "ERROR: Global Supabase bridge verification failed."
    exit 1
  }

# ------------------------------------------------------------
# 6. CHECK AUTH MODULES
# ------------------------------------------------------------

echo
echo "===== 6. CHECK AUTH MODULES ====="

for f in \
  storeman-auth-final.js \
  storeman-auth-flow-final.js \
  storeman-web-auth-gate.js \
  storeman-login-ui-final.js
do
  if [ -f "$f" ]; then
    echo "FOUND: $f"
  fi
done

# ------------------------------------------------------------
# 7. JS SYNTAX CHECK
# ------------------------------------------------------------

echo
echo "===== 7. JAVASCRIPT SYNTAX CHECK ====="

if command -v node >/dev/null 2>&1; then

  for f in \
    storeman-auth-final.js \
    storeman-auth-flow-final.js \
    storeman-web-auth-gate.js \
    storeman-login-ui-final.js \
    storeman-admin-final.js \
    storeman-admin-management.js \
    storeman-pending-ui.js
  do
    if [ -f "$f" ]; then
      node --check "$f" >/dev/null 2>&1

      if [ $? -eq 0 ]; then
        echo "OK: $f"
      else
        echo "WARNING: syntax check failed for $f"
      fi
    fi
  done

else
  echo "Node.js not available. Skipping JS syntax check."
fi

# ------------------------------------------------------------
# 8. VERIFY AUTH MODULE EXPECTATION
# ------------------------------------------------------------

echo
echo "===== 8. VERIFY AUTH CLIENT EXPECTATION ====="

grep -RniE \
  "window\.supabaseClient|window\.storemanSupabase|window\.SUPABASE_CLIENT" \
  storeman-auth-final.js \
  storeman-auth-flow-final.js \
  storeman-web-auth-gate.js \
  storeman-login-ui-final.js \
  2>/dev/null | head -n 40

# ------------------------------------------------------------
# 9. CHECK GIT DIFF
# ------------------------------------------------------------

echo
echo "===== 9. GIT DIFF ====="

git diff -- index.html

# ------------------------------------------------------------
# 10. COMMIT ONLY THE REQUIRED FIX
# ------------------------------------------------------------

echo
echo "===== 10. COMMIT ====="

git add index.html

if git diff --cached --quiet; then
  echo "No new index.html change to commit."
else
  git commit -m "Fix global Supabase client for web authentication"
fi

# ------------------------------------------------------------
# 11. PUSH
# ------------------------------------------------------------

echo
echo "===== 11. PUSH TO GITHUB ====="

BRANCH="$(git branch --show-current)"

if [ -z "$BRANCH" ]; then
  BRANCH="main"
fi

echo "Branch: $BRANCH"

git push origin "$BRANCH"

if [ $? -ne 0 ]; then
  echo
  echo "ERROR: Git push failed."
  echo "The local fix is still saved."
  exit 1
fi

# ------------------------------------------------------------
# 12. FINAL STATUS
# ------------------------------------------------------------

echo
echo "============================================================"
echo " SUCCESS"
echo "============================================================"

echo
echo "Supabase global client:"
echo "  window.supabaseClient"

echo
echo "Storeman Supabase alias:"
echo "  window.storemanSupabase"

echo
echo "Auth flow:"
echo "  Sign In"
echo "  Sign Up"
echo "  Supabase Auth"
echo "  Pending"
echo "  Admin Approval"
echo "  Active"
echo "  Permissions"
echo "  Dashboard"

echo
echo "Backup:"
echo "  $BACKUP"

echo
echo "GitHub:"
git log -1 --oneline

echo
echo "============================================================"
echo " IMPORTANT"
echo "============================================================"
echo "GitHub Pages may need a short time to publish the new commit."
echo "After publishing, open the site in a PRIVATE/INCOGNITO tab"
echo "or clear the browser cache before testing."
echo "============================================================"

