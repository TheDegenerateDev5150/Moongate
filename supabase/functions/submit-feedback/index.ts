// POST /functions/v1/submit-feedback
//
// Backs the "Report a problem" item in the app drawer. Verifies the caller's
// Supabase JWT (anonymous is fine), validates the payload, and inserts one
// row into public.feedback via the service role - clients have no direct
// access to that table (see migration 20260609120000_feedback).
//
// The destination is the feedback table ONLY; nothing is sent anywhere else.
// A future version could forward to GitHub / email from here without any app
// change - that's the reason for the indirection instead of a direct insert.
//
// Caller MUST present a Supabase JWT (anonymous or otherwise) in the
// Authorization header.
//
// Request body:
//   {
//     "comment":      "<required, 1-5000 chars>",
//     "contact":      "<optional, how to reach the reporter>",
//     "printer_name": "<optional, which printer the report is about>",
//     "app_version":  "<optional, e.g. 0.6.2 (build 55)>",
//     "platform":     "<optional, e.g. Android 14 (API 34) - samsung SM-S911B>",
//     "diagnostics":  { ... }   // optional JSON object (printer list, counts…)
//   }
//
// Response 200: { "ok": true }
//
// Errors:
//   400 - malformed body / empty comment
//   401 - no/invalid JWT
//   500 - internal

import { handleCorsPreflight } from "../_shared/cors.ts";
import {
  jsonResponse, badRequest, unauthorized, methodNotAllowed, internalError,
} from "../_shared/responses.ts";
import { adminClient, getUserFromRequest } from "../_shared/supabaseClients.ts";

const MAX_COMMENT          = 5000;
const MAX_CONTACT          = 200;
const MAX_NAME             = 64;
const MAX_VERSION          = 64;
const MAX_PLATFORM         = 200;
const MAX_DIAGNOSTICS_BYTES = 20_000;

// Trim, drop empties, and cap length. Returns null for anything not a
// non-empty string so optional columns stay NULL rather than "".
function clampStr(v: unknown, max: number): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim();
  return t.length === 0 ? null : t.slice(0, max);
}

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

  const comment = clampStr(body.comment, MAX_COMMENT);
  if (!comment) return badRequest("comment required");

  // diagnostics: accept a plain object only, and cap its serialized size so a
  // client can't stuff the table with megabytes of JSON.
  let diagnostics: Record<string, unknown> = {};
  if (
    body.diagnostics && typeof body.diagnostics === "object" &&
    !Array.isArray(body.diagnostics)
  ) {
    try {
      if (JSON.stringify(body.diagnostics).length <= MAX_DIAGNOSTICS_BYTES) {
        diagnostics = body.diagnostics as Record<string, unknown>;
      }
    } catch {
      // non-serializable → drop it, keep the comment
    }
  }

  const db = adminClient();
  const { error } = await db.from("feedback").insert({
    user_id:      user.id,
    comment,
    contact:      clampStr(body.contact, MAX_CONTACT),
    printer_name: clampStr(body.printer_name, MAX_NAME),
    app_version:  clampStr(body.app_version, MAX_VERSION),
    platform:     clampStr(body.platform, MAX_PLATFORM),
    diagnostics,
  });

  if (error) {
    console.error("feedback insert error", error);
    return internalError();
  }

  return jsonResponse({ ok: true });
});
