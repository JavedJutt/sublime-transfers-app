-- ============================================================================
-- Sublime Transfers — tables
--
-- One shared ride pool across all admins. `source_admin_id` is metadata on the
-- shared record, visible to admins only — that visibility is enforced later by
-- routing driver reads through a view that omits the column (see the views
-- migration), not by anything here.
-- ============================================================================

-- ---------------------------------------------------------------- profiles ---
-- One row per auth user, created by a trigger on auth.users (auth migration).
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  role        public.user_role not null,
  full_name   text not null,
  email       text not null,
  phone       text,
  avatar_url  text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Application profile per auth user. Role is immutable after creation via RLS.';

-- ------------------------------------------------------- driver_profiles ---
-- Driver-specific extension of a profile. Only exists for role = 'driver'.
create table public.driver_profiles (
  id                uuid primary key
                      references public.profiles (id) on delete cascade,
  approval_status   public.driver_status not null default 'pending',
  approved_by       uuid references public.profiles (id),
  approved_at       timestamptz,
  rejection_reason  text,
  vehicle_type      public.vehicle_type,
  vehicle_make      text,
  vehicle_plate     text,
  licence_number    text,
  is_on_duty        boolean not null default false,
  -- Last known position, denormalised from location_pings for cheap map reads.
  last_lat          double precision,
  last_lng          double precision,
  last_location_at  timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index driver_profiles_approved_idx
  on public.driver_profiles (approval_status)
  where approval_status = 'approved';
create index driver_profiles_onduty_idx
  on public.driver_profiles (is_on_duty)
  where is_on_duty;

-- -------------------------------------------------------- inbound_emails ---
-- Declared before rides because rides.source_email_id references it.
create table public.inbound_emails (
  id                uuid primary key default gen_random_uuid(),
  gmail_account_id  uuid not null,  -- FK added after gmail_accounts exists
  admin_id          uuid not null references public.profiles (id),
  gmail_message_id  text not null,
  thread_id         text,
  from_address      text,
  subject           text,
  received_at       timestamptz,
  body_text         text,
  body_html         text,
  parse_status      public.parse_status not null default 'needs_review',
  parsed_payload    jsonb,
  confidence        real,
  model_id          text,
  parse_error       text,
  reviewed_by       uuid references public.profiles (id),
  reviewed_at       timestamptz,
  created_ride_id   uuid,           -- FK added after rides exists
  created_at        timestamptz not null default now(),
  -- Webhook idempotency: Pub/Sub is at-least-once, so the same message can be
  -- delivered repeatedly. This makes re-insertion a no-op.
  unique (gmail_account_id, gmail_message_id)
);

create index inbound_emails_review_idx
  on public.inbound_emails (created_at desc)
  where parse_status = 'needs_review';

-- ------------------------------------------------------------------ rides ---
create table public.rides (
  id                    uuid primary key default gen_random_uuid(),
  -- Human-facing reference. Short, unique, generated on insert.
  reference             text not null unique
                          default 'ST-' ||
                            upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8)),

  -- Core booking fields (requirements §2.2).
  pickup_at             timestamptz not null,   -- PRIMARY calendar sort key
  customer_name         text not null,
  customer_phone        text,
  pickup_address        text not null,
  pickup_lat            double precision,
  pickup_lng            double precision,
  dropoff_address       text not null,
  dropoff_lat           double precision,
  dropoff_lng           double precision,
  passengers            smallint not null default 1
                          check (passengers between 0 and 60),
  luggage               smallint not null default 0 check (luggage >= 0),
  fare_amount           numeric(10, 2),
  fare_currency         char(3) not null default 'GBP',
  vehicle_type          public.vehicle_type,
  flight_number         text,
  notes                 text,

  -- Dispatch state.
  status                public.ride_status not null default 'unassigned',
  source_admin_id       uuid not null references public.profiles (id),  -- ADMIN-ONLY
  source_email_id       uuid references public.inbound_emails (id),
  assigned_driver_id    uuid references public.profiles (id),
  assigning_admin_id    uuid references public.profiles (id),
  assignment_method     public.assignment_method,
  assigned_at           timestamptz,
  broadcast_open        boolean not null default false,
  broadcast_started_at  timestamptz,
  claimed_at            timestamptz,
  cancelled_reason      text,

  created_by            uuid not null references public.profiles (id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  -- A ride is either unassigned/draft/cancelled with no driver, or it is
  -- offered, or it has a driver. Guards against an inconsistent write that
  -- bypasses the RPCs.
  constraint rides_assignment_coherent check (
    (assigned_driver_id is null
       and status in ('draft', 'unassigned', 'cancelled', 'no_show'))
    or status = 'offered'
    or assigned_driver_id is not null
  )
);

create index rides_pickup_idx           on public.rides (pickup_at);
create index rides_status_pickup_idx    on public.rides (status, pickup_at);
create index rides_driver_pickup_idx    on public.rides (assigned_driver_id, pickup_at)
                                         where assigned_driver_id is not null;
create index rides_broadcast_idx        on public.rides (pickup_at)
                                         where broadcast_open;
create index rides_unassigned_idx       on public.rides (pickup_at)
                                         where status = 'unassigned';
create index rides_source_admin_idx     on public.rides (source_admin_id);

-- Back-references now that both tables exist.
alter table public.inbound_emails
  add constraint inbound_emails_created_ride_fk
  foreign key (created_ride_id) references public.rides (id) on delete set null;

-- ------------------------------------------------- ride_status_events ---
-- Append-only audit log. Every status change, assignment, edit, and location
-- capture lands here with who did it and when.
create table public.ride_status_events (
  id           bigint generated always as identity primary key,
  ride_id      uuid not null references public.rides (id) on delete cascade,
  from_status  public.ride_status,
  to_status    public.ride_status not null,
  actor_id     uuid references public.profiles (id),
  actor_role   public.user_role,
  action       text not null,   -- created | assigned | offer_accepted |
                                 -- offer_declined | claimed | status_advanced |
                                 -- reassigned | cancelled | edited
  driver_id    uuid references public.profiles (id),
  lat          double precision,
  lng          double precision,
  accuracy_m   real,
  captured_at  timestamptz,     -- device clock at the moment of capture
  note         text,
  metadata     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index ride_status_events_ride_idx
  on public.ride_status_events (ride_id, created_at desc);

-- ------------------------------------------------------------ ride_offers ---
create table public.ride_offers (
  id             uuid primary key default gen_random_uuid(),
  ride_id        uuid not null references public.rides (id) on delete cascade,
  driver_id      uuid not null references public.profiles (id) on delete cascade,
  method         public.assignment_method not null,
  status         public.offer_status not null default 'pending',
  offered_by     uuid references public.profiles (id),
  offered_at     timestamptz not null default now(),
  responded_at   timestamptz,
  decline_reason text
);

create index ride_offers_driver_pending_idx
  on public.ride_offers (driver_id)
  where status = 'pending';

-- At most one live *direct* offer per ride. Broadcast offers are many-per-ride
-- (one per driver) so they are excluded from this constraint.
create unique index ride_offers_one_active_direct
  on public.ride_offers (ride_id)
  where status = 'pending' and method = 'direct';

-- ---------------------------------------------------------- location_pings ---
create table public.location_pings (
  id          bigint generated always as identity primary key,
  driver_id   uuid not null references public.profiles (id) on delete cascade,
  ride_id     uuid references public.rides (id) on delete set null,
  lat         double precision not null,
  lng         double precision not null,
  accuracy_m  real,
  heading     real,
  speed_mps   real,
  source      text not null default 'status_change',  -- status_change | stream
  captured_at timestamptz not null,
  created_at  timestamptz not null default now()
);

create index location_pings_driver_idx
  on public.location_pings (driver_id, captured_at desc);
create index location_pings_ride_idx
  on public.location_pings (ride_id, captured_at);

-- ---------------------------------------------------------- gmail_accounts ---
create table public.gmail_accounts (
  id                 uuid primary key default gen_random_uuid(),
  admin_id           uuid not null references public.profiles (id) on delete cascade,
  email_address      text not null,
  -- Tokens are stored encrypted by the Edge Functions (Vault); never returned
  -- to any client — no RLS policy exposes these columns to app roles.
  refresh_token_enc  text,
  access_token_enc   text,
  access_expires_at  timestamptz,
  history_id         bigint,
  watch_expiration   timestamptz,
  watch_topic        text,
  last_sync_at       timestamptz,
  last_error         text,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (admin_id, email_address)
);

create index gmail_accounts_watch_exp_idx
  on public.gmail_accounts (watch_expiration)
  where is_active;

alter table public.inbound_emails
  add constraint inbound_emails_gmail_account_fk
  foreign key (gmail_account_id)
  references public.gmail_accounts (id) on delete cascade;

-- ----------------------------------------------------------- device_tokens ---
-- FCM registration tokens. Unused until the FCM phase, but the table exists so
-- the notification interface has somewhere to write from day one.
create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  token      text not null unique,
  platform   text not null,   -- ios | android | web
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ----------------------------------------------------------- notifications ---
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  type       text not null,  -- offer | offer_declined | ride_updated |
                              -- driver_pending | parse_review | gmail_sync_failed
  title      text not null,
  body       text not null,
  ride_id    uuid references public.rides (id) on delete cascade,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_unread_idx
  on public.notifications (user_id, created_at desc)
  where read_at is null;

-- ------------------------------------------------------------ client_events ---
-- Offline idempotency ledger. Every driver-side RPC records the client-supplied
-- event id here; a replay from the outbox is recognised and made a no-op.
create table public.client_events (
  client_event_id uuid primary key,
  user_id         uuid not null references public.profiles (id),
  action          text not null,
  created_at      timestamptz not null default now()
);
