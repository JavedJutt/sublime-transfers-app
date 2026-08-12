-- ============================================================================
-- Sublime Transfers — Row Level Security
--
-- The hard requirement: admins see `source_admin_id`; drivers never do. RLS is
-- row-level and cannot hide a *column* from one role and not another when both
-- authenticate as the same Postgres role (`authenticated`). So the strategy is:
--
--   1. Enable RLS on every table.
--   2. REVOKE direct table access to `rides` from app roles entirely.
--   3. Expose reads through two security_invoker views (next migration):
--      admin_rides (full projection) and driver_rides (source/assigning admin
--      columns absent). RLS on the base table still gates which rows each role
--      can see through those views.
--
-- Drivers get NO direct UPDATE policy on rides anywhere — every driver mutation
-- goes through a security definer RPC, so transition rules can't be bypassed by
-- a hand-crafted PATCH.
-- ============================================================================

alter table public.profiles            enable row level security;
alter table public.driver_profiles     enable row level security;
alter table public.rides               enable row level security;
alter table public.ride_status_events  enable row level security;
alter table public.ride_offers         enable row level security;
alter table public.location_pings      enable row level security;
alter table public.gmail_accounts      enable row level security;
alter table public.inbound_emails      enable row level security;
alter table public.device_tokens       enable row level security;
alter table public.notifications       enable row level security;
alter table public.client_events       enable row level security;

-- Clients never touch `rides`, `gmail_accounts`, or `inbound_emails` directly.
-- Token columns and source-admin metadata therefore never reach the wire except
-- through the projection views granted below.
revoke all on public.rides          from anon, authenticated;
revoke all on public.gmail_accounts from anon, authenticated;
revoke all on public.inbound_emails from anon, authenticated;

-- ------------------------------------------------------------------ profiles ---
-- Everyone signed in can read profiles (drivers need admin/driver names for
-- assignment context; the sensitive metadata is not here). Self-update only,
-- and role is frozen by a guard trigger below.
create policy profiles_select_all on public.profiles
  for select to authenticated
  using (true);

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_admin_update on public.profiles
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Freeze role and is_active for self-updates: a user cannot promote themselves
-- to admin or re-activate a suspended account. Admins bypass via a separate
-- guard: the trigger only blocks when the actor is the row owner and not admin.
create or replace function public.tg_profiles_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    if new.role is distinct from old.role then
      raise exception 'forbidden: role is immutable';
    end if;
    if new.is_active is distinct from old.is_active then
      raise exception 'forbidden: is_active is admin-only';
    end if;
  end if;
  return new;
end;
$$;

create trigger profiles_guard
  before update on public.profiles
  for each row execute function public.tg_profiles_guard();

-- ------------------------------------------------------- driver_profiles ---
-- A driver reads and updates their own vehicle details; approval fields are
-- admin-only, enforced by a guard trigger. Admins read and write all.
create policy driver_profiles_select_self on public.driver_profiles
  for select to authenticated
  using (id = auth.uid());

create policy driver_profiles_select_admin on public.driver_profiles
  for select to authenticated
  using (public.is_admin());

create policy driver_profiles_update_self on public.driver_profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy driver_profiles_admin_all on public.driver_profiles
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create or replace function public.tg_driver_profiles_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    if new.approval_status is distinct from old.approval_status
       or new.approved_by is distinct from old.approved_by
       or new.approved_at is distinct from old.approved_at
       or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'forbidden: approval fields are admin-only';
    end if;
  end if;
  return new;
end;
$$;

create trigger driver_profiles_guard
  before update on public.driver_profiles
  for each row execute function public.tg_driver_profiles_guard();

-- ------------------------------------------------------------------- rides ---
-- Admins: full row visibility regardless of source admin (shared pool).
create policy rides_admin_select on public.rides
  for select to authenticated
  using (public.is_admin());

-- Drivers: only rides that are theirs, open for broadcast, or pending-offered
-- to them. This is what a driver's realtime/query scope resolves to; note
-- drivers read through the driver_rides VIEW, but the base-table policy is what
-- actually filters the rows the view returns.
create policy rides_driver_select on public.rides
  for select to authenticated
  using (
    public.is_approved_driver()
    and (
      assigned_driver_id = auth.uid()
      or broadcast_open
      or exists (
        select 1 from public.ride_offers o
        where o.ride_id = rides.id
          and o.driver_id = auth.uid()
          and o.status = 'pending'
      )
    )
  );

-- Only admins write rides directly (create + edit). Drivers never get an
-- UPDATE/INSERT/DELETE policy — their mutations go through definer RPCs.
create policy rides_admin_insert on public.rides
  for insert to authenticated
  with check (public.is_admin());

create policy rides_admin_update on public.rides
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ------------------------------------------------- ride_status_events ---
-- Read-only to clients; append happens through definer functions/triggers.
create policy events_admin_select on public.ride_status_events
  for select to authenticated
  using (public.is_admin());

create policy events_driver_select on public.ride_status_events
  for select to authenticated
  using (
    public.is_approved_driver()
    and exists (
      select 1 from public.rides r
      where r.id = ride_status_events.ride_id
        and r.assigned_driver_id = auth.uid()
    )
  );
-- No insert/update/delete policy for anyone: the log is append-only, written
-- solely by security definer code.

-- ------------------------------------------------------------ ride_offers ---
create policy offers_admin_all on public.ride_offers
  for select to authenticated
  using (public.is_admin());

create policy offers_driver_select on public.ride_offers
  for select to authenticated
  using (driver_id = auth.uid() and public.is_approved_driver());
-- Offers are created and resolved by definer RPCs; no client write policy.

-- ---------------------------------------------------------- location_pings ---
create policy pings_driver_insert on public.location_pings
  for insert to authenticated
  with check (driver_id = auth.uid() and public.is_approved_driver());

create policy pings_driver_select on public.location_pings
  for select to authenticated
  using (driver_id = auth.uid());

create policy pings_admin_select on public.location_pings
  for select to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------- gmail_accounts ---
-- Reads go through a view that omits the token columns. Admins can see all
-- linked mailboxes (shared review duty) but the token ciphertext is never
-- granted. No client write policy — the OAuth Edge Functions own writes.
create policy gmail_admin_select on public.gmail_accounts
  for select to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------- inbound_emails ---
-- All admins share the review queue.
create policy emails_admin_select on public.inbound_emails
  for select to authenticated
  using (public.is_admin());

create policy emails_admin_update on public.inbound_emails
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ----------------------------------------------------------- device_tokens ---
create policy device_tokens_self_all on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ----------------------------------------------------------- notifications ---
create policy notifications_self_select on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

create policy notifications_self_update on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ------------------------------------------------------------ client_events ---
create policy client_events_self_select on public.client_events
  for select to authenticated
  using (user_id = auth.uid());
-- Writes only via definer RPCs.
