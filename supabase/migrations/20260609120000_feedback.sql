-- Moongate v0.6.x - In-app feedback / bug reports table.
--
-- Backs the "Report a problem" item in the app drawer. The app POSTs a
-- comment (+ optional contact, the printer it's about, and auto-collected
-- diagnostics) to the submit-feedback Edge Function, which inserts one row
-- here via the service role.
--
-- Consistent with the rest of the schema (see 20260526120000_v03_initial):
--   • Clients NEVER write directly - only the Edge Function (service role)
--     does, so ALL privileges are revoked from anon/authenticated and no
--     RLS policy is defined. Reads happen in the dashboard / SQL editor.
--   • user_id is the anonymous submitter. ON DELETE SET NULL (not CASCADE)
--     so a report survives the 6-week orphan-user cleanup sweep - the text
--     is what we care about, not the throwaway anon identity.
--
-- Idempotent (IF NOT EXISTS). Safe to re-run.

BEGIN;

-- ============================================================================
-- 1. TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.feedback (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    timestamptz NOT NULL DEFAULT now(),
  user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  app_version   text,
  platform      text,
  printer_name  text,
  contact       text,
  comment       text NOT NULL,
  diagnostics   jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT feedback_comment_len CHECK (char_length(comment) BETWEEN 1 AND 5000),
  CONSTRAINT feedback_contact_len CHECK (contact IS NULL OR char_length(contact) <= 200)
);

COMMENT ON TABLE public.feedback IS
  'In-app bug reports / feedback. Written ONLY by the submit-feedback Edge Function (service role); clients have no direct access. Read via the dashboard. user_id is the anon submitter (nullable so reports outlive the orphan-user cleanup sweep).';

-- ============================================================================
-- 2. INDEX
-- ============================================================================

CREATE INDEX IF NOT EXISTS feedback_created_idx
  ON public.feedback (created_at DESC);

-- ============================================================================
-- 3. ROW-LEVEL SECURITY  (locked down exactly like printers/enrollment_tokens)
-- ============================================================================

ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- No policy is defined on purpose: with RLS enabled and no policy, the
-- anon/authenticated roles can do nothing here. The service role used by the
-- submit-feedback Edge Function bypasses RLS. Belt-and-braces REVOKE in case
-- a future default-privilege grant ever leaks in.
REVOKE ALL ON public.feedback FROM anon, authenticated;

COMMIT;
