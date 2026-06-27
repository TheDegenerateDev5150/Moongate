-- Enable Supabase Realtime on public.printers.
--
-- Why: the app learns each printer's online/offline state from `last_seen`
-- (bumped by the Pi's heartbeat). Reading it over Realtime - or via a plain
-- RLS-scoped SELECT - is NOT an Edge Function invocation, unlike /printer-access.
-- With this, the dashboard can show a powered-off printer as offline and skip
-- minting a token for it entirely, so an offline Pi costs zero Edge Function
-- calls. See mobile/lib/services/printer_liveness_service.dart.
--
-- Security: the existing "select own printers" RLS policy already scopes both
-- SELECT and Realtime delivery to the owner. REPLICA IDENTITY FULL puts the full
-- row (incl. owner_user_id) in the WAL so Realtime can evaluate that policy on
-- UPDATE events - a heartbeat only changes last_seen / tunnel_url, not
-- owner_user_id, so without FULL the policy column would be absent and the
-- update would not be delivered.
--
-- Idempotent: safe to re-run.

BEGIN;

ALTER TABLE public.printers REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename  = 'printers'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.printers;
  END IF;
END $$;

COMMIT;
