-- Moongate - Restrict the internal RPCs to the service role (least privilege).
--
-- These SECURITY DEFINER functions are an implementation detail of the Edge
-- Functions, which authenticate every caller and then invoke them via the
-- service-role client (adminClient in _shared/supabaseClients.ts). They are not
-- part of the public API, so they should be callable only by service_role.
--
-- Revoke EXECUTE from PUBLIC/anon/authenticated and grant it explicitly to
-- service_role for each, so the Edge Functions keep working while direct access
-- is removed. Idempotent; safe to re-run.

BEGIN;

REVOKE EXECUTE ON FUNCTION
  public.upsert_enrollment_token(text, text, int),
  public.claim_printer(text, text, text, uuid),
  public.get_printer_access(uuid, uuid),
  public.record_heartbeat(text, text, text),
  public.release_printer(uuid, uuid),
  public.release_printer_by_pubkey(text),
  public.create_restore_grant(text, uuid),
  public.redeem_restore_grant(text, uuid),
  public.moongate_cleanup_inactive()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.upsert_enrollment_token(text, text, int),
  public.claim_printer(text, text, text, uuid),
  public.get_printer_access(uuid, uuid),
  public.record_heartbeat(text, text, text),
  public.release_printer(uuid, uuid),
  public.release_printer_by_pubkey(text),
  public.create_restore_grant(text, uuid),
  public.redeem_restore_grant(text, uuid),
  public.moongate_cleanup_inactive()
TO service_role;

COMMIT;
