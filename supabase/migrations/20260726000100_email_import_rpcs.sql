-- ===========================================================================
-- Phase 6 — turning inbound emails into rides
-- ===========================================================================
-- The parser (Edge Function) and the admin review queue both need to promote an
-- inbound email into a real ride. The rules are identical either way — set the
-- source admin from the mailbox the email arrived in, link the email, default
-- the status — so the logic lives once in a private helper and two thin,
-- differently-gated entry points call it:
--   * create_ride_from_email  — service-role, used by the parser for the
--                               high-confidence auto-create path.
--   * import_reviewed_email   — admin-JWT, used by the review screen with the
--                               fields a human corrected.
-- A third RPC rejects an email that isn't a booking.
-- ===========================================================================

-- Safely coerce a payload's vehicle_type to the enum, tolerating junk/nulls.
create or replace function public._payload_vehicle_type(p_payload jsonb)
returns public.vehicle_type
language plpgsql
immutable
as $$
declare
  v text := nullif(p_payload->>'vehicle_type', '');
begin
  if v is null then
    return null;
  end if;
  return v::public.vehicle_type;
exception when others then
  return null;  -- unknown value: leave it for the reviewer, don't fail import
end;
$$;

-- The shared insert. Not security-gated itself — its callers are. Runs as the
-- definer so it can write to rides (clients have no direct insert grant).
create or replace function public._insert_ride_from_email(
  p_email_id uuid,
  p_payload  jsonb
)
returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email public.inbound_emails;
  v_ride  public.rides;
begin
  select * into v_email from public.inbound_emails where id = p_email_id;
  if not found then
    raise exception 'inbound email % not found', p_email_id
      using errcode = 'no_data_found';
  end if;

  if v_email.created_ride_id is not null then
    raise exception 'email % already imported as ride %',
      p_email_id, v_email.created_ride_id
      using errcode = 'unique_violation';
  end if;

  if coalesce(p_payload->>'pickup_at', '') = '' then
    raise exception 'pickup_at is required to create a ride'
      using errcode = 'not_null_violation';
  end if;
  if coalesce(p_payload->>'customer_name', '') = '' then
    raise exception 'customer_name is required to create a ride'
      using errcode = 'not_null_violation';
  end if;

  insert into public.rides (
    pickup_at,
    customer_name,
    customer_phone,
    pickup_address,
    dropoff_address,
    passengers,
    luggage,
    fare_amount,
    fare_currency,
    vehicle_type,
    flight_number,
    notes,
    status,
    source_admin_id,
    source_email_id,
    created_by
  ) values (
    (p_payload->>'pickup_at')::timestamptz,
    p_payload->>'customer_name',
    nullif(p_payload->>'customer_phone', ''),
    coalesce(nullif(p_payload->>'pickup_address', ''), 'Not provided'),
    coalesce(nullif(p_payload->>'dropoff_address', ''), 'Not provided'),
    coalesce((p_payload->>'passengers')::smallint, 1),
    coalesce((p_payload->>'luggage')::smallint, 0),
    (p_payload->>'fare_amount')::numeric,
    coalesce(nullif(p_payload->>'fare_currency', ''), 'GBP'),
    public._payload_vehicle_type(p_payload),
    nullif(p_payload->>'flight_number', ''),
    nullif(p_payload->>'notes', ''),
    'unassigned',
    v_email.admin_id,
    v_email.id,
    v_email.admin_id
  )
  returning * into v_ride;

  update public.inbound_emails
     set created_ride_id = v_ride.id,
         parse_status    = 'imported',
         reviewed_at     = now()
   where id = p_email_id;

  return v_ride;
end;
$$;

-- Parser auto-create path. Service-role only (the parser runs server-side); no
-- app role is granted execute.
create or replace function public.create_ride_from_email(
  p_email_id uuid,
  p_payload  jsonb
)
returns public.rides
language plpgsql
security definer
set search_path = public
as $$
begin
  return public._insert_ride_from_email(p_email_id, p_payload);
end;
$$;

-- Admin review path. The reviewer may have corrected any field; we take the
-- payload as given and record who imported it.
create or replace function public.import_reviewed_email(
  p_email_id uuid,
  p_payload  jsonb
)
returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ride public.rides;
begin
  if not public.is_admin() then
    raise exception 'only admins can import a reviewed email'
      using errcode = 'insufficient_privilege';
  end if;

  v_ride := public._insert_ride_from_email(p_email_id, p_payload);

  update public.inbound_emails
     set reviewed_by = auth.uid()
   where id = p_email_id;

  return v_ride;
end;
$$;

-- Reject an email that a reviewer judged not to be a booking (or a duplicate,
-- amendment, etc.). Leaves an audit trail of who and why.
create or replace function public.reject_inbound_email(
  p_email_id uuid,
  p_reason   text default null
)
returns public.inbound_emails
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email public.inbound_emails;
begin
  if not public.is_admin() then
    raise exception 'only admins can reject an email'
      using errcode = 'insufficient_privilege';
  end if;

  update public.inbound_emails
     set parse_status = 'rejected',
         parse_error  = coalesce(nullif(p_reason, ''), parse_error),
         reviewed_by  = auth.uid(),
         reviewed_at  = now()
   where id = p_email_id
  returning * into v_email;

  if not found then
    raise exception 'inbound email % not found', p_email_id
      using errcode = 'no_data_found';
  end if;

  return v_email;
end;
$$;

revoke all on function public.create_ride_from_email(uuid, jsonb) from public, anon, authenticated;
revoke all on function public._insert_ride_from_email(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.import_reviewed_email(uuid, jsonb) to authenticated;
grant execute on function public.reject_inbound_email(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- admin_emails — the review queue's read model.
-- ---------------------------------------------------------------------------
-- Base `inbound_emails` has its grant revoked from clients (defense in depth,
-- same as `rides`). The review screen reads through this owner-run view, which
-- carries its own is_admin() predicate — mirroring admin_rides/driver_rides —
-- and joins the mailbox address and reviewer name the UI needs. Owner-run (NOT
-- security_invoker) so it bypasses the base-table grant; auth.uid() still
-- reflects the caller, so the predicate is real.
create or replace view public.admin_emails as
select
  e.id,
  e.gmail_account_id,
  e.admin_id,
  e.gmail_message_id,
  e.thread_id,
  e.from_address,
  e.subject,
  e.received_at,
  e.body_text,
  e.parse_status,
  e.parsed_payload,
  e.confidence,
  e.model_id,
  e.parse_error,
  e.reviewed_by,
  e.reviewed_at,
  e.created_ride_id,
  e.created_at,
  ga.email_address as mailbox_address,
  reviewer.full_name as reviewed_by_name
from public.inbound_emails e
left join public.gmail_accounts ga on ga.id = e.gmail_account_id
left join public.profiles reviewer on reviewer.id = e.reviewed_by
where public.is_admin();

grant select on public.admin_emails to authenticated;
