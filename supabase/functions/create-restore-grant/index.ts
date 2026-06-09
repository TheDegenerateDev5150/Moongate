// POST /functions/v1/create-restore-grant
//
// Mints a single-use, 90-day "restore code" for the caller so a future
// reinstall can reclaim THIS identity's printers without re-pairing. Only
// SHA-256(code) is stored server-side; the raw code is returned once and lives
// only in the user's backup file. See migration 20260609130000_restore_grants.
//
// Caller MUST present a Supabase JWT (the current owner) in the Authorization
// header.
//
// Response 200: { "restore_code": "<base64 secret>" }
// Errors: 401 no/invalid JWT, 405 wrong method, 500 internal

import { handleCorsPreflight } from "../_shared/cors.ts";
import {
  jsonResponse, unauthorized, methodNotAllowed, internalError,
} from "../_shared/responses.ts";
import { adminClient, getUserFromRequest } from "../_shared/supabaseClients.ts";
import { sha256, bytesToBase64 } from "../_shared/cryptoUtils.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return methodNotAllowed();

  const user = await getUserFromRequest(req);
  if (!user) return unauthorized();

  // 32-byte random secret; only its hash is persisted.
  const secretBytes = crypto.getRandomValues(new Uint8Array(32));
  const secret      = bytesToBase64(secretBytes);
  const hashB64     = bytesToBase64(await sha256(new TextEncoder().encode(secret)));

  const db = adminClient();
  const { error } = await db.rpc("create_restore_grant", {
    p_token_hash_b64: hashB64,
    p_user_id:        user.id,
  });

  if (error) {
    console.error("create_restore_grant rpc error", error);
    return internalError();
  }

  return jsonResponse({ restore_code: secret });
});
