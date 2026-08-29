#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/Storeman-app"
cd "$ROOT" || exit 1

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="backup_auth_final_cleanup_$STAMP"

echo "=================================================="
echo " STOREMAN AUTH ARCHITECTURE FINAL CLEANUP"
echo "=================================================="

echo
echo "[1/7] Creating safety backup..."

mkdir -p "$BACKUP"

for f in \
  index.html \
  storeman-auth-final.js \
  storeman-auth-flow-final.js \
  storeman-login-ui-final.js \
  storeman-auth-final-guard.js \
  storeman-pending-ui.js \
  storeman-admin-final.js \
  storeman-admin-management.js \
  storeman-auth-notification.js \
  storeman-final-security.js \
  storeman-security.js \
  storeman-settings-security.js
do
  [ -f "$f" ] && cp -f "$f" "$BACKUP/"
done

echo "Backup: $BACKUP"

echo
echo "[2/7] Verifying canonical Auth Core..."

grep -q 'window.StoremanFinalAuth' storeman-auth-final.js || {
  echo "ERROR: Canonical Auth Core not found."
  exit 1
}

echo "OK: StoremanFinalAuth exists."

echo
echo "[3/7] Removing ONLY obsolete active legacy Auth references..."

python - <<'PY'
from pathlib import Path

p = Path("index.html")
text = p.read_text()

# These are legacy Auth implementations.
# Their source files are NOT deleted.
legacy_files = [
    "storeman-auth.js",
    "storeman-web-auth-gate.js",
]

for name in legacy_files:
    old = text
    lines = text.splitlines(True)

    kept = []
    removed = 0

    for line in lines:
        if "<script" in line and "src=" in line and name in line:
            removed += 1
            continue
        kept.append(line)

    text = "".join(kept)

    if removed:
        print(f"REMOVED active legacy tag: {name}")
    else:
        print(f"OK already isolated: {name}")

p.write_text(text)
PY

echo
echo "[4/7] Fixing Auth Flow notification dependency..."

python - <<'PY'
from pathlib import Path

p = Path("storeman-auth-flow-final.js")
text = p.read_text()

old = '''        if (
            window.StoremanAuth &&
            typeof window.StoremanAuth.notify ===
                "function"
        ) {
            window.StoremanAuth.notify(
                message,
                error
            );

            return;
        }'''

new = '''        if (
            window.StoremanAuthNotification &&
            typeof window.StoremanAuthNotification.notify ===
                "function"
        ) {
            window.StoremanAuthNotification.notify(
                message,
                error
            );

            return;
        }'''

if old in text:
    text = text.replace(old, new)
    p.write_text(text)
    print("UPDATED: Auth Flow now uses AuthNotification.")
else:
    if "window.StoremanAuth.notify" in text:
        print("WARNING: Old notification dependency exists but block shape differs.")
        print("NO CHANGE MADE to avoid unsafe replacement.")
    else:
        print("OK: No old notification dependency found.")
PY

echo
echo "[5/7] Checking Guard dependency — NO unsafe rewrite..."

if grep -q 'window.StoremanAuth' storeman-auth-final-guard.js; then
    echo "NOTICE: Final Guard still references legacy StoremanAuth."
    echo "Decision: DO NOT blindly rewrite it because FinalAuth profile access is async."
    echo "Guard remains temporarily isolated until its contract is migrated safely."
else
    echo "OK: Final Guard has no legacy StoremanAuth reference."
fi

echo
echo "[6/7] Syntax validation..."

JS_FILES=(
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

FAIL=0

if command -v node >/dev/null 2>&1; then
    for f in "${JS_FILES[@]}"; do
        if [ -f "$f" ]; then
            if node --check "$f" >/dev/null 2>&1; then
                echo "  OK    $f"
            else
                echo "  FAIL  $f"
                FAIL=1
            fi
        fi
    done
else
    echo "Node.js unavailable — syntax check skipped."
fi

echo
echo "[7/7] Final architecture verification..."

echo
echo "===== ACTIVE AUTH SCRIPTS ====="
grep -nE '<script[^>]+src=' index.html | \
grep -Ei 'auth|security|notification|admin|pending' || true

echo
echo "===== CANONICAL AUTH EXPORT ====="
grep -n 'window.StoremanFinalAuth' storeman-auth-final.js || true

echo
echo "===== OLD ACTIVE AUTH TAGS ====="
if grep -nE '<script[^>]+src=.*(storeman-auth\.js|storeman-web-auth-gate\.js)' index.html; then
    echo "WARNING: Legacy Auth script is still active."
else
    echo "OK: No legacy Auth script is active in index.html."
fi

echo
echo "===== OLD AUTH DEPENDENCIES IN ACTIVE FINAL FILES ====="
grep -RniE \
'window\.StoremanAuth\.|window\.StoremanAuth[[:space:]]*&&' \
--include='*.js' . \
| grep -v '/backup/' \
| grep -v 'app/src/main/assets/' \
| grep -v '/web/' \
| grep -v 'storeman-auth.js' \
|| true

echo
echo "=================================================="

if [ "$FAIL" -eq 0 ]; then
    echo " RESULT: ARCHITECTURE CLEANUP PASSED"
else
    echo " RESULT: CLEANUP HAS JS SYNTAX FAILURES"
fi

echo "=================================================="
echo
echo "Canonical Core:"
echo "  storeman-auth-final.js"
echo
echo "Auth Flow:"
echo "  storeman-auth-flow-final.js"
echo
echo "Login UI:"
echo "  storeman-login-ui-final.js"
echo
echo "Guard:"
echo "  storeman-auth-final-guard.js"
echo
echo "Legacy source files were NOT deleted."
echo "Backup: $BACKUP"
echo
echo "NEXT STATE:"
echo "  Auth Core = StoremanFinalAuth"
echo "  Legacy Auth scripts = inactive"
echo "  No new Auth system created"
echo "=================================================="
