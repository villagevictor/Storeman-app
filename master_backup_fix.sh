#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-$HOME/Storeman-app}"
ADMIN_EMAIL="${ADMIN_EMAIL:-ashenafihailay779@gmail.com}"
PUSH_NOW="${PUSH_NOW:-1}"

cd "$APP_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$APP_DIR/backup/backup_fix_$STAMP"
MIG_DIR="$APP_DIR/supabase/migrations"

mkdir -p "$BACKUP_DIR" "$MIG_DIR"

echo "============================================================"
echo " STOREMAN BACKUP / RESTORE MASTER FIX"
echo "============================================================"
echo "APP       : $APP_DIR"
echo "ADMIN     : $ADMIN_EMAIL"
echo "TIME      : $STAMP"
echo "============================================================"

# ============================================================
# 1. SAFETY BACKUP
# ============================================================

echo
echo "[1/7] Creating safety backup..."

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git status --short > "$BACKUP_DIR/git-status.txt" || true
    git rev-parse HEAD > "$BACKUP_DIR/git-head.txt" || true
    git remote -v > "$BACKUP_DIR/git-remotes.txt" || true

    git bundle create \
      "$BACKUP_DIR/storeman-before-backup-fix.bundle" \
      --all >/dev/null 2>&1 || true
fi

[ -f index.html ] && cp -p index.html "$BACKUP_DIR/index.html.before-fix" || true
[ -f web/index.html ] && cp -p web/index.html "$BACKUP_DIR/web-index.html.before-fix" || true
[ -f app/src/main/assets/index.html ] &&
  cp -p app/src/main/assets/index.html \
  "$BACKUP_DIR/android-index.html.before-fix" || true

echo "✓ Safety backup created:"
echo "$BACKUP_DIR"

# ============================================================
# 2. SUPABASE STORE_BACKUPS MIGRATION
# ============================================================

echo
echo "[2/7] Creating Supabase backup migration..."

MIGRATION="$MIG_DIR/20260903_storeman_backup_restore_fix.sql"

cat > "$MIGRATION" <<'SQL'

-- ============================================================
-- STOREMAN CLOUD BACKUP / RESTORE FIX
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- Storeman backup table
-- ------------------------------------------------------------

create table if not exists public.store_backups (
    id uuid primary key default gen_random_uuid(),

    user_id uuid
        references auth.users(id)
        on delete cascade,

    email text not null,

    company_id uuid,

    backup_version integer
        not null default 1,

    payload jsonb
        not null default '{}'::jsonb,

    -- Compatibility with older Storeman backup code
    materials_data text,

    created_at timestamptz
        not null default now(),

    updated_at timestamptz
        not null default now()
);

-- ------------------------------------------------------------
-- Add missing columns to old installations
-- ------------------------------------------------------------

alter table public.store_backups
    add column if not exists user_id uuid;

alter table public.store_backups
    add column if not exists company_id uuid;

alter table public.store_backups
    add column if not exists backup_version integer
    default 1;

alter table public.store_backups
    add column if not exists payload jsonb
    default '{}'::jsonb;

alter table public.store_backups
    add column if not exists materials_data text;

alter table public.store_backups
    add column if not exists created_at timestamptz
    default now();

alter table public.store_backups
    add column if not exists updated_at timestamptz
    default now();

-- ------------------------------------------------------------
-- Make user_id reference auth.users where possible
-- ------------------------------------------------------------

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'store_backups_user_id_fkey'
    ) then
        begin
            alter table public.store_backups
            add constraint store_backups_user_id_fkey
            foreign key (user_id)
            references auth.users(id)
            on delete cascade;
        exception
            when duplicate_object then null;
        end;
    end if;
end $$;

-- ------------------------------------------------------------
-- Unique backup per user
-- ------------------------------------------------------------

create unique index if not exists
store_backups_user_id_unique
on public.store_backups(user_id)
where user_id is not null;

-- ------------------------------------------------------------
-- Indexes
-- ------------------------------------------------------------

create index if not exists
store_backups_email_idx
on public.store_backups(lower(email));

create index if not exists
store_backups_updated_idx
on public.store_backups(updated_at desc);

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------

alter table public.store_backups enable row level security;

-- Remove old conflicting policies safely
drop policy if exists "storeman_backup_select_own"
on public.store_backups;

drop policy if exists "storeman_backup_insert_own"
on public.store_backups;

drop policy if exists "storeman_backup_update_own"
on public.store_backups;

drop policy if exists "storeman_backup_delete_own"
on public.store_backups;

drop policy if exists "storeman_backup_admin_all"
on public.store_backups;

-- ------------------------------------------------------------
-- User can read own backup
-- ------------------------------------------------------------

create policy "storeman_backup_select_own"
on public.store_backups
for select
to authenticated
using (
    user_id = auth.uid()
    or lower(email) = lower(coalesce(auth.jwt()->>'email',''))
);

-- ------------------------------------------------------------
-- User can create own backup
-- ------------------------------------------------------------

create policy "storeman_backup_insert_own"
on public.store_backups
for insert
to authenticated
with check (
    user_id = auth.uid()
    or lower(email) = lower(coalesce(auth.jwt()->>'email',''))
);

-- ------------------------------------------------------------
-- User can update own backup
-- ------------------------------------------------------------

create policy "storeman_backup_update_own"
on public.store_backups
for update
to authenticated
using (
    user_id = auth.uid()
    or lower(email) = lower(coalesce(auth.jwt()->>'email',''))
)
with check (
    user_id = auth.uid()
    or lower(email) = lower(coalesce(auth.jwt()->>'email',''))
);

-- ------------------------------------------------------------
-- User can delete own backup
-- ------------------------------------------------------------

create policy "storeman_backup_delete_own"
on public.store_backups
for delete
to authenticated
using (
    user_id = auth.uid()
    or lower(email) = lower(coalesce(auth.jwt()->>'email',''))
);

-- ------------------------------------------------------------
-- Admin access
-- ------------------------------------------------------------

create policy "storeman_backup_admin_all"
on public.store_backups
for all
to authenticated
using (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and lower(coalesce(p.role,'')) in ('admin','owner')
          and lower(coalesce(p.status,'')) = 'active'
    )
)
with check (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and lower(coalesce(p.role,'')) in ('admin','owner')
          and lower(coalesce(p.status,'')) = 'active'
    )
);

-- ------------------------------------------------------------
-- Updated timestamp trigger
-- ------------------------------------------------------------

create or replace function public.storeman_backup_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists
storeman_backup_touch_updated_at
on public.store_backups;

create trigger
storeman_backup_touch_updated_at
before update on public.store_backups
for each row
execute function public.storeman_backup_touch_updated_at();

SQL

echo "✓ Migration created:"
echo "$MIGRATION"

# ============================================================
# 3. CREATE FRONTEND BACKUP FIX
# ============================================================

echo
echo "[3/7] Creating backup engine..."

PATCH="$APP_DIR/storeman-backup-fix.js"

cat > "$PATCH" <<'JS'
(function () {
  "use strict";

  console.log("[Storeman Backup Fix] loaded");

  function getClient() {
    return (
      window.sb ||
      window.supabaseClient ||
      window.supabase ||
      window.storemanSupabase ||
      null
    );
  }

  function parseJSON(value, fallback) {
    try {
      return JSON.parse(value);
    } catch (_) {
      return fallback;
    }
  }

  function readLocal(key, fallback) {
    return parseJSON(
      localStorage.getItem(key) ||
      JSON.stringify(fallback),
      fallback
    );
  }

  async function getCurrentUser() {
    const client = getClient();

    if (!client || !client.auth) {
      throw new Error("Supabase client/auth is not available.");
    }

    const result = await client.auth.getUser();

    if (result.error) {
      throw result.error;
    }

    if (!result.data || !result.data.user) {
      throw new Error("No authenticated Supabase user.");
    }

    return result.data.user;
  }

  async function getProfile(userId) {
    const client = getClient();

    const result = await client
      .from("profiles")
      .select("id,email,role,status,company_id")
      .eq("id", userId)
      .maybeSingle();

    if (result.error) {
      throw result.error;
    }

    return result.data || null;
  }

  /*
   * Collect ALL important Storeman data.
   * LocalStorage is used only as a source for the
   * current ERP cache. Supabase remains the cloud source.
   */
  async function collectBackupData() {
    const client = getClient();
    const user = await getCurrentUser();
    const profile = await getProfile(user.id);

    const materialsLocal =
      readLocal("products_store", null) ||
      readLocal("materials", null) ||
      readLocal("storeman_materials", []);

    const suppliersLocal =
      readLocal("suppliers_store", []);

    const warehousesLocal =
      readLocal("warehouses_store", []);

    const transactionsLocal =
      readLocal("transactions_store", []);

    const fullData = {
      schema_version: 2,

      backup_source: "storeman-web",

      user: {
        id: user.id,
        email: user.email || profile?.email || ""
      },

      profile: profile || null,

      materials: materialsLocal,
      suppliers: suppliersLocal,
      warehouses: warehousesLocal,
      transactions: transactionsLocal,

      created_at: new Date().toISOString()
    };

    /*
     * If cloud tables are available, collect them too.
     * Local cache is retained as fallback.
     */
    if (client) {
      const queries = await Promise.allSettled([
        client.from("materials").select("*"),
        client.from("suppliers").select("*"),
        client.from("warehouses").select("*"),
        client.from("transactions").select("*"),
        client.from("sales_orders").select("*")
      ]);

      const names = [
        "materials",
        "suppliers",
        "warehouses",
        "transactions",
        "sales_orders"
      ];

      queries.forEach(function (q, i) {
        if (
          q.status === "fulfilled" &&
          !q.value.error &&
          Array.isArray(q.value.data)
        ) {
          fullData[names[i]] = q.value.data;
        }
      });
    }

    return fullData;
  }

  function showMessage(text, success) {
    const candidates = [
      "#backup-status",
      "#cloud-backup-status",
      ".backup-status"
    ];

    let box = null;

    for (const selector of candidates) {
      box = document.querySelector(selector);
      if (box) break;
    }

    if (!box) {
      box = document.createElement("div");
      box.id = "storeman-backup-status";
      box.style.cssText =
        "margin-top:12px;padding:12px;border-radius:10px;font-weight:700;text-align:center;";
      const card = [...document.querySelectorAll("div")].find(function (x) {
        return (x.textContent || "").includes("Cloud Database Backup");
      });

      if (card) {
        card.appendChild(box);
      } else {
        document.body.appendChild(box);
      }
    }

    box.textContent = text;

    if (success) {
      box.style.background = "#dcfce7";
      box.style.color = "#166534";
    } else {
      box.style.background = "#fee2e2";
      box.style.color = "#991b1b";
    }
  }

  async function cloudBackupData() {
    showMessage("☁️ Saving backup to Supabase...", true);

    try {
      const client = getClient();

      if (!client) {
        throw new Error(
          "Supabase client was not found. Check supabase-config.js/config."
        );
      }

      const user = await getCurrentUser();
      const profile = await getProfile(user.id);
      const fullData = await collectBackupData();

      const email =
        user.email ||
        profile?.email ||
        "";

      if (!email) {
        throw new Error("Authenticated user email is missing.");
      }

      const payload = {
        schema_version: 2,
        saved_by: user.id,
        email: email,
        saved_at: new Date().toISOString(),
        data: fullData
      };

      /*
       * IMPORTANT:
       * Use user_id as the conflict target.
       * This avoids the common "ON CONFLICT email"
       * failure when email has no UNIQUE constraint.
       */
      const row = {
        user_id: user.id,
        email: email,
        company_id: profile?.company_id || null,
        backup_version: 2,
        payload: payload,
        materials_data: JSON.stringify(fullData),
        updated_at: new Date().toISOString()
      };

      let result = await client
        .from("store_backups")
        .upsert(row, {
          onConflict: "user_id"
        })
        .select("*")
        .single();

      /*
       * Compatibility fallback for old rows/schema.
       */
      if (result.error) {
        console.warn(
          "[Storeman Backup] user_id upsert failed:",
          result.error
        );

        const fallback = await client
          .from("store_backups")
          .upsert(
            {
              email: email,
              materials_data: JSON.stringify(fullData),
              updated_at: new Date().toISOString()
            },
            {
              onConflict: "email"
            }
          )
          .select("*")
          .single();

        result = fallback;
      }

      if (result.error) {
        throw result.error;
      }

      localStorage.setItem(
        "storeman_last_cloud_backup",
        new Date().toISOString()
      );

      showMessage(
        "✅ Cloud Backup Successful — data saved to Supabase.",
        true
      );

      console.log(
        "[Storeman Backup] SUCCESS",
        result.data
      );

      return result.data;

    } catch (error) {
      console.error(
        "[Storeman Backup] FAILED:",
        error
      );

      showMessage(
        "❌ Cloud Backup Failed: " +
          (error?.message || String(error)),
        false
      );

      throw error;
    }
  }

  async function restoreCloudData() {
    showMessage("🔄 Restoring data from Supabase...", true);

    try {
      const client = getClient();
      const user = await getCurrentUser();

      const result = await client
        .from("store_backups")
        .select("*")
        .eq("user_id", user.id)
        .order("updated_at", {
          ascending: false
        })
        .limit(1)
        .maybeSingle();

      let backup = result.data;

      /*
       * Compatibility fallback for old email-based backups.
       */
      if (!backup) {
        const emailResult = await client
          .from("store_backups")
          .select("*")
          .eq("email", user.email || "")
          .order("updated_at", {
            ascending: false
          })
          .limit(1)
          .maybeSingle();

        if (emailResult.error) {
          throw emailResult.error;
        }

        backup = emailResult.data;
      }

      if (!backup) {
        throw new Error(
          "No cloud backup was found for this account."
        );
      }

      let fullData = null;

      if (backup.payload) {
        const p =
          typeof backup.payload === "string"
            ? parseJSON(backup.payload, null)
            : backup.payload;

        fullData = p?.data || p;
      }

      if (!fullData && backup.materials_data) {
        fullData = parseJSON(
          backup.materials_data,
          null
        );
      }

      if (!fullData) {
        throw new Error(
          "Backup exists, but its data format is invalid."
        );
      }

      /*
       * Restore local cache.
       */
      if (Array.isArray(fullData.materials)) {
        localStorage.setItem(
          "products_store",
          JSON.stringify(fullData.materials)
        );

        localStorage.setItem(
          "materials",
          JSON.stringify(fullData.materials)
        );
      }

      if (Array.isArray(fullData.suppliers)) {
        localStorage.setItem(
          "suppliers_store",
          JSON.stringify(fullData.suppliers)
        );
      }

      if (Array.isArray(fullData.warehouses)) {
        localStorage.setItem(
          "warehouses_store",
          JSON.stringify(fullData.warehouses)
        );
      }

      if (Array.isArray(fullData.transactions)) {
        localStorage.setItem(
          "transactions_store",
          JSON.stringify(fullData.transactions)
        );
      }

      /*
       * Optional sales order cache.
       */
      if (Array.isArray(fullData.sales_orders)) {
        localStorage.setItem(
          "sales_orders_store",
          JSON.stringify(fullData.sales_orders)
        );
      }

      localStorage.setItem(
        "storeman_last_cloud_restore",
        new Date().toISOString()
      );

      if (typeof window.renderUI === "function") {
        try {
          window.renderUI();
        } catch (_) {}
      }

      showMessage(
        "✅ Cloud Restore Successful.",
        true
      );

      return fullData;

    } catch (error) {
      console.error(
        "[Storeman Restore] FAILED:",
        error
      );

      showMessage(
        "❌ Cloud Restore Failed: " +
          (error?.message || String(error)),
        false
      );

      throw error;
    }
  }

  /*
   * Replace old buttons safely by cloning them.
   * This removes old click listeners/inline handlers
   * without changing the ERP UI.
   */
  function installButtons() {
    const allButtons = [
      ...document.querySelectorAll("button")
    ];

    allButtons.forEach(function (button) {
      const text =
        (button.textContent || "")
          .replace(/\s+/g, " ")
          .trim()
          .toLowerCase();

      if (
        text.includes("save backup to cloud database")
      ) {
        const clone = button.cloneNode(true);

        clone.removeAttribute("onclick");

        clone.addEventListener("click", function (event) {
          event.preventDefault();

          cloudBackupData().catch(function () {});
        });

        button.replaceWith(clone);
      }

      if (
        text.includes("restore data from cloud database")
      ) {
        const clone = button.cloneNode(true);

        clone.removeAttribute("onclick");

        clone.addEventListener("click", function (event) {
          event.preventDefault();

          restoreCloudData().catch(function () {});
        });

        button.replaceWith(clone);
      }
    });
  }

  window.StoremanCloudBackup = {
    backup: cloudBackupData,
    restore: restoreCloudData,
    collect: collectBackupData
  };

  window.cloudBackupData = cloudBackupData;
  window.restoreCloudData = restoreCloudData;

  function boot() {
    installButtons();

    setTimeout(installButtons, 500);
    setTimeout(installButtons, 1500);
    setTimeout(installButtons, 3000);
  }

  if (
    document.readyState === "loading"
  ) {
    document.addEventListener(
      "DOMContentLoaded",
      boot
    );
  } else {
    boot();
  }

})();
JS

echo "✓ Backup engine created:"
echo "$PATCH"

# ============================================================
# 4. INJECT PATCH INTO ALL STOREMAN HTML COPIES
# ============================================================

echo
echo "[4/7] Injecting backup engine..."

inject_patch() {
    local FILE="$1"

    [ -f "$FILE" ] || return 0

    if grep -q "storeman-backup-fix.js" "$FILE"; then
        echo "✓ Already linked: $FILE"
        return 0
    fi

    sed -i \
      's#</body>#<script src="./storeman-backup-fix.js"></script>\n</body>#' \
      "$FILE"

    echo "✓ Patched: $FILE"
}

inject_patch "$APP_DIR/index.html"
inject_patch "$APP_DIR/web/index.html"
inject_patch "$APP_DIR/app/src/main/assets/index.html"

# Copy patch beside Android asset
if [ -d "$APP_DIR/app/src/main/assets" ]; then
    cp -p "$PATCH" \
      "$APP_DIR/app/src/main/assets/storeman-backup-fix.js"
    echo "✓ Android backup engine copied"
fi

# ============================================================
# 5. JAVASCRIPT SYNTAX CHECK
# ============================================================

echo
echo "[5/7] Running JavaScript checks..."

if command -v node >/dev/null 2>&1; then
    node --check "$PATCH"
    echo "✓ storeman-backup-fix.js syntax OK"
else
    echo "⚠ Node.js not installed; syntax check skipped."
fi

# ============================================================
# 6. GIT COMMIT
# ============================================================

echo
echo "[6/7] Git status..."

git status --short

git add \
  storeman-backup-fix.js \
  supabase/migrations/20260903_storeman_backup_restore_fix.sql \
  index.html \
  web/index.html \
  app/src/main/assets/index.html \
  app/src/main/assets/storeman-backup-fix.js \
  2>/dev/null || true

git commit \
  -m "fix: Storeman cloud backup and restore with Supabase RLS" \
  || true

# ============================================================
# 7. PUSH
# ============================================================

echo
echo "[7/7] GitHub..."

if [ "$PUSH_NOW" = "1" ]; then

    BRANCH="$(git branch --show-current)"

    echo "Pushing branch: $BRANCH"

    git push origin "$BRANCH"

    echo "✓ GitHub push completed."

else
    echo "Push disabled."
    echo "Run:"
    echo "PUSH_NOW=1 bash master_backup_fix.sh"
fi

echo
echo "============================================================"
echo " MASTER BACKUP FIX FINISHED"
echo "============================================================"
echo
echo "NEXT STEP — SUPABASE:"
echo
echo "Open Supabase Dashboard"
echo "→ SQL Editor"
echo
echo "Run:"
echo "$MIGRATION"
echo
echo "IMPORTANT:"
echo "The SQL migration MUST be executed in Supabase."
echo
echo "Then test:"
echo "1. Login as active admin/user"
echo "2. Save Backup"
echo "3. Confirm SUCCESS"
echo "4. Restore"
echo "5. Confirm data returns"
echo "============================================================"
