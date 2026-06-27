// POST /functions/v1/delete-account
//
// Deletes the caller's anonymous account and everything tied to it. Backs the
// in-app "Delete my data" action (App Store guideline 5.1.1(v): account
// creation must come with in-app deletion).
//
// Verifies the caller's Supabase JWT, then deletes that auth user via the
// service role. Foreign keys do the rest:
//   • printers, device_push_tokens, enrollment_tokens, restore_grants → CASCADE
//     (removed)
//   • feedback.user_id → SET NULL (the report text survives, de-identified)
// So no row tied to the user's identity is left behind.
//
// The user's printers (Pis) keep their local pairing state and will simply 404
// on their next heartbeat (their cloud row is gone), exactly like a reset - the
// user re-pairs if they want them back. The app signs back in as a fresh
// anonymous user afterwards.
//
// Caller MUST present a Supabase JWT (anonymous or otherwise).
//
// Response 200: { "ok": true }
//
// Errors:
//   401 - no/invalid JWT
//   405 - wrong method
//   500 - deletion failed

import { handleCorsPreflight } from "../_shared/cors.ts";
import {
  jsonResponse, unauthorized, methodNotAllowed, internalError,
} from "../_shared/responses.ts";
import { adminClient, getUserFromRequest } from "../_shared/supabaseClients.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return methodNotAllowed();

  const user = await getUserFromRequest(req);
  if (!user) return unauthorized();

  const db = adminClient();
  const { error } = await db.auth.admin.deleteUser(user.id);
  if (error) {
    console.error("deleteUser error", error);
    return internalError();
  }

  return jsonResponse({ ok: true });
});
