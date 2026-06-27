-- Moongate - device push-notification tokens.
--
-- Backs background push notifications (iPhone first; the column is platform-
-- tagged so Android can join later without a schema change). Each phone that
-- opts in registers its delivery token here, and the send-push Edge Function
-- looks up a printer owner's tokens to deliver "print finished / failed"
-- alerts straight to Apple's APNs (and later Google's FCM).
--
-- Consistent with the rest of the schema (see 20260526120000_v03_initial and
-- 20260609120000_feedback):
--   • Clients NEVER write directly. The register-push-token Edge Function
--     (service role) upserts rows; ALL privileges are revoked from
--     anon/authenticated and no client RLS policy is defined.
--   • user_id is the anonymous owner. ON DELETE CASCADE - a token is useless
--     once its anon identity is cleaned up by the orphan sweep, so it goes
--     with it (unlike feedback, whose text we deliberately keep).
--   • token is UNIQUE: a given device token maps to exactly one row, so a
--     re-registration (or a token moving to a new anon user after a restore)
--     upserts in place instead of leaving duplicates. Dead tokens are pruned
--     by send-push when Apple/Google report them unregistered.
--
-- Idempotent (IF NOT EXISTS). Safe to re-run.

BEGIN;

-- ============================================================================
-- 1. TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.device_push_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token       text NOT NULL UNIQUE,
  platform    text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT device_push_tokens_platform_chk CHECK (platform IN ('ios', 'android')),
  CONSTRAINT device_push_tokens_token_len     CHECK (char_length(token) BETWEEN 1 AND 4096)
);

COMMENT ON TABLE public.device_push_tokens IS
  'Per-device push tokens for background notifications. Written ONLY by the register-push-token Edge Function (service role); read by send-push to target a printer owner''s devices. platform is ios/android (iOS shipped first). user_id is the anon owner (CASCADE: tokens die with the throwaway identity).';
COMMENT ON COLUMN public.device_push_tokens.token IS
  'APNs token (iOS) or FCM token (Android). Opaque delivery address from the OS; unique per device+install.';

-- ============================================================================
-- 2. INDEX
-- ============================================================================

-- send-push looks tokens up by owner.
CREATE INDEX IF NOT EXISTS device_push_tokens_user_idx
  ON public.device_push_tokens (user_id);

-- ============================================================================
-- 3. ROW-LEVEL SECURITY  (locked down exactly like printers/feedback)
-- ============================================================================

ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;

-- No policy on purpose: with RLS enabled and no policy, anon/authenticated can
-- do nothing here. The service role used by the Edge Functions bypasses RLS.
-- Belt-and-braces REVOKE in case a future default-privilege grant leaks in.
REVOKE ALL ON public.device_push_tokens FROM anon, authenticated;

COMMIT;
