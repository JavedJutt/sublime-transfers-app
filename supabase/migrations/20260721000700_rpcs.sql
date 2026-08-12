-- ============================================================================
-- Sublime Transfers — dispatch RPCs
--
-- All security definer, all pinned search_path. Business-rule failures are
-- raised with a machine-readable prefix (already_claimed, invalid_transition,
-- not_approved, forbidden, not_found) that ErrorMapper on the client turns into
-- the right AppException without string-matching prose.
--
-- Every driver-side RPC accepts p_client_event_id for offline idempotency: a
-- replayed action from the outbox is recognised via client_events and made a
-- no-op rather than double-applied.
-- ============================================================================

-- ---------------------------------------------- transition validity table ---
-- The only legal forward moves a driver can make. Admin overrides bypass this.
create or replace function public.is_legal_driver_transition(
  p_from public.ride_status,
  p_to   public.ride_status
) returns boolean
language sql
immutable
as $$
  select (p_from, p_to) in (
    ('assigned',    'en_route'),
    ('en_route',    'arrived'),
    ('arrived',     'in_progress'),
    ('in_progress', 'completed'),
    -- A driver may mark a no-show once at the pickup point.
    ('arrived',     'no_show')
  );
$$;

-- --------------------------------------------- idempotency claim helper ---
-- Returns true if this is the first time we've seen the event (caller should
-- proceed), false if it's a replay (caller should short-circuit). A null id
-- always proceeds (online path with no outbox).
create or replace function public.claim_client_event(
  p_client_event_id uuid,
  p_action text
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_client_event_id is null then
    return true;
  end if;
  insert into public.client_events (client_event_id, user_id, action)
  values (p_client_event_id, auth.uid(), p_action)
  on conflict (client_event_id) do nothing;
  return found;  -- found = row inserted = first time
end;
$$;

-- ======================================================= advance_ride_status ==
create or replace function public.advance_ride_status(
  p_ride_id         uuid,
  p_to              public.ride_status,
  p_lat             double precision default null,
  p_lng             double precision default null,
  p_accuracy_m      real             default null,
  p_captured_at     timestamptz      default null,
  p_client_event_id uuid             default null
) returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid := auth.uid();
  v_ride   public.rides;
  v_fresh  boolean;
  v_loc_missing boolean := (p_lat is null or p_lng is null);
begin
  if not public.is_approved_driver() then
    raise exception 'not_approved: your account is not approved';
  end if;

  v_fresh := public.claim_client_event(p_client_event_id, 'advance_ride_status');

  select * into v_ride from public.rides where id = p_ride_id for update;
  if not found then
    raise exception 'not_found: ride does not exist';
  end if;

  -- Replay of an already-applied advance: return the current row, no-op.
  if not v_fresh then
    return v_ride;
  end if;

  if v_ride.assigned_driver_id is distinct from v_driver then
    raise exception 'forbidden: not your ride';
  end if;

  if not public.is_legal_driver_transition(v_ride.status, p_to) then
    raise exception 'invalid_transition: % -> %', v_ride.status, p_to;
  end if;

  update public.rides
  set status = p_to,
      updated_at = now()
  where id = p_ride_id
  returning * into v_ride;

  -- Location is captured at EVERY status change (hard requirement). When the
  -- device could not produce a fix, the event is still written — flagged as
  -- location_unavailable — so the audit trail never silently loses the row.
  insert into public.ride_status_events (
    ride_id, from_status, to_status, actor_id, actor_role, action,
    driver_id, lat, lng, accuracy_m, captured_at, metadata
  )
  values (
    p_ride_id,
    -- from_status is the value before this update; recompute from p_to's parent
    -- is unnecessary — the trigger already logged the transition, but the RPC
    -- row carries the location, so we record both endpoints explicitly.
    (select from_status from public.ride_status_events
       where ride_id = p_ride_id order by id desc limit 1),
    p_to, v_driver, 'driver', 'status_advanced',
    v_driver, p_lat, p_lng, p_accuracy_m, coalesce(p_captured_at, now()),
    jsonb_build_object('location_unavailable', v_loc_missing, 'rpc', true)
  );

  -- Keep the driver's denormalised last-known position current.
  if not v_loc_missing then
    update public.driver_profiles
    set last_lat = p_lat, last_lng = p_lng, last_location_at = coalesce(p_captured_at, now())
    where id = v_driver;

    insert into public.location_pings (
      driver_id, ride_id, lat, lng, accuracy_m, source, captured_at
    )
    values (
      v_driver, p_ride_id, p_lat, p_lng, p_accuracy_m, 'status_change',
      coalesce(p_captured_at, now())
    );
  end if;

  -- Tell the source admin the ride moved.
  insert into public.notifications (user_id, type, title, body, ride_id)
  select r.source_admin_id, 'ride_updated', 'Ride ' || r.reference,
         (select full_name from public.profiles where id = v_driver)
           || ' → ' || p_to::text, r.id
  from public.rides r where r.id = p_ride_id;

  return v_ride;
end;
$$;

-- ======================================================= assign_ride_direct ==
create or replace function public.assign_ride_direct(
  p_ride_id   uuid,
  p_driver_id uuid
) returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_ride  public.rides;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  select * into v_ride from public.rides where id = p_ride_id for update;
  if not found then
    raise exception 'not_found: ride does not exist';
  end if;
  if v_ride.status in ('completed', 'cancelled', 'no_show') then
    raise exception 'invalid_transition: ride is closed';
  end if;

  if not exists (
    select 1 from public.driver_profiles
    where id = p_driver_id and approval_status = 'approved'
  ) then
    raise exception 'forbidden: driver is not approved';
  end if;

  -- Withdraw any outstanding offers/broadcast; a new direct offer replaces them.
  update public.ride_offers set status = 'withdrawn', responded_at = now()
  where ride_id = p_ride_id and status = 'pending';

  update public.rides
  set status = 'offered',
      assigned_driver_id = null,
      assigning_admin_id = v_admin,
      assignment_method = 'direct',
      broadcast_open = false,
      updated_at = now()
  where id = p_ride_id
  returning * into v_ride;

  insert into public.ride_offers (ride_id, driver_id, method, offered_by)
  values (p_ride_id, p_driver_id, 'direct', v_admin);

  insert into public.ride_status_events (
    ride_id, from_status, to_status, actor_id, actor_role, action, driver_id, metadata
  )
  values (p_ride_id, v_ride.status, 'offered', v_admin, 'admin', 'assigned',
          p_driver_id, jsonb_build_object('method', 'direct', 'rpc', true));

  insert into public.notifications (user_id, type, title, body, ride_id)
  values (p_driver_id, 'offer', 'New ride offer',
          'You have a direct offer for ' || v_ride.reference, p_ride_id);

  return v_ride;
end;
$$;

-- ======================================================== respond_to_offer ==
-- Driver accepts or declines a direct offer. Decline reverts the ride to
-- unassigned and notifies the assigning + source admins.
create or replace function public.respond_to_offer(
  p_ride_id         uuid,
  p_accept          boolean,
  p_reason          text default null,
  p_lat             double precision default null,
  p_lng             double precision default null,
  p_accuracy_m      real default null,
  p_captured_at     timestamptz default null,
  p_client_event_id uuid default null
) returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid := auth.uid();
  v_ride   public.rides;
  v_offer  public.ride_offers;
  v_fresh  boolean;
begin
  if not public.is_approved_driver() then
    raise exception 'not_approved: your account is not approved';
  end if;

  v_fresh := public.claim_client_event(p_client_event_id, 'respond_to_offer');

  select * into v_ride from public.rides where id = p_ride_id for update;
  if not found then
    raise exception 'not_found: ride does not exist';
  end if;
  if not v_fresh then
    return v_ride;  -- replay
  end if;

  select * into v_offer from public.ride_offers
  where ride_id = p_ride_id and driver_id = v_driver
    and status = 'pending' and method = 'direct'
  order by offered_at desc limit 1;
  if not found then
    raise exception 'invalid_transition: no pending offer for you';
  end if;

  if p_accept then
    update public.ride_offers set status = 'accepted', responded_at = now()
    where id = v_offer.id;

    update public.rides
    set status = 'assigned',
        assigned_driver_id = v_driver,
        assignment_method = 'direct',
        assigned_at = now(),
        updated_at = now()
    where id = p_ride_id
    returning * into v_ride;

    insert into public.ride_status_events (
      ride_id, from_status, to_status, actor_id, actor_role, action,
      driver_id, lat, lng, accuracy_m, captured_at, metadata
    )
    values (p_ride_id, 'offered', 'assigned', v_driver, 'driver',
            'offer_accepted', v_driver, p_lat, p_lng, p_accuracy_m,
            coalesce(p_captured_at, now()), jsonb_build_object('rpc', true));

    insert into public.notifications (user_id, type, title, body, ride_id)
    select r.source_admin_id, 'ride_updated', 'Offer accepted',
           (select full_name from public.profiles where id = v_driver)
             || ' accepted ' || r.reference, r.id
    from public.rides r where r.id = p_ride_id;
  else
    update public.ride_offers
    set status = 'declined', responded_at = now(), decline_reason = p_reason
    where id = v_offer.id;

    update public.rides
    set status = 'unassigned',
        assigned_driver_id = null,
        assigning_admin_id = null,
        assignment_method = null,
        updated_at = now()
    where id = p_ride_id
    returning * into v_ride;

    insert into public.ride_status_events (
      ride_id, from_status, to_status, actor_id, actor_role, action,
      driver_id, note, metadata
    )
    values (p_ride_id, 'offered', 'unassigned', v_driver, 'driver',
            'offer_declined', v_driver, p_reason, jsonb_build_object('rpc', true));

    -- Notify the source admin and, if different, the assigning admin.
    insert into public.notifications (user_id, type, title, body, ride_id)
    select distinct admin_id, 'offer_declined', 'Offer declined',
           (select full_name from public.profiles where id = v_driver)
             || ' declined ' || v_ride.reference
             || coalesce(' — ' || p_reason, ''), p_ride_id
    from (
      select v_ride.source_admin_id as admin_id
      union
      select v_offer.offered_by
    ) a
    where admin_id is not null;
  end if;

  return v_ride;
end;
$$;

-- ========================================================== broadcast_ride ==
create or replace function public.broadcast_ride(
  p_ride_id uuid
) returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_ride  public.rides;
  v_count int;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  select * into v_ride from public.rides where id = p_ride_id for update;
  if not found then
    raise exception 'not_found: ride does not exist';
  end if;
  if v_ride.status in ('completed', 'cancelled', 'no_show') then
    raise exception 'invalid_transition: ride is closed';
  end if;

  update public.ride_offers set status = 'withdrawn', responded_at = now()
  where ride_id = p_ride_id and status = 'pending';

  update public.rides
  set status = 'unassigned',
      assigned_driver_id = null,
      assigning_admin_id = v_admin,
      assignment_method = 'broadcast',
      broadcast_open = true,
      broadcast_started_at = now(),
      updated_at = now()
  where id = p_ride_id
  returning * into v_ride;

  -- Fan out an offer + notification to every approved, on-duty driver.
  insert into public.ride_offers (ride_id, driver_id, method, offered_by)
  select p_ride_id, dp.id, 'broadcast', v_admin
  from public.driver_profiles dp
  where dp.approval_status = 'approved' and dp.is_on_duty;
  get diagnostics v_count = row_count;

  insert into public.notifications (user_id, type, title, body, ride_id)
  select dp.id, 'offer', 'Ride available',
         'A ride is open to claim: ' || v_ride.reference, p_ride_id
  from public.driver_profiles dp
  where dp.approval_status = 'approved' and dp.is_on_duty;

  insert into public.ride_status_events (
    ride_id, from_status, to_status, actor_id, actor_role, action, metadata
  )
  values (p_ride_id, v_ride.status, 'unassigned', v_admin, 'admin', 'assigned',
          jsonb_build_object('method', 'broadcast', 'recipients', v_count, 'rpc', true));

  return v_ride;
end;
$$;

-- ==================================================== claim_broadcast_ride ==
-- The atomic claim. FOR UPDATE (not SKIP LOCKED) so a losing claimer BLOCKS,
-- then re-reads the winner's committed row and reports already_claimed — the
-- correct message. SKIP LOCKED would make a loser report not_found instead.
create or replace function public.claim_broadcast_ride(
  p_ride_id         uuid,
  p_lat             double precision default null,
  p_lng             double precision default null,
  p_accuracy_m      real default null,
  p_captured_at     timestamptz default null,
  p_client_event_id uuid default null
) returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid := auth.uid();
  v_ride   public.rides;
  v_fresh  boolean;
begin
  if not public.is_approved_driver() then
    raise exception 'not_approved: your account is not approved';
  end if;

  v_fresh := public.claim_client_event(p_client_event_id, 'claim_broadcast_ride');

  -- Serialize all concurrent claimers on this row.
  select * into v_ride from public.rides where id = p_ride_id for update;
  if not found then
    raise exception 'not_found: ride does not exist';
  end if;

  if not v_fresh then
    -- Replay: report success only if this driver actually holds it.
    if v_ride.assigned_driver_id = v_driver then
      return v_ride;
    end if;
    raise exception 'already_claimed: taken by another driver';
  end if;

  if not v_ride.broadcast_open or v_ride.assigned_driver_id is not null then
    raise exception 'already_claimed: taken by another driver';
  end if;
  if v_ride.status not in ('unassigned', 'offered') then
    raise exception 'invalid_transition: ride is not claimable';
  end if;

  update public.rides
  set assigned_driver_id = v_driver,
      assignment_method = 'broadcast',
      status = 'assigned',
      broadcast_open = false,
      assigned_at = now(),
      claimed_at = now(),
      updated_at = now()
  where id = p_ride_id
  returning * into v_ride;

  -- Expire the losers' offers; accept the winner's.
  update public.ride_offers set status = 'expired', responded_at = now()
  where ride_id = p_ride_id and status = 'pending' and driver_id <> v_driver;
  update public.ride_offers set status = 'accepted', responded_at = now()
  where ride_id = p_ride_id and driver_id = v_driver and status = 'pending';

  insert into public.ride_status_events (
    ride_id, from_status, to_status, actor_id, actor_role, action,
    driver_id, lat, lng, accuracy_m, captured_at, metadata
  )
  values (p_ride_id, 'unassigned', 'assigned', v_driver, 'driver', 'claimed',
          v_driver, p_lat, p_lng, p_accuracy_m, coalesce(p_captured_at, now()),
          jsonb_build_object('rpc', true));

  insert into public.notifications (user_id, type, title, body, ride_id)
  select r.source_admin_id, 'ride_updated', 'Broadcast claimed',
         (select full_name from public.profiles where id = v_driver)
           || ' claimed ' || r.reference, r.id
  from public.rides r where r.id = p_ride_id;

  return v_ride;
end;
$$;

-- ================================================= admin_override_assignment ==
-- Reassign or cancel a ride at any status. This is the admin's full override.
create or replace function public.admin_override_assignment(
  p_ride_id   uuid,
  p_action    text,               -- 'reassign' | 'unassign' | 'cancel'
  p_driver_id uuid default null,
  p_reason    text default null
) returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_ride  public.rides;
  v_prev_driver uuid;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  select * into v_ride from public.rides where id = p_ride_id for update;
  if not found then
    raise exception 'not_found: ride does not exist';
  end if;
  v_prev_driver := v_ride.assigned_driver_id;

  update public.ride_offers set status = 'withdrawn', responded_at = now()
  where ride_id = p_ride_id and status = 'pending';

  if p_action = 'reassign' then
    if p_driver_id is null then
      raise exception 'forbidden: driver required for reassign';
    end if;
    if not exists (
      select 1 from public.driver_profiles
      where id = p_driver_id and approval_status = 'approved'
    ) then
      raise exception 'forbidden: driver is not approved';
    end if;
    update public.rides
    set status = 'assigned',
        assigned_driver_id = p_driver_id,
        assigning_admin_id = v_admin,
        assignment_method = 'direct',
        assigned_at = now(),
        broadcast_open = false,
        updated_at = now()
    where id = p_ride_id
    returning * into v_ride;

    insert into public.notifications (user_id, type, title, body, ride_id)
    values (p_driver_id, 'ride_updated', 'Ride assigned to you',
            'An admin assigned you ' || v_ride.reference, p_ride_id);

  elsif p_action = 'unassign' then
    update public.rides
    set status = 'unassigned',
        assigned_driver_id = null,
        assigning_admin_id = null,
        assignment_method = null,
        broadcast_open = false,
        updated_at = now()
    where id = p_ride_id
    returning * into v_ride;

  elsif p_action = 'cancel' then
    update public.rides
    set status = 'cancelled',
        broadcast_open = false,
        cancelled_reason = p_reason,
        updated_at = now()
    where id = p_ride_id
    returning * into v_ride;

  else
    raise exception 'forbidden: unknown action %', p_action;
  end if;

  insert into public.ride_status_events (
    ride_id, from_status, to_status, actor_id, actor_role, action,
    driver_id, note, metadata
  )
  values (p_ride_id, v_ride.status, v_ride.status, v_admin, 'admin',
          'reassigned', v_ride.assigned_driver_id, p_reason,
          jsonb_build_object('override', p_action, 'prev_driver', v_prev_driver, 'rpc', true));

  -- Tell a bumped driver their ride was taken away.
  if v_prev_driver is not null and v_prev_driver is distinct from v_ride.assigned_driver_id then
    insert into public.notifications (user_id, type, title, body, ride_id)
    values (v_prev_driver, 'ride_updated', 'Ride reassigned',
            v_ride.reference || ' was reassigned by dispatch', p_ride_id);
  end if;

  return v_ride;
end;
$$;

-- ------------------------------------------------------- driver duty toggle ---
create or replace function public.set_driver_duty(p_on_duty boolean)
returns public.driver_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.driver_profiles;
begin
  if not public.is_approved_driver() then
    raise exception 'not_approved: your account is not approved';
  end if;
  update public.driver_profiles
  set is_on_duty = p_on_duty, updated_at = now()
  where id = auth.uid()
  returning * into v_row;
  return v_row;
end;
$$;

-- ----------------------------------------------------------- driver approval ---
create or replace function public.review_driver(
  p_driver_id uuid,
  p_approve   boolean,
  p_reason    text default null
) returns public.driver_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_row   public.driver_profiles;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  update public.driver_profiles
  set approval_status = case when p_approve then 'approved' else 'rejected' end,
      approved_by = v_admin,
      approved_at = now(),
      rejection_reason = case when p_approve then null else p_reason end,
      updated_at = now()
  where id = p_driver_id
  returning * into v_row;
  if not found then
    raise exception 'not_found: driver does not exist';
  end if;

  insert into public.notifications (user_id, type, title, body)
  values (
    p_driver_id, 'driver_pending',
    case when p_approve then 'Account approved' else 'Application declined' end,
    case when p_approve
         then 'You can now receive rides.'
         else coalesce(p_reason, 'Your application was not approved.') end
  );

  return v_row;
end;
$$;

-- Lock down execute grants: authenticated only, never anon.
revoke all on function public.advance_ride_status       from public, anon;
revoke all on function public.assign_ride_direct         from public, anon;
revoke all on function public.respond_to_offer           from public, anon;
revoke all on function public.broadcast_ride             from public, anon;
revoke all on function public.claim_broadcast_ride       from public, anon;
revoke all on function public.admin_override_assignment  from public, anon;
revoke all on function public.set_driver_duty            from public, anon;
revoke all on function public.review_driver              from public, anon;

grant execute on function public.advance_ride_status       to authenticated;
grant execute on function public.assign_ride_direct        to authenticated;
grant execute on function public.respond_to_offer          to authenticated;
grant execute on function public.broadcast_ride            to authenticated;
grant execute on function public.claim_broadcast_ride      to authenticated;
grant execute on function public.admin_override_assignment to authenticated;
grant execute on function public.set_driver_duty           to authenticated;
grant execute on function public.review_driver             to authenticated;
