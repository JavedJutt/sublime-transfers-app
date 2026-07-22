-- ============================================================================
-- Sublime Transfers — helper functions, auth wiring, updated_at triggers
-- ============================================================================

-- --------------------------------------------------- role helper functions ---
-- security definer so RLS policies can read `profiles` without recursing into
-- the profiles policies themselves (which would deadlock the policy check).
-- search_path is pinned to defeat search-path injection on a definer function.

create or replace function public.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  );
$$;

create or replace function public.is_approved_driver()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.driver_profiles d
    join public.profiles p on p.id = d.id
    where d.id = auth.uid()
      and d.approval_status = 'approved'
      and p.is_active
  );
$$;

-- ------------------------------------------------------ updated_at touch ---
create or replace function public.tg_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch
  before update on public.profiles
  for each row execute function public.tg_touch_updated_at();
create trigger driver_profiles_touch
  before update on public.driver_profiles
  for each row execute function public.tg_touch_updated_at();
create trigger gmail_accounts_touch
  before update on public.gmail_accounts
  for each row execute function public.tg_touch_updated_at();
create trigger device_tokens_touch
  before update on public.device_tokens
  for each row execute function public.tg_touch_updated_at();

-- ----------------------------------------------- new-user provisioning ---
-- Creates a profile (and a driver_profile for drivers) when an auth user is
-- created. Role and name come from the sign-up metadata; a driver created by
-- an admin can be pre-approved by passing approval_status in metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role            public.user_role;
  v_full_name       text;
  v_approval        public.driver_status;
begin
  v_role := coalesce(
    (new.raw_user_meta_data ->> 'role')::public.user_role,
    'driver'  -- self-service sign-ups default to driver; admins are seeded
  );
  v_full_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(new.email, '@', 1)
  );

  insert into public.profiles (id, role, full_name, email, phone)
  values (
    new.id,
    v_role,
    v_full_name,
    new.email,
    nullif(trim(new.raw_user_meta_data ->> 'phone'), '')
  );

  if v_role = 'driver' then
    v_approval := coalesce(
      (new.raw_user_meta_data ->> 'approval_status')::public.driver_status,
      'pending'
    );
    insert into public.driver_profiles (
      id, approval_status, vehicle_type, vehicle_make, vehicle_plate
    )
    values (
      new.id,
      v_approval,
      (new.raw_user_meta_data ->> 'vehicle_type')::public.vehicle_type,
      nullif(trim(new.raw_user_meta_data ->> 'vehicle_make'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'vehicle_plate'), '')
    );
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
