-- ---------------------------------------------------------------------------
-- admin_gmail_accounts — the Gmail settings read model.
-- ---------------------------------------------------------------------------
-- Base `gmail_accounts` is client-revoked because it holds the encrypted OAuth
-- tokens. The settings screen reads through this owner-run view, which projects
-- only the status columns a human needs (never the token ciphertext) and
-- carries the is_admin() predicate — same pattern as admin_rides/admin_emails.
create or replace view public.admin_gmail_accounts as
select
  g.id,
  g.admin_id,
  g.email_address,
  g.history_id is not null       as is_watching,
  g.watch_expiration,
  g.last_sync_at,
  g.last_error,
  g.is_active,
  g.created_at,
  owner.full_name                as admin_name
from public.gmail_accounts g
left join public.profiles owner on owner.id = g.admin_id
where public.is_admin();

grant select on public.admin_gmail_accounts to authenticated;
