-- Continuous location streaming during a live ride (Phase 7, nice-to-have).
--
-- Capture at every status change is the hard requirement and already lands
-- inside advance_ride_status. THIS function is the higher-frequency stream used
-- only when CONTINUOUS_TRACKING is enabled: from en_route through completed the
-- driver app posts a batched position every ~30s. It writes one location_pings
-- row (source 'stream') and keeps the denormalised driver_profiles position
-- current so the admin live map glides between transitions instead of jumping.
--
-- security definer so the two writes are atomic and a driver can never touch
-- another driver's row; the ride must be the driver's own and live.
create or replace function public.record_location_ping(
  p_ride_id     uuid,
  p_lat         double precision,
  p_lng         double precision,
  p_accuracy_m  real        default null,
  p_heading     real        default null,
  p_speed_mps   real        default null,
  p_captured_at timestamptz default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid := auth.uid();
  v_ride   public.rides;
  v_at     timestamptz := coalesce(p_captured_at, now());
begin
  if not public.is_approved_driver() then
    raise exception 'not_approved: your account is not approved';
  end if;
  if p_lat is null or p_lng is null then
    raise exception 'invalid: lat/lng required';
  end if;

  select * into v_ride from public.rides where id = p_ride_id;
  if not found then
    raise exception 'not_found: ride does not exist';
  end if;
  if v_ride.assigned_driver_id is distinct from v_driver then
    raise exception 'forbidden: not your ride';
  end if;
  -- Only accept a stream while the ride is actually in flight. Silently ignore
  -- a stray late ping rather than error the driver's stream.
  if v_ride.status not in ('en_route', 'arrived', 'in_progress') then
    return;
  end if;

  insert into public.location_pings (
    driver_id, ride_id, lat, lng, accuracy_m, heading, speed_mps, source, captured_at
  )
  values (
    v_driver, p_ride_id, p_lat, p_lng, p_accuracy_m, p_heading, p_speed_mps, 'stream', v_at
  );

  -- Never let an out-of-order ping regress the last-known position.
  update public.driver_profiles
  set last_lat = p_lat, last_lng = p_lng, last_location_at = v_at
  where id = v_driver
    and (last_location_at is null or last_location_at < v_at);
end;
$$;

revoke all on function public.record_location_ping(
  uuid, double precision, double precision, real, real, real, timestamptz
) from public, anon;
grant execute on function public.record_location_ping(
  uuid, double precision, double precision, real, real, real, timestamptz
) to authenticated;
