
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

