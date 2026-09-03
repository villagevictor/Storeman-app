
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

