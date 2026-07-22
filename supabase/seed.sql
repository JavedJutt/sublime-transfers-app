-- ============================================================================
-- Sublime Transfers — development seed data
--
-- Auth users are created separately via the Auth Admin API (see
-- scripts/seed_users.py) because passwords can't be set through SQL. This file
-- assumes the five seeded profiles exist and populates rides across every
-- status so the calendar, filters, and driver views have real data on first
-- run.
--
-- Idempotent: deletes prior seeded rides (by reference prefix) before inserting.
-- Safe to re-run.
--
-- Seeded accounts (password: Password123!):
--   ava.admin@sublimetransfers.test      admin
--   noah.admin@sublimetransfers.test     admin
--   marcus.driver@sublimetransfers.test  driver, approved, executive
--   priya.driver@sublimetransfers.test   driver, approved, mpv
--   sam.driver@sublimetransfers.test     driver, PENDING approval
-- ============================================================================

do $$
declare
  ava    uuid := (select id from public.profiles where email = 'ava.admin@sublimetransfers.test');
  noah   uuid := (select id from public.profiles where email = 'noah.admin@sublimetransfers.test');
  marcus uuid := (select id from public.profiles where email = 'marcus.driver@sublimetransfers.test');
  priya  uuid := (select id from public.profiles where email = 'priya.driver@sublimetransfers.test');
  today  date := current_date;
begin
  if ava is null or noah is null then
    raise notice 'Seed users not found — run scripts/seed_users.py first. Skipping.';
    return;
  end if;

  -- Clear previously seeded rides so re-runs stay clean.
  delete from public.rides where reference like 'ST-SEED%';

  -- Put the two approved drivers on duty so broadcasts reach them.
  update public.driver_profiles set is_on_duty = true
    where id in (marcus, priya);

  -- Two admins split the source, so the admin-only source tag is exercised.
  -- Statuses span the whole lifecycle across today and the next few days.
  insert into public.rides (
    reference, pickup_at, customer_name, customer_phone,
    pickup_address, pickup_lat, pickup_lng,
    dropoff_address, dropoff_lat, dropoff_lng,
    passengers, luggage, fare_amount, vehicle_type, flight_number, notes,
    status, source_admin_id, created_by,
    assigned_driver_id, assigning_admin_id, assignment_method, assigned_at,
    broadcast_open, broadcast_started_at
  )
  values
  -- Unassigned, today
  ('ST-SEED01', today + time '08:15', 'Eleanor Fitzgerald', '+44 7700 900201',
   'Heathrow Terminal 5, Arrivals', 51.4723, -0.4876,
   'The Savoy, Strand, London WC2R 0EZ', 51.5101, -0.1206,
   2, 3, 145.00, 'executive', 'BA0284', 'Meet & greet at arrivals.',
   'unassigned', ava, ava, null, null, null, null, false, null),

  ('ST-SEED02', today + time '09:40', 'Hiroshi Tanaka', '+44 7700 900202',
   'Gatwick South Terminal', 51.1537, -0.1821,
   'Claridge''s, Brook Street, London W1K 4HR', 51.5129, -0.1478,
   1, 2, 130.00, 'executive', 'JL0043', null,
   'unassigned', noah, noah, null, null, null, null, false, null),

  -- Broadcast open, today
  ('ST-SEED03', today + time '11:00', 'Sofia Marchetti', '+44 7700 900203',
   'St Pancras International', 51.5320, -0.1263,
   'Canary Wharf, One Canada Square', 51.5049, -0.0195,
   3, 4, 95.00, 'mpv', null, 'Three adults plus luggage.',
   'unassigned', ava, ava, null, ava, 'broadcast', null, true, now()),

  -- Offered (direct) to Marcus, today
  ('ST-SEED04', today + time '13:30', 'James Okonkwo', '+44 7700 900204',
   'Mayfair, Berkeley Square', 51.5100, -0.1465,
   'London City Airport', 51.5048, 0.0495,
   1, 1, 80.00, 'sedan', null, null,
   'offered', noah, noah, null, noah, 'direct', null, false, null),

  -- Assigned, today (Marcus)
  ('ST-SEED05', today + time '15:00', 'Amelia Hart', '+44 7700 900205',
   'The Shard, 32 London Bridge St', 51.5045, -0.0865,
   'Heathrow Terminal 2', 51.4700, -0.4543,
   2, 2, 120.00, 'executive', 'LH0907', 'Flight departs 18:00.',
   'assigned', ava, ava, marcus, ava, 'direct', now(), false, null),

  -- En route, today (Priya)
  ('ST-SEED06', today + time '16:20', 'Wei Chen', '+44 7700 900206',
   'Kings Cross Station', 51.5308, -0.1238,
   'Stratford International', 51.5457, -0.0086,
   4, 5, 70.00, 'mpv', null, null,
   'en_route', noah, noah, priya, noah, 'direct', now(), false, null),

  -- Arrived at pickup, today (Marcus)
  ('ST-SEED07', today + time '17:00', 'Olivia Bennett', '+44 7700 900207',
   'Soho, Dean Street', 51.5136, -0.1315,
   'Heathrow Terminal 3', 51.4710, -0.4590,
   1, 1, 115.00, 'executive', 'AA0107', null,
   'arrived', ava, ava, marcus, ava, 'direct', now(), false, null),

  -- In progress, today (Priya)
  ('ST-SEED08', today + time '17:45', 'Mohammed Al-Rashid', '+44 7700 900208',
   'The Dorchester, Park Lane', 51.5074, -0.1521,
   'Gatwick North Terminal', 51.1594, -0.1608,
   2, 4, 135.00, 'mpv', 'EK0002', 'VIP — priority handling.',
   'in_progress', noah, noah, priya, noah, 'broadcast', now(), false, null),

  -- Completed earlier today (Marcus)
  ('ST-SEED09', today + time '06:30', 'Grace Sullivan', '+44 7700 900209',
   'Notting Hill, Portobello Road', 51.5170, -0.2050,
   'Heathrow Terminal 5', 51.4723, -0.4876,
   1, 2, 110.00, 'executive', 'BA0342', null,
   'completed', ava, ava, marcus, ava, 'direct', now() - interval '3 hours', false, null),

  -- Cancelled, today
  ('ST-SEED10', today + time '19:00', 'Daniel Weber', '+44 7700 900210',
   'Shoreditch, Old Street', 51.5255, -0.0876,
   'Luton Airport', 51.8747, -0.3683,
   2, 2, 90.00, 'sedan', null, 'Customer cancelled — flight changed.',
   'cancelled', noah, noah, null, null, null, null, false, null),

  -- Tomorrow: a spread for the week view
  ('ST-SEED11', today + interval '1 day' + time '07:00', 'Isabella Rossi', '+44 7700 900211',
   'Chelsea, Sloane Square', 51.4924, -0.1565,
   'Heathrow Terminal 4', 51.4590, -0.4460,
   1, 1, 118.00, 'executive', 'AZ0204', null,
   'unassigned', ava, ava, null, null, null, null, false, null),

  ('ST-SEED12', today + interval '1 day' + time '10:30', 'Lucas Andersson', '+44 7700 900212',
   'Canary Wharf, One Canada Square', 51.5049, -0.0195,
   'Stansted Airport', 51.8860, 0.2389,
   3, 3, 105.00, 'mpv', 'SK0502', null,
   'assigned', noah, noah, priya, noah, 'direct', now(), false, null),

  ('ST-SEED13', today + interval '1 day' + time '14:00', 'Fatima Nasser', '+44 7700 900213',
   'Westminster, Parliament Square', 51.5007, -0.1246,
   'London City Airport', 51.5048, 0.0495,
   2, 2, 85.00, 'sedan', 'BA0430', null,
   'unassigned', ava, ava, null, null, null, null, true, now()),

  ('ST-SEED14', today + interval '2 day' + time '09:15', 'Henry Clarke', '+44 7700 900214',
   'Islington, Upper Street', 51.5380, -0.1030,
   'Gatwick South Terminal', 51.1537, -0.1821,
   1, 1, 95.00, 'executive', 'EK0010', 'Early pickup, quiet ride requested.',
   'unassigned', noah, noah, null, null, null, null, false, null),

  ('ST-SEED15', today + interval '2 day' + time '18:30', 'Yuki Sato', '+44 7700 900215',
   'The Ritz, Piccadilly', 51.5073, -0.1416,
   'Heathrow Terminal 2', 51.4700, -0.4543,
   2, 3, 125.00, 'executive', 'NH0212', null,
   'assigned', ava, ava, marcus, ava, 'direct', now(), false, null),

  ('ST-SEED16', today + interval '3 day' + time '11:45', 'Emma Thompson', '+44 7700 900216',
   'Camden, Regent''s Park Road', 51.5416, -0.1550,
   'Luton Airport', 51.8747, -0.3683,
   4, 6, 100.00, 'minibus', 'W60123', 'Group of four with skis.',
   'unassigned', noah, noah, null, null, null, null, false, null),

  -- Yesterday: completed history
  ('ST-SEED17', today - interval '1 day' + time '13:00', 'Carlos Mendes', '+44 7700 900217',
   'Paddington Station', 51.5154, -0.1755,
   'Heathrow Terminal 5', 51.4723, -0.4876,
   1, 1, 112.00, 'executive', 'TP0234', null,
   'completed', ava, ava, marcus, ava, 'direct', now() - interval '1 day', false, null),

  ('ST-SEED18', today - interval '1 day' + time '16:30', 'Anna Kowalski', '+44 7700 900218',
   'Greenwich, Cutty Sark', 51.4820, -0.0096,
   'London City Airport', 51.5048, 0.0495,
   2, 2, 75.00, 'sedan', 'LO0282', null,
   'completed', noah, noah, priya, noah, 'broadcast', now() - interval '1 day', false, null),

  -- No-show, yesterday
  ('ST-SEED19', today - interval '1 day' + time '20:00', 'Robert Fox', '+44 7700 900219',
   'Victoria Station', 51.4952, -0.1441,
   'Gatwick South Terminal', 51.1537, -0.1821,
   1, 1, 88.00, 'sedan', null, 'Customer did not appear at pickup.',
   'no_show', ava, ava, marcus, ava, 'direct', now() - interval '1 day', false, null),

  -- A draft hold
  ('ST-SEED20', today + interval '4 day' + time '08:00', 'Nadia Petrova', '+44 7700 900220',
   'Marylebone, Baker Street', 51.5226, -0.1571,
   'Heathrow Terminal 3', 51.4710, -0.4590,
   2, 2, 120.00, 'executive', 'SU0242', 'Awaiting confirmation of flight time.',
   'draft', noah, noah, null, null, null, null, false, null);

  raise notice 'Seeded 20 rides across all statuses.';
end $$;
