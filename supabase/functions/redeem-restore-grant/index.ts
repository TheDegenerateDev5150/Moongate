// POST /functions/v1/redeem-restore-grant
//
// After a reinstall, the freshly-signed-in anonymous user redeems the restore
// code from their backup to reclaim their printers - the RPC re-assigns the
// grantor's live printer rows to the caller. Single-use; an expired/used/
// unknown code returns 404. See migration 20260609130000_restore_grants.
//
// Caller MUST present a Supabase JWT (the new anon identity) in the
// Authorization header.
//
// Request body:  { "restore_code": "<base64 secret from the backup file>" }
// Response 200:  { "printers": [ { "id": "<uuid>", "name": "<text>" } ], "count": N }
// Errors: 400 malformed/empty, 401 no/invalid JWT, 404 invalid/expired/used
//         code, 405 wrong method, 500 internal

import { handleCorsPreflight } from "../_shared/cors.ts";
import {
  jsonResponse, badRequest, unauthorized, notFound, methodNotAllowed,
  internalError,
} from "../_shared/responses.ts";
import { adminClient, getUserFromRequest } from "../_shared/supabaseClients.ts";
import { sha256, bytesToBase64 } from "../_shared/cryptoUtils.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return methodNotAllowed();

  const user = await getUserFromRequest(req);
  if (!user) return unauthorized();

  let body: { restore_code?: unknown };
  try {
    body = await req.json();
  } catch {
    return badRequest("invalid_json");
  }
  const code = body.restore_code;
  if (typeof code !== "string" || code.length === 0) {
    return badRequest("restore_code required");
  }

  const hashB64 = bytesToBase64(await sha256(new TextEncoder().encode(code)));

  const db = adminClient();
  const { data, error } = await db.rpc("redeem_restore_grant", {
    p_token_hash_b64: hashB64,
    p_new_user_id:    user.id,
  });

  if (error) {
    console.error("redeem_restore_grant rpc error", error);
    return internalError();
  }

  const rows = (Array.isArray(data) ? data : []) as Array<
    { printer_id: string | null; printer_name: string | null; status: string }
  >;

  // Invalid / expired / already-used grant comes back as a single not_found row.
  if (rows.length === 1 && rows[0].status === "not_found") {
    return notFound();
  }

  const printers = rows
    .filter((r) => r.status === "ok" && r.printer_id)
    .map((r) => ({ id: r.printer_id, name: r.printer_name }));

  return jsonResponse({ printers, count: printers.length });
});
