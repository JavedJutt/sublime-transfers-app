-- ============================================================================
-- Sublime Transfers — realtime publication + scheduled jobs
-- ============================================================================

-- ------------------------------------------------------------ realtime ---
-- Admins subscribe to postgres_changes on these tables; RLS is applied to the
-- change stream, so an admin only receives rows they may see. Drivers do NOT
-- subscribe to `rides` directly (the change payload would carry
-- source_admin_id); the driver client subscribes to a broadcast channel that
-- the RPCs emit on, added in the assignment phase.
alter publication supabase_realtime add table public.rides;
alter publication supabase_realtime add table public.ride_offers;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.driver_profiles;

-- REPLICA IDENTITY FULL so UPDATE payloads include old values — the driver
-- offers list needs to know when broadcast_open flips to false to drop a row.
alter table public.rides replica identity full;
alter table public.ride_offers replica identity full;

-- ------------------------------------------------------------ cron jobs ---
-- Requires pg_cron. On Supabase it lives in the `cron` schema and must be
-- enabled once (done here idempotently).
create extension if not exists pg_cron with schema pg_catalog;

-- Close stale broadcasts: an open broadcast whose pickup time has passed is
-- garbage, not an offer. Close it and tell the source admin it went unclaimed.
-- (The spec forbids a claim *deadline*, not garbage collection.)
create or replace function public.close_stale_broadcasts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_ride  public.rides;
begin
  for v_ride in
    select * from public.rides
    where broadcast_open and pickup_at < now()
    for update skip locked
  loop
    update public.rides
    set broadcast_open = false, updated_at = now()
    where id = v_ride.id;

    update public.ride_offers set status = 'expired', responded_at = now()
    where ride_id = v_ride.id and status = 'pending';

    insert into public.notifications (user_id, type, title, body, ride_id)
    values (v_ride.source_admin_id, 'ride_updated', 'Broadcast expired',
            v_ride.reference || ' passed its pickup time unclaimed', v_ride.id);

    insert into public.ride_status_events (
      ride_id, from_status, to_status, actor_id, actor_role, action, metadata
    )
    values (v_ride.id, v_ride.status, v_ride.status, null, null,
            'status_advanced',
            jsonb_build_object('system', 'broadcast_closed_stale', 'rpc', true));

    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Every 5 minutes. Unschedule first so re-running this migration is safe.
select cron.unschedule('close-stale-broadcasts')
  where exists (select 1 from cron.job where jobname = 'close-stale-broadcasts');
select cron.schedule(
  'close-stale-broadcasts',
  '*/5 * * * *',
  $$select public.close_stale_broadcasts();$$
);
