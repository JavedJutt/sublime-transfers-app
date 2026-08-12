-- ============================================================================
-- Sublime Transfers — extensions & enums
--
-- All domain enums live here so later migrations can reference them freely.
-- Enum value order matters: it defines the natural sort order and, for
-- ride_status, follows the lifecycle so `order by status` is meaningful.
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

-- Roles. A user is exactly one of these; the two never share an account.
create type public.user_role as enum ('admin', 'driver');

-- Driver eligibility. A self-registered driver starts 'pending' and cannot
-- receive rides until an admin sets them 'approved'.
create type public.driver_status as enum (
  'pending', 'approved', 'rejected', 'suspended'
);

-- Ride lifecycle, in order.
--   draft       — created but not yet released to the pool (rare; manual holds)
--   unassigned  — in the pool, nobody assigned. Broadcasts live here too, with
--                 broadcast_open = true.
--   offered     — a direct offer is out to one driver, awaiting accept/decline.
--   assigned    — a driver has accepted (direct) or claimed (broadcast).
--   en_route    — driver is on the way to pickup.
--   arrived     — driver is at the pickup point.
--   in_progress — customer on board, ride underway.
--   completed   — done.
--   cancelled   — called off by an admin.
--   no_show     — customer never appeared.
create type public.ride_status as enum (
  'draft', 'unassigned', 'offered', 'assigned',
  'en_route', 'arrived', 'in_progress', 'completed',
  'cancelled', 'no_show'
);

-- How a ride reached its driver. Recorded per the requirements' audit needs.
create type public.assignment_method as enum ('direct', 'broadcast', 'manual');

-- Lifecycle of a single offer to a single driver.
create type public.offer_status as enum (
  'pending', 'accepted', 'declined', 'expired', 'withdrawn'
);

-- Vehicle classes. Kept small and fixed; the parser maps free text onto these.
create type public.vehicle_type as enum (
  'sedan', 'estate', 'mpv', 'executive', 'minibus'
);

-- Where an inbound email sits in the parse pipeline.
--   needs_review — default landing state; the parser must actively promote out
--   parsed       — confidently parsed, ride auto-created
--   rejected     — a reviewer decided it was not a booking
--   imported     — a reviewer approved a needs_review item into a ride
create type public.parse_status as enum (
  'needs_review', 'parsed', 'rejected', 'imported'
);
