-- Moongate - releases become 1-week tombstones + the heartbeat learns to say why.
--
-- Context (2026-07-13 Edge Function quota work): an orphaned Pi - one whose
-- cloud row is gone - heartbeats forever, because a 404 cannot tell it whether
-- the row is gone for good (owner released it) or gone for ninety seconds
-- (a re-pair is mid-flight). Plugin 0.6.15 goes dormant the moment the server
-- answers "the owner released this printer", and the schema has had the
-- machinery for that answer since day one: printers.revoked_at is documented
-- as 'Soft delete. Set by MOONGATE_RESET_OWNER. Hard-deleted by cleanup cron
-- after 1 week.', and every read path already filters revoked_at IS NULL
-- (RLS "select own printers", claim_printer, get_printer_access,
-- record_heartbeat, send-push, restore grants) - the cleanup cron already
-- prunes revoked rows too. The two release RPCs just never set it: they
-- hard-deleted, so no revoked row has ever existed, and the 2026-06-24 /
-- 2026-07-13 spinner hunts also lost the released row's name instantly.
--
-- This migration:
--   1. release_printer / release_printer_by_pubkey: soft-delete
--      (revoked_at = now()) instead of DELETE. The existing cleanup cron
--      hard-deletes tombstones after 1 week. Account deletion
--      (delete-account) still hard-deletes via the FK CASCADE - personal
--      data does not tombstone. Tombstones never block a re-pair:
--      printers.pi_public_key has no unique constraint and claim_printer
--      only refuses on a LIVE row for the pubkey.
--   2. record_heartbeat_v2: same UPDATE as record_heartbeat but answers
--      'ok' / 'revoked' / 'not_found', so the printer-heartbeat Edge
--      Function can return 204 / 410 / 404. record_heartbeat (v1) is kept
--      until the function deploy has switched over - deploy order is
--      MIGRATION FIRST, THEN `supabase functions deploy printer-heartbeat`.
--
-- Enumeration note: distinguishing revoked from never-existed is safe here
-- because the Edge Function verifies the caller's Ed25519 signature against
-- the claimed pi_public_key BEFORE the lookup, so a caller can only ever
-- probe a key whose private half it already holds.

BEGIN;

-- ============================================================================
-- 1a. release_printer (user-JWT "Remove printer" path) - now a tombstone
-- ============================================================================

CREATE OR REPLACE FUNCTION public.release_printer(
  p_printer_id uuid,
  p_user_id    uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner uuid;
  v_pubkey text;
BEGIN
  SELECT owner_user_id, pi_public_key
    INTO v_owner, v_pubkey
  FROM printers
  WHERE id = p_printer_id AND revoked_at IS NULL;

  IF NOT FOUND THEN
    -- Idempotent: the row is already gone or already a tombstone.
    RETURN 'ok';
  END IF;

  IF v_owner <> p_user_id THEN
    RETURN 'not_found';
  END IF;

  UPDATE printers SET revoked_at = now() WHERE id = p_printer_id;
  DELETE FROM enrollment_tokens WHERE pi_public_key = v_pubkey;

  RETURN 'ok';
END;
$$;

COMMENT ON FUNCTION public.release_printer IS
  'Called by Edge Function release-printer. Owner-checked soft delete (revoked_at tombstone; cleanup cron hard-deletes after 1 week) + removes any pending enrollment token for the same Pi pubkey.';

-- ============================================================================
-- 1b. release_printer_by_pubkey (Pi-signed MOONGATE_RESET_OWNER path)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.release_printer_by_pubkey(
  p_pi_public_key text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Idempotent. The row may already be gone or tombstoned; the Pi might be
  -- retrying after a transient error, or the user may have triggered the
  -- app-side release flow first.
  UPDATE printers SET revoked_at = now()
  WHERE pi_public_key = p_pi_public_key AND revoked_at IS NULL;
  DELETE FROM enrollment_tokens WHERE pi_public_key = p_pi_public_key;
  RETURN 'ok';
END;
$$;

COMMENT ON FUNCTION public.release_printer_by_pubkey IS
  'Called by Edge Function release-printer on the Pi-signed force-release path. Authentication happens before the RPC call (Ed25519 signature verified against pi_public_key); this RPC is just the soft delete (revoked_at tombstone).';

-- ============================================================================
-- 2. record_heartbeat_v2 - distinguishes live / revoked / never-existed
-- ============================================================================

CREATE OR REPLACE FUNCTION public.record_heartbeat_v2(
  p_pi_public_key        text,
  p_tunnel_url_enc_b64   text,
  p_tunnel_url_nonce_b64 text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_printer_id uuid;
BEGIN
  UPDATE printers
  SET tunnel_url_enc   = decode(p_tunnel_url_enc_b64,   'base64'),
      tunnel_url_nonce = decode(p_tunnel_url_nonce_b64, 'base64'),
      last_seen        = now()
  WHERE pi_public_key = p_pi_public_key
    AND revoked_at IS NULL
  RETURNING id INTO v_printer_id;

  IF v_printer_id IS NOT NULL THEN
    RETURN 'ok';
  END IF;

  -- No live row. A tombstone means the owner deliberately released this Pi
  -- within the last week (before the cleanup cron prunes it) - the caller
  -- turns that into a 410 so plugin 0.6.15 can stop heartbeating instantly
  -- instead of probing a dead row for a day.
  IF EXISTS (SELECT 1 FROM printers
             WHERE pi_public_key = p_pi_public_key
               AND revoked_at IS NOT NULL) THEN
    RETURN 'revoked';
  END IF;

  RETURN 'not_found';
END;
$$;

COMMENT ON FUNCTION public.record_heartbeat_v2 IS
  'Called by Edge Function printer-heartbeat. Updates tunnel URL ciphertext from a Pi-signed payload; answers ok / revoked / not_found so the plugin can tell a deliberate release from a mid-repair gap. Supersedes record_heartbeat, which is kept until the function deploy switches over.';

-- Same least-privilege locking as the other internal RPCs (see
-- 20260619170000_lock_rpc_execute_to_service_role.sql). CREATE OR REPLACE
-- preserves the existing grants on the two release functions.
REVOKE EXECUTE ON FUNCTION public.record_heartbeat_v2(text, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_heartbeat_v2(text, text, text)
  TO service_role;

COMMIT;
