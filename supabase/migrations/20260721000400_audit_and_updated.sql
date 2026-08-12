-- ============================================================================
-- Sublime Transfers — rides audit trigger
--
-- The RPCs write their own rich audit rows (with captured location). This
-- trigger is the safety net: it records anything that changes a ride outside
-- the RPCs — an admin edit, a direct table write — so the audit trail is
-- complete even when a mutation didn't come through a function.
--
-- Rows written here carry metadata.trigger = true, so the timeline widget can
-- prefer the RPC-authored row when both describe the same statement.
-- ============================================================================

create or replace function public.tg_rides_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_role  public.user_role := public.current_role();
begin
  if tg_op = 'INSERT' then
    insert into public.ride_status_events (
      ride_id, from_status, to_status, actor_id, actor_role, action, metadata
    )
    values (
      new.id, null, new.status, v_actor, v_role, 'created',
      jsonb_build_object(
        'trigger', true,
        'source', case when new.source_email_id is null then 'manual' else 'email' end
      )
    );
    return new;
  end if;

  -- UPDATE. Distinguish assignment changes, status changes, and field edits so
  -- the timeline can label each.
  if new.assigned_driver_id is distinct from old.assigned_driver_id then
    insert into public.ride_status_events (
      ride_id, from_status, to_status, actor_id, actor_role, action,
      driver_id, metadata
    )
    values (
      new.id, old.status, new.status, v_actor, v_role, 'reassigned',
      new.assigned_driver_id,
      jsonb_build_object('trigger', true, 'prev_driver', old.assigned_driver_id)
    );
  elsif new.status is distinct from old.status then
    insert into public.ride_status_events (
      ride_id, from_status, to_status, actor_id, actor_role, action, metadata
    )
    values (
      new.id, old.status, new.status, v_actor, v_role, 'status_advanced',
      jsonb_build_object('trigger', true)
    );
  else
    -- Field-level edit. Build a diff of everything that actually changed,
    -- excluding bookkeeping columns, so "admin can edit any ride" is auditable.
    declare
      v_changed jsonb;
    begin
      select jsonb_object_agg(o.key, jsonb_build_array(o.value, n.value))
        into v_changed
      from jsonb_each(to_jsonb(old)) o
      join jsonb_each(to_jsonb(new)) n on n.key = o.key
      where o.value is distinct from n.value
        and o.key not in ('updated_at');

      if v_changed is not null then
        insert into public.ride_status_events (
          ride_id, from_status, to_status, actor_id, actor_role, action, metadata
        )
        values (
          new.id, old.status, new.status, v_actor, v_role, 'edited',
          jsonb_build_object('trigger', true, 'changed', v_changed)
        );
      end if;
    end;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger rides_audit_insert
  after insert on public.rides
  for each row execute function public.tg_rides_audit();

create trigger rides_audit_update
  before update on public.rides
  for each row execute function public.tg_rides_audit();
