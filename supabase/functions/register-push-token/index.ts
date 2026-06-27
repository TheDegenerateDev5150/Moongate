// POST /functions/v1/register-push-token
//
// Stores (or refreshes) the calling device's push-notification token so the
// send-push function can later deliver "print finished / failed" alerts to it.
// Verifies the caller's Supabase JWT (anonymous is fine), validates the
// payload, and upserts one row into public.device_push_tokens via the service
// role - clients have no direct access to that table (see migration
// 20260626120000_device_push_tokens).
//
// Upsert key is the token itself: re-registering the same device updates its
// row in place (and re-points it at the current anon user, e.g. after a
// restore) instead of leaving duplicates. Dead tokens are pruned later by
// send-push when Apple/Google report them unregistered.
//
// Caller MUST present a Supabase JWT (anonymous or otherwise) in the
// Authorization header.
//
// Request body:
//   {
//     "token":    "<required, the APNs (iOS) or FCM (Android) token>",
//     "platform": "ios" | "android"   // required
//   }
//
// Response 200: { "ok": true }
//
// Errors:
//   400 - malformed body / missing token / bad platform
//   401 - no/invalid JWT
//   500 - internal

import { handleCorsPreflight } from "../_shared/cors.ts";
import {
  jsonResponse, badRequest, unauthorized, methodNotAllowed, internalError,
} from "../_shared/responses.ts";
import { adminClient, getUserFromRequest } from "../_shared/supabaseClients.ts";

const MAX_TOKEN = 4096;
const PLATFORMS = new Set(["ios", "android"]);

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return methodNotAllowed();

  const user = await getUserFromRequest(req);
  if (!user) return unauthorized();

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return badRequest("invalid_json");
  }

  const token = typeof body.token === "string" ? body.token.trim() : "";
  if (token.length === 0 || token.length > MAX_TOKEN) {
    return badRequest("token required");
  }

  const platform = typeof body.platform === "string" ? body.platform : "";
  if (!PLATFORMS.has(platform)) {
    return badRequest("platform must be ios or android");
  }

  // Upsert on the token: a device re-registering (or a token that moved to a
  // new anon identity after a restore) updates in place. created_at keeps its
  // insert default; updated_at is bumped every time.
  const db = adminClient();
  const { error } = await db
    .from("device_push_tokens")
    .upsert(
      { user_id: user.id, token, platform, updated_at: new Date().toISOString() },
      { onConflict: "token" },
    );

  if (error) {
    console.error("device_push_tokens upsert error", error);
    return internalError();
  }

  return jsonResponse({ ok: true });
});
