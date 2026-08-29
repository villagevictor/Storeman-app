#!/data/data/com.termux/files/usr/bin/bash

set -u

echo "=================================================="
echo " STOREMAN AUTH ARCHITECTURE CLEANUP MASTER"
echo "=================================================="

ROOT="$HOME/Storeman-app"
cd "$ROOT" || exit 1

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="backup_auth_arch_cleanup_$STAMP"

echo
echo "[1/8] Creating safety backup..."
mkdir -p "$BACKUP"

cp -f index.html "$BACKUP/" 2>/dev/null || true

for f in \
  storeman-auth.js \
  storeman-auth-final.js \
  storeman-auth-flow-final.js \
  storeman-login-ui-final.js \
  storeman-web-auth-gate.js \
  storeman-auth-final-guard.js \
  storeman-pending-ui.js \
  storeman-admin-final.js \
  storeman-admin-management.js \
  storeman-auth-notification.js \
  storeman-admin-notification.js \
  storeman-final-security.js \
  storeman-security.js \
  storeman-settings-security.js \
  storeman-email-config.js
do
  [ -f "$f" ] && cp -f "$f" "$BACKUP/"
done

echo "Backup created: $BACKUP"

echo
echo "[2/8] Verifying required final modules..."

REQUIRED=(
  "storeman-auth-final.js"
  "storeman-auth-flow-final.js"
  "storeman-login-ui-final.js"
  "storeman-auth-final-guard.js"
  "storeman-pending-ui.js"
  "storeman-admin-final.js"
)

MISSING=0

for f in "${REQUIRED[@]}"; do
  if [ -f "$f" ]; then
    echo "  OK  $f"
  else
    echo "  MISSING  $f"
    MISSING=1
  fi
done

if [ "$MISSING" -ne 0 ]; then
  echo
  echo "STOP: Required final Auth module is missing."
  echo "Nothing was changed."
  exit 1
fi

echo
echo "[3/8] Checking index.html..."

if [ ! -f index.html ]; then
  echo "STOP: index.html not found."
  exit 1
fi

echo "index.html found."

echo
echo "[4/8] Removing duplicate ACTIVE legacy Auth script tags..."

python - <<'PY'
from pathlib import Path
import re

p = Path("index.html")
text = p.read_text()

legacy = [
    "storeman-auth.js",
    "storeman-web-auth-gate.js"
]

for name in legacy:
    pattern = rf'^[ \t]*<script\b[^>]*src=["\'][^"\']*{re.escape(name)}(?:\?[^"\']*)?["\'][^>]*>\s*</script>[ \t]*\n?'
    text, n = re.subn(pattern, "", text, flags=re.I | re.M)

    if n:
        print(f"  REMOVED ACTIVE TAG: {name}")
    else:
        print(f"  NOT PRESENT: {name}")

p.write_text(text)
PY

echo
echo "[5/8] Removing accidental literal '\\n' from script line..."

python - <<'PY'
from pathlib import Path

p = Path("index.html")
text = p.read_text()

text = text.replace(
    '</script>\\n  <script',
    '</script>\n  <script'
)

text = text.replace(
    '</script>\\n<script',
    '</script>\n<script'
)

p.write_text(text)

print("  Normalized literal newline escapes.")
PY

echo
echo "[6/8] Checking active Auth architecture..."

echo
echo "--- ACTIVE AUTH SCRIPT TAGS ---"
grep -nE '<script[^>]+src=' index.html | \
grep -E 'auth|security|notification|admin|pending' || true

echo
echo "--- ACTIVE AUTH PUBLIC APIS ---"
grep -RniE \
'window\.(StoremanAuth|StoremanFinalAuth|StoremanAuthFinalFlow|StoremanWebAuth|StoremanLoginUI|StoremanFinalSecurity)' \
--include='*.js' . \
| grep -v '/backup/' \
| grep -v 'app/src/main/assets/' \
| grep -v 'web/' \
|| true

echo
echo "--- ACTIVE AUTH LISTENERS ---"
grep -RniE \
'onAuthStateChange|SIGNED_IN|SIGNED_OUT|USER_UPDATED' \
--include='*.js' . \
| grep -v '/backup/' \
| grep -v 'app/src/main/assets/' \
| grep -v 'web/' \
|| true

echo
echo "[7/8] Syntax checking JavaScript..."

JS_FILES=(
  storeman-auth-final.js
  storeman-auth-flow-final.js
  storeman-login-ui-final.js
  storeman-auth-final-guard.js
  storeman-pending-ui.js
  storeman-admin-final.js
  storeman-admin-management.js
  storeman-auth-notification.js
  storeman-admin-notification.js
  storeman-final-security.js
  storeman-settings-security.js
)

SYNTAX_FAIL=0

if command -v node >/dev/null 2>&1; then
  for f in "${JS_FILES[@]}"; do
    if [ -f "$f" ]; then
      if node --check "$f" >/dev/null 2>&1; then
        echo "  OK  $f"
      else
        echo "  FAIL  $f"
        SYNTAX_FAIL=1
      fi
    fi
  done
else
  echo "Node.js not available; syntax check skipped."
fi

echo
echo "[8/8] Final architecture report..."

echo
echo "=================================================="
echo " CANONICAL AUTH CORE"
echo "=================================================="
echo " storeman-auth-final.js"

echo
echo "=================================================="
echo " AUTH FLOW"
echo "=================================================="
echo " storeman-auth-flow-final.js"

echo
echo "=================================================="
echo " LOGIN UI"
echo "=================================================="
echo " storeman-login-ui-final.js"

echo
echo "=================================================="
echo " SESSION / SECURITY GUARD"
echo "=================================================="
echo " storeman-auth-final-guard.js"
echo " storeman-final-security.js"

echo
echo "=================================================="
echo " PENDING / ADMIN"
echo "=================================================="
echo " storeman-pending-ui.js"
echo " storeman-admin-final.js"
echo " storeman-admin-management.js"

echo
echo "=================================================="
echo " NOTIFICATION"
echo "=================================================="
echo " storeman-auth-notification.js"
echo " storeman-admin-notification.js"

echo
echo "=================================================="
echo " LEGACY ISOLATED"
echo "=================================================="
echo " storeman-auth.js"
echo " storeman-web-auth-gate.js"

echo
echo "=================================================="
echo " RESULT"
echo "=================================================="

if [ "$SYNTAX_FAIL" -eq 0 ]; then
  echo " AUTH ARCHITECTURE CLEANUP COMPLETED."
else
  echo " CLEANUP COMPLETED WITH JS SYNTAX WARNINGS."
fi

echo
echo "Backup:"
echo "$BACKUP"

echo
echo "IMPORTANT:"
echo "No legacy source file was deleted."
echo "Only ACTIVE duplicate script tags were removed from index.html."
echo "=================================================="
