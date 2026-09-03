#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

APP_DIR="${HOME}/Storeman-app"
BRANCH="main"

echo
echo "============================================================"
echo "       STOREMAN ERP - FINAL RELIABILITY MASTER"
echo "============================================================"
echo

cd "$APP_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR=".storeman-backup/final-fix-$STAMP"

mkdir -p "$BACKUP_DIR"
mkdir -p supabase/migrations
mkdir -p web

echo "STEP 1/7 - SAFETY BACKUP"
echo "------------------------------------------------------------"

for FILE in \
  index.html \
  web/index.html \
  storeman-backup-fix.js \
  web/storeman-backup-fix.js \
  storeman-alert-report-master.js \
  web/storeman-alert-report-master.js \
  storeman-alert-report-resilience.js \
  web/storeman-alert-report-resilience.js \
  storeman-email-config.js \
  web/storeman-email-config.js
do

  if [ -f "$FILE" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$FILE")"
    cp -p "$FILE" "$BACKUP_DIR/$FILE"
  fi

done

echo "✓ Safety backup created:"
echo "$BACKUP_DIR"
echo


echo "STEP 2/7 - SUPABASE BACKUP/RESTORE FIX"
echo "------------------------------------------------------------"

cat > supabase/migrations/20260903_storeman_reliability_fix.sql <<'SQL'

-- ============================================================
-- STOREMAN FINAL CLOUD BACKUP / RESTORE FIX
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- BACKUP TABLE
-- ------------------------------------------------------------

create table if not exists public.store_backups (

    id uuid primary key
        default gen_random_uuid(),

    user_id uuid
        references auth.users(id)
        on delete cascade,

    email text not null,

    company_id uuid,

    backup_version integer
        not null default 1,

    payload jsonb
        not null default '{}'::jsonb,

    materials_data text,

    created_at timestamptz
        not null default now(),

    updated_at timestamptz
        not null default now()
);


-- ------------------------------------------------------------
-- OLD INSTALLATIONS
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
-- CONNECT OLD BACKUPS TO AUTH USERS
-- ------------------------------------------------------------

update public.store_backups b

set user_id = u.id

from auth.users u

where b.user_id is null

and lower(b.email) =
    lower(u.email);


-- ------------------------------------------------------------
-- REMOVE DUPLICATE USER BACKUPS
-- KEEP NEWEST
-- ------------------------------------------------------------

with ranked as (

    select

        id,

        row_number() over (

            partition by user_id

            order by
                updated_at desc nulls last,
                created_at desc nulls last,
                id desc

        ) as rn

    from public.store_backups

    where user_id is not null
)

delete from public.store_backups b

using ranked r

where b.id = r.id

and r.rn > 1;


-- ------------------------------------------------------------
-- FOREIGN KEY
-- ------------------------------------------------------------

do $$
begin

    if not exists (

        select 1

        from pg_constraint

        where conname =
            'store_backups_user_id_fkey'

    ) then

        begin

            alter table public.store_backups

            add constraint
                store_backups_user_id_fkey

            foreign key (user_id)

            references auth.users(id)

            on delete cascade;

        exception

            when duplicate_object
            then null;

        end;

    end if;

end $$;


-- ------------------------------------------------------------
-- IMPORTANT:
-- NON-PARTIAL UNIQUE CONSTRAINT
--
-- This fixes:
-- upsert(... onConflict:"user_id")
-- ------------------------------------------------------------

drop index if exists
    public.store_backups_user_id_unique;


do $$
begin

    if not exists (

        select 1

        from pg_constraint

        where conname =
            'store_backups_user_id_key'

    ) then

        alter table public.store_backups

        add constraint
            store_backups_user_id_key

        unique (user_id);

    end if;

end $$;


-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------

create index if not exists
    store_backups_email_idx

on public.store_backups
    (lower(email));


create index if not exists
    store_backups_updated_idx

on public.store_backups
    (updated_at desc);


-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------

alter table public.store_backups
enable row level security;


drop policy if exists
    "storeman_backup_select_own"
on public.store_backups;

drop policy if exists
    "storeman_backup_insert_own"
on public.store_backups;

drop policy if exists
    "storeman_backup_update_own"
on public.store_backups;

drop policy if exists
    "storeman_backup_delete_own"
on public.store_backups;

drop policy if exists
    "storeman_backup_admin_all"
on public.store_backups;


-- ------------------------------------------------------------
-- SELECT OWN BACKUP
-- ------------------------------------------------------------

create policy
    "storeman_backup_select_own"

on public.store_backups

for select

to authenticated

using (

    user_id = auth.uid()

    or

    lower(email) =
    lower(
        coalesce(
            auth.jwt()->>'email',
            ''
        )
    )

);


-- ------------------------------------------------------------
-- INSERT OWN BACKUP
-- ------------------------------------------------------------

create policy
    "storeman_backup_insert_own"

on public.store_backups

for insert

to authenticated

with check (

    user_id = auth.uid()

    or

    lower(email) =
    lower(
        coalesce(
            auth.jwt()->>'email',
            ''
        )
    )

);


-- ------------------------------------------------------------
-- UPDATE OWN BACKUP
-- ------------------------------------------------------------

create policy
    "storeman_backup_update_own"

on public.store_backups

for update

to authenticated

using (

    user_id = auth.uid()

    or

    lower(email) =
    lower(
        coalesce(
            auth.jwt()->>'email',
            ''
        )
    )

)

with check (

    user_id = auth.uid()

    or

    lower(email) =
    lower(
        coalesce(
            auth.jwt()->>'email',
            ''
        )
    )

);


-- ------------------------------------------------------------
-- DELETE OWN BACKUP
-- ------------------------------------------------------------

create policy
    "storeman_backup_delete_own"

on public.store_backups

for delete

to authenticated

using (

    user_id = auth.uid()

    or

    lower(email) =
    lower(
        coalesce(
            auth.jwt()->>'email',
            ''
        )
    )

);


-- ------------------------------------------------------------
-- ADMIN BACKUP ACCESS
-- ------------------------------------------------------------

create policy
    "storeman_backup_admin_all"

on public.store_backups

for all

to authenticated

using (

    exists (

        select 1

        from public.profiles p

        where p.id = auth.uid()

        and lower(
            coalesce(p.role,'')
        ) in ('admin','owner')

        and lower(
            coalesce(p.status,'')
        ) = 'active'

    )

)

with check (

    exists (

        select 1

        from public.profiles p

        where p.id = auth.uid()

        and lower(
            coalesce(p.role,'')
        ) in ('admin','owner')

        and lower(
            coalesce(p.status,'')
        ) = 'active'

    )

);


-- ------------------------------------------------------------
-- UPDATED_AT
-- ------------------------------------------------------------

create or replace function
public.storeman_backup_touch_updated_at()

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

before update

on public.store_backups

for each row

execute function
public.storeman_backup_touch_updated_at();

SQL

echo "✓ Supabase migration created."
echo


echo "STEP 3/7 - LOW STOCK EMAIL RELIABILITY FIX"
echo "------------------------------------------------------------"

cat > web/storeman-reliability-fix.js <<'JS'

(function () {

"use strict";

const STOREMAN_DEFAULTS = {

    receiverEmail:
        "ashenafihailay779@gmail.com",

    publicKey:
        "8JupT1wuqer_SMq3P",

    serviceId:
        "service_ojriqwn",

    lowStockTemplateId:
        "template_tbu1wdb"

};


function getConfig(key, storageKey) {

    try {

        const saved =
            localStorage.getItem(storageKey);

        if (saved && saved.trim()) {

            return saved.trim();

        }

    } catch (_) {}

    return STOREMAN_DEFAULTS[key];

}


function setStatus(target, type, text) {

    if (!target) return;

    target.className =
        "status-msg " + type;

    target.innerText =
        text;

}


async function sendLowStockAlert(
    params,
    target
) {

    const receiver =
        getConfig(
            "receiverEmail",
            "cfg_email"
        );

    const publicKey =
        getConfig(
            "publicKey",
            "cfg_passkey"
        );

    const serviceId =
        getConfig(
            "serviceId",
            "cfg_service_id"
        );

    const templateId =
        getConfig(
            "lowStockTemplateId",
            "cfg_low_template"
        );


    if (
        !window.emailjs ||

        typeof window.emailjs.send !==
        "function"
    ) {

        setStatus(
            target,
            "msg-error",
            "❌ EmailJS SDK is not loaded."
        );

        return false;

    }


    try {

        window.emailjs.init({

            publicKey:
                publicKey

        });

    } catch (_) {}


    const date =
        new Date().toLocaleString();


    const message =

        "⚠️ LOW STOCK ALERT\n\n" +

        "Material Name: " +
        (params.material_name || "") +
        "\n" +

        "Current Stock: " +
        (params.current_stock ?? "") +
        " " +
        (params.unit || "") +
        "\n" +

        "Minimum Stock: " +
        (params.minimum_stock ?? "") +
        " " +
        (params.unit || "") +
        "\n\n" +

        "Transaction Type: " +
        (params.type || "") +
        "\n" +

        "Quantity: " +
        (params.quantity ?? "") +
        "\n" +

        "Reference: " +
        (params.reference || "") +
        "\n" +

        "Date: " +
        date +
        "\n\n" +

        "Please restock this material as soon as possible.";


    setStatus(
        target,
        "msg-sending",
        "⏳ Sending Low Stock Alert Email..."
    );


    try {

        await window.emailjs.send(

            serviceId,

            templateId,

            {

                to_email:
                    receiver,

                material_name:
                    params.material_name || "",

                current_stock:
                    params.current_stock ?? "",

                unit:
                    params.unit || "",

                minimum_stock:
                    params.minimum_stock ?? "",

                type:
                    params.type || "",

                quantity:
                    params.quantity ?? "",

                reference:
                    params.reference || "",

                date:
                    date,

                message:
                    message,

                alert_text:
                    message

            }

        );


        setStatus(
            target,
            "msg-success",
            "✅ Low Stock Alert Email Sent!"
        );


        return true;


    } catch (error) {

        console.error(
            "[Storeman] Low Stock EmailJS Error:",
            error
        );


        setStatus(

            target,

            "msg-error",

            "❌ Email service unavailable. Reconnect EmailJS Gmail service and test again."

        );


        return false;

    }

}


/*
 * Make repaired function available
 * to existing Storeman inline handlers.
 */

window.triggerLowStockAlert =
    sendLowStockAlert;


window.StoremanReliability = {

    sendLowStockAlert

};


/*
 * Correct old receiver address.
 */

try {

    if (
        localStorage.getItem(
            "cfg_email"
        ) ===
        "ashenafihailay645@gmail.com"
    ) {

        localStorage.setItem(
            "cfg_email",
            STOREMAN_DEFAULTS.receiverEmail
        );

    }

} catch (_) {}


/*
 * Keep existing cloud backup module.
 */

function installBackupButtons() {

    if (
        !window.StoremanCloudBackup
    ) return;


    window.cloudBackupData =
        window.StoremanCloudBackup.backup;

    window.restoreCloudData =
        window.StoremanCloudBackup.restore;


    document
        .querySelectorAll("button")
        .forEach(function (button) {

            const text =
                (
                    button.textContent ||
                    ""
                )
                .replace(/\s+/g, " ")
                .trim()
                .toLowerCase();


            if (

                text.includes(
                    "save backup to cloud database"
                )

                &&

                button.dataset
                    .storemanBackupFix !==
                    "1"

            ) {

                button.dataset
                    .storemanBackupFix =
                    "1";


                button.removeAttribute(
                    "onclick"
                );


                button.addEventListener(
                    "click",
                    function (event) {

                        event.preventDefault();

                        window
                            .cloudBackupData()
                            .catch(
                                function (error) {

                                    console.error(
                                        "[Storeman] Backup:",
                                        error
                                    );

                                }
                            );

                    }
                );

            }


            if (

                text.includes(
                    "restore data from cloud database"
                )

                &&

                button.dataset
                    .storemanRestoreFix !==
                    "1"

            ) {

                button.dataset
                    .storemanRestoreFix =
                    "1";


                button.removeAttribute(
                    "onclick"
                );


                button.addEventListener(
                    "click",
                    function (event) {

                        event.preventDefault();

                        window
                            .restoreCloudData()
                            .catch(
                                function (error) {

                                    console.error(
                                        "[Storeman] Restore:",
                                        error
                                    );

                                }
                            );

                    }
                );

            }

        });

}


function install() {

    window.triggerLowStockAlert =
        sendLowStockAlert;

    installBackupButtons();

}


if (
    document.readyState ===
    "loading"
) {

    document.addEventListener(
        "DOMContentLoaded",
        install
    );

} else {

    install();

}


setTimeout(
    install,
    1000
);

setTimeout(
    install,
    3000
);


})();

JS

cp web/storeman-reliability-fix.js \
   storeman-reliability-fix.js

echo "✓ Low Stock reliability module created."
echo


echo "STEP 4/7 - PATCH WEB FILES"
echo "------------------------------------------------------------"

python3 <<'PY'

from pathlib import Path

files = [
    Path("index.html"),
    Path("web/index.html")
]

for path in files:

    if not path.exists():
        continue

    text = path.read_text(
        encoding="utf-8",
        errors="ignore"
    )

    # Correct old receiver.
    text = text.replace(
        "ashenafihailay645@gmail.com",
        "ashenafihailay779@gmail.com"
    )

    # EmailJS current browser SDK.
    text = text.replace(
        "@emailjs/browser@3/dist/email.min.js",
        "@emailjs/browser@4/dist/email.min.js"
    )

    if path.parts and path.parts[0] == "web":

        tag = (
            '<script '
            'src="./storeman-reliability-fix.js">'
            '</script>'
        )

    else:

        tag = (
            '<script '
            'src="storeman-reliability-fix.js">'
            '</script>'
        )

    if "storeman-reliability-fix.js" not in text:

        if "</body>" in text:

            text = text.replace(
                "</body>",
                "    " +
                tag +
                "\n</body>",
                1
            )

        else:

            text += "\n" + tag + "\n"

    path.write_text(
        text,
        encoding="utf-8"
    )

    print(
        "✓ patched:",
        path
    )

PY

echo


echo "STEP 5/7 - JAVASCRIPT SYNTAX TEST"
echo "------------------------------------------------------------"

if command -v node >/dev/null 2>&1; then

    node --check \
        web/storeman-reliability-fix.js

    node --check \
        storeman-reliability-fix.js

    echo "✓ JavaScript syntax OK."

else

    echo "⚠ Node.js not installed."
    echo "JavaScript syntax test skipped."

fi

echo


echo "STEP 6/7 - GIT"
echo "------------------------------------------------------------"

git status --short

git add .

git commit \
    -m "fix: finalize low stock email and cloud backup reliability" \
    || true

echo


echo "============================================================"
echo "STEP 7/7 - GITHUB PUSH"
echo "============================================================"
echo

read -rp \
"GitHub Username (ENTER to skip push): " \
GITHUB_USER

if [ -n "$GITHUB_USER" ]; then

    read -rsp \
    "GitHub PAT: " \
    GITHUB_PAT

    echo

    REMOTE="$(
        git remote get-url origin
    )"

    CLEAN_REMOTE="$(
        printf '%s' "$REMOTE" |
        sed -E \
        's#https://[^@]+@github.com/#https://github.com/#'
    )"

    AUTH_REMOTE="https://${GITHUB_USER}:${GITHUB_PAT}@github.com/$(printf '%s' "$CLEAN_REMOTE" | sed 's#https://github.com/##')"

    git push \
        "$AUTH_REMOTE" \
        "HEAD:${BRANCH}"

    git remote set-url \
        origin \
        "$CLEAN_REMOTE"

    unset GITHUB_PAT

    echo
    echo "✓ GitHub PUSH successful."

else

    echo
    echo "GitHub push skipped."
    echo "Run:"
    echo "git push origin main"

fi


echo
echo "============================================================"
echo "              STOREMAN FINAL FIX COMPLETE"
echo "============================================================"
echo
echo "BACKUP:"
echo "$BACKUP_DIR"
echo
echo "SUPABASE SQL:"
echo "supabase/migrations/20260903_storeman_reliability_fix.sql"
echo
echo "IMPORTANT:"
echo "Open Supabase SQL Editor and RUN the SQL file above."
echo
echo "Then reconnect/test EmailJS Gmail service:"
echo "service_ojriqwn"
echo
echo "Low Stock Template:"
echo "template_tbu1wdb"
echo
echo "Receiver:"
echo "ashenafihailay779@gmail.com"
echo
echo "============================================================"

