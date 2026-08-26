-- ============================================================
-- STOREMAN ADMIN NOTIFICATIONS
-- ============================================================

create table if not exists public.admin_notifications (

  id uuid primary key default gen_random_uuid(),

  user_id uuid references auth.users(id)
    on delete cascade,

  user_email text,

  full_name text,

  type text not null default 'new_signup',

  status text not null default 'unread',

  message text,

  created_at timestamptz not null default now()

);

alter table public.admin_notifications
enable row level security;

revoke all
on public.admin_notifications
from anon, authenticated;

grant select, update
on public.admin_notifications
to authenticated;

drop policy if exists admin_notifications_select
on public.admin_notifications;

create policy admin_notifications_select
on public.admin_notifications
for select
to authenticated
using (
  private.is_admin()
);

drop policy if exists admin_notifications_update
on public.admin_notifications;

create policy admin_notifications_update
on public.admin_notifications
for update
to authenticated
using (
  private.is_admin()
)
with check (
  private.is_admin()
);

-- No normal authenticated user can insert notifications.
-- Notifications are created by trusted backend/webhook logic.

