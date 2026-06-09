// POST /functions/v1/read-feedback
//
// Admin/debug-only reader for the feedback table. Returns recent rows ONLY
// when called with the correct `x-moongate-debug` secret (matched against the
// MOONGATE_DEBUG_KEY function env var). Everyone else — even with a valid anon
// JWT — gets 404, so the feedback table stays locked to clients (no direct
// access; this is the one server-side read path besides the dashboard).
//
// Rows are read via the service role (RLS bypassed). Rotate/disable by
// changing or clearing MOONGATE_DEBUG_KEY (`supabase secrets set/unset`).
//
// Request body (optional): { "limit": <1-200, default 20> }
// Response 200: { "count": N, "rows": [ {feedback row}, ... ] }
// Errors: 404 missing/wrong secret, 405 wrong method, 500 internal

import { handleCorsPreflight } from "../_shared/cors.ts";
import {
  jsonResponse, notFound, methodNotAllowed, internalError,
} from "../_shared/responses.ts";
import { adminClient } from "../_shared/supabaseClients.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return methodNotAllowed();

  // The debug secret is the gate. A missing env var or any mismatch returns
  // the same 404 as an unknown route — non-enumerating, and fails closed.
  const expected = Deno.env.get("MOONGATE_DEBUG_KEY");
  const provided = req.headers.get("x-moongate-debug");
  if (!expected || !provided || provided !== expected) return notFound();

  let limit = 20;
  try {
    const body = await req.json();
    const n = (body as { limit?: unknown })?.limit;
    if (typeof n === "number" && n > 0 && n <= 200) limit = Math.floor(n);
  } catch { /* no/invalid body → default limit */ }

  const db = adminClient();
  const { data, error } = await db
    .from("feedback")
    .select(
      "id, created_at, app_version, platform, printer_name, contact, comment, diagnostics",
    )
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    console.error("read-feedback error", error);
    return internalError();
  }

  return jsonResponse({ count: data?.length ?? 0, rows: data ?? [] });
});
