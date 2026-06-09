-- Moongate v0.6.x — Backup restore grants.
--
-- Powers "restore brings machines back online without re-pairing". A printer's
-- ownership is bound to the app's anonymous Supabase identity, which is wiped
-- on uninstall, so a printer-list backup alone can't revive a pairing — the
-- reinstalled app is a different cloud user. A restore grant is a single-use,
-- expiring secret the owner mints at backup time (create-restore-grant) and
-- redeems after reinstall (redeem-restore-grant) to re-assign their existing
-- printer rows to the new identity.
--
-- Only SHA-256(secret) is stored (the raw secret lives only in the user's
-- backup file), mirroring enrollment_tokens. Locked down like every other
-- table: no direct client access; Edge Functions (service role) do all writes.
--
-- Idempotent. Safe to re-run.

BEGIN;

-- ============================================================================
-- 1. TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.restore_grants (
  token_hash       bytea PRIMARY KEY,                 -- SHA-256(raw secret)
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  expires_at       timestamptz NOT NULL,
  used_at          timestamptz,
  used_by_user_id  uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.restore_grants IS
  'Single-use, expiring secrets that let a reinstalled app reclaim its printers without re-pairing. Only SHA-256(secret) is stored; the raw secret lives only in the user backup file. Minted by create-restore-grant, consumed by redeem-restore-grant (re-assigns the grantor''s live printers to the redeemer).';

CREATE INDEX IF NOT EXISTS restore_grants_expires_idx
  ON public.restore_grants (expires_at);

-- ============================================================================
-- 2. ROW-LEVEL SECURITY  (Edge Functions only; no direct client access)
-- ============================================================================

ALTER TABLE public.restore_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.restore_grants FROM anon, authenticated;

-- ============================================================================
-- 3. RPCs  (SECURITY DEFINER — called by Edge Functions via the service role)
-- ============================================================================

-- Mint a grant for p_user_id. The Edge Function generated the secret and
-- passes only its hash; the 90-day expiry is fixed server-side.
CREATE OR REPLACE FUNCTION public.create_restore_grant(
  p_token_hash_b64 text,
  p_user_id        uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO restore_grants (token_hash, user_id, expires_at)
  VALUES (decode(p_token_hash_b64, 'base64'), p_user_id, now() + interval '90 days')
  ON CONFLICT (token_hash) DO NOTHING;
END;
$$;

COMMENT ON FUNCTION public.create_restore_grant IS
  'Called by Edge Function create-restore-grant. Stores SHA-256(secret) bound to the owner; 90-day expiry, single-use (consumed by redeem_restore_grant).';

-- Redeem a grant: re-assign all the grantor's live printers to p_new_user_id,
-- mark the grant used, and return the rebound printers. Constant 'not_found'
-- shape for any invalid (missing / expired / already-used) grant, mirroring
-- claim_printer's non-enumerating error path.
CREATE OR REPLACE FUNCTION public.redeem_restore_grant(
  p_token_hash_b64 text,
  p_new_user_id    uuid
)
RETURNS table(printer_id uuid, printer_name text, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_grant restore_grants%ROWTYPE;
BEGIN
  SELECT * INTO v_grant
  FROM restore_grants
  WHERE token_hash = decode(p_token_hash_b64, 'base64');

  IF NOT FOUND
     OR v_grant.expires_at < now()
     OR v_grant.used_at IS NOT NULL
  THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, 'not_found'::text;
    RETURN;
  END IF;

  -- Re-home the grantor's live printers onto the redeeming identity and
  -- return exactly those rows.
  RETURN QUERY
  WITH rebound AS (
    UPDATE printers
    SET owner_user_id = p_new_user_id
    WHERE owner_user_id = v_grant.user_id
      AND revoked_at IS NULL
    RETURNING id, name
  )
  SELECT rebound.id, rebound.name, 'ok'::text FROM rebound;

  -- Single-use: consume the grant.
  UPDATE restore_grants
  SET used_at = now(), used_by_user_id = p_new_user_id
  WHERE token_hash = v_grant.token_hash;
END;
$$;

COMMENT ON FUNCTION public.redeem_restore_grant IS
  'Called by Edge Function redeem-restore-grant. Validates the grant (exists, not expired, not used), re-assigns the grantor''s live printers to the redeemer, marks the grant used, returns the rebound printers. Single-use.';

COMMIT;
