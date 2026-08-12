-- ============================================================================
-- Sublime Transfers — projection views
--
-- These are the ONLY read path to rides for app clients (direct table grants
-- were revoked in the RLS migration). Column hiding is the hard requirement:
-- admins see source_admin_id, drivers never do.
--
-- Approach: the views run as their OWNER (security_invoker = false, the
-- default), which bypasses the base-table RLS. That is deliberate and safe
-- here because each view carries its OWN visibility predicate in a WHERE
-- clause. This is what lets us hide a *column* (impossible with row-level RLS
-- alone when both roles share the `authenticated` Postgres role):
--
--   * We do NOT grant SELECT on the base `rides` table to app roles, so a
--     driver cannot bypass the view and read source_admin_id directly.
--   * driver_rides omits source_admin_id / assigning_admin_id / source_email_id
--     / created_by entirely — a driver cannot receive those columns on the wire.
--   * Each view's WHERE clause reproduces the row visibility that the base RLS
--     policies describe, using the same security-definer helpers.
--
-- (Row-level RLS on `rides` remains enabled and is what governs realtime
-- postgres_changes for admins; see the realtime migration.)
-- ============================================================================

drop view if exists public.admin_rides;
drop view if exists public.driver_rides;
drop view if exists public.gmail_accounts_safe;

create view public.admin_rides as
select
  r.*,
  sa.full_name as source_admin_name,
  aa.full_name as assigning_admin_name,
  d.full_name  as driver_name,
  d.phone      as driver_phone,
  dp.vehicle_type as driver_vehicle_type,
  dp.is_on_duty   as driver_on_duty,
  dp.last_lat     as driver_last_lat,
  dp.last_lng     as driver_last_lng,
  dp.last_location_at as driver_last_location_at
from public.rides r
left join public.profiles sa on sa.id = r.source_admin_id
left join public.profiles aa on aa.id = r.assigning_admin_id
left join public.profiles d  on d.id  = r.assigned_driver_id
left join public.driver_profiles dp on dp.id = r.assigned_driver_id
-- Admin-only gate. A non-admin selecting this view gets zero rows.
where public.is_admin();

comment on view public.admin_rides is
  'Admin-facing ride projection with joined names. Runs as owner; the WHERE '
  'is_admin() gate is the row-visibility control since base-table RLS is '
  'bypassed by owner execution.';

create view public.driver_rides as
select
  r.id,
  r.reference,
  r.pickup_at,
  r.customer_name,
  r.customer_phone,
  r.pickup_address,
  r.pickup_lat,
  r.pickup_lng,
  r.dropoff_address,
  r.dropoff_lat,
  r.dropoff_lng,
  r.passengers,
  r.luggage,
  r.fare_amount,
  r.fare_currency,
  r.vehicle_type,
  r.flight_number,
  r.notes,
  r.status,
  r.assigned_driver_id,
  r.assignment_method,
  r.broadcast_open,
  r.assigned_at,
  r.created_at,
  r.updated_at
  -- No source_admin_id / source_email_id / assigning_admin_id / created_by.
from public.rides r
-- Driver visibility: approved, and the ride is theirs, an open broadcast, or
-- pending-offered to them. Mirrors the rides_driver_select RLS policy.
where public.is_approved_driver()
  and (
    r.assigned_driver_id = auth.uid()
    or r.broadcast_open
    or exists (
      select 1 from public.ride_offers o
      where o.ride_id = r.id and o.driver_id = auth.uid() and o.status = 'pending'
    )
  );

comment on view public.driver_rides is
  'Driver-facing ride projection. Source/assigning admin columns omitted so a '
  'driver can never receive them. Runs as owner; the WHERE clause reproduces '
  'the driver row-visibility rule.';

create view public.gmail_accounts_safe as
select
  id, admin_id, email_address, history_id, watch_expiration, watch_topic,
  last_sync_at, last_error, is_active, created_at, updated_at
from public.gmail_accounts
where public.is_admin();

comment on view public.gmail_accounts_safe is
  'Gmail accounts without the encrypted token columns. Admin-only.';

grant select on public.admin_rides         to authenticated;
grant select on public.driver_rides        to authenticated;
grant select on public.gmail_accounts_safe  to authenticated;
