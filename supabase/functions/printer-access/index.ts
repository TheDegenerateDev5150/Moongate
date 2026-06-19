// POST /functions/v1/printer-access
//
// Called by the app immediately before sending a control command to the Pi.
// Returns the current tunnel URL (decrypted) and a fresh 10-minute access
// token signed with the server's Ed25519 key.
//
// Caller MUST present a Supabase JWT in the Authorization header.
// Ownership is enforced inside the RPC; non-owners get an indistinguishable
// 404 response.
//
// Request body:
//   { "printer_id": "<uuid>" }
//
// Response 200:
//   {
//     "tunnel_url":   "https://xxx.trycloudflare.com" | null,
//     "access_token": "<EdDSA JWT, ~10 min TTL>",
//     "expires_in":   600
//   }
//
// The access token is valid on the LAN OR the tunnel — the Pi verifies the
// same EdDSA signature on either path. So when the caller advertises
// `accept_no_tunnel: true` (v0.5.0+ apps that go LAN-first via mDNS), we
// mint and return the token even before the Pi has reported a tunnel URL,
// with `tunnel_url: null`. This lets a freshly-paired printer come up
// "Local" instantly instead of blocking on the cloud round-trip — the
// tunnel populates within seconds on the next heartbeat and the app
// surfaces it in the background. Older apps that omit the flag keep the
// pre-v0.5 contract (503 until the tunnel is known).
//
// Errors:
//   400 — malformed body
//   401 — no/invalid JWT
//   404 — printer doesn't exist OR not owned by caller (constant shape)
//   503 — printer exists but Pi has not sent a heartbeat yet AND the caller
//         did not set accept_no_tunnel; retry_after seconds

import { handleCorsPreflight } from "../_shared/cors.ts";
import {
  jsonResponse, badRequest, unauthorized, notFound,
  methodNotAllowed, internalError, serviceUnavailable,
} from "../_shared/responses.ts";
import { adminClient, getUserFromRequest } from "../_shared/supabaseClients.ts";
import { decryptTunnelUrl } from "../_shared/cryptoUtils.ts";
import { mintAccessToken } from "../_shared/accessToken.ts";

const RETRY_AFTER_SECONDS = 5;

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return methodNotAllowed();

  const user = await getUserFromRequest(req);
  if (!user) return unauthorized();

  let body: { printer_id?: unknown; accept_no_tunnel?: unknown };
  try {
    body = await req.json();
  } catch {
    return badRequest("invalid_json");
  }

  const printerId = body.printer_id;
  if (typeof printerId !== "string" || printerId.length === 0) {
    return badRequest("printer_id required");
  }

  // v0.5.0+ apps set this to opt into LAN-first: get the token even when the
  // tunnel URL isn't known yet (tunnel_url comes back null). Older apps omit
  // it and keep the 503-until-tunnel contract.
  const acceptNoTunnel = body.accept_no_tunnel === true;

  const db = adminClient();
  const { data, error } = await db.rpc("get_printer_access", {
    p_printer_id: printerId,
    p_user_id:    user.id,
  });

  if (error) {
    console.error("get_printer_access rpc error", error);
    return internalError();
  }

  const row = Array.isArray(data) ? data[0] : data;
  if (!row) return notFound();

  // Pi hasn't heartbeated yet — ciphertext+nonce will both be null.
  const hasTunnel = !!row.tunnel_url_enc_b64 && !!row.tunnel_url_nonce_b64;
  if (!hasTunnel && !acceptNoTunnel) {
    // Legacy contract for pre-v0.5 apps: make them wait for the tunnel.
    return serviceUnavailable(RETRY_AFTER_SECONDS);
  }

  let tunnelUrl: string | null = null;
  if (hasTunnel) {
    try {
      tunnelUrl = await decryptTunnelUrl(row.tunnel_url_enc_b64, row.tunnel_url_nonce_b64);
    } catch (e) {
      console.error("decrypt failed", e);
      return internalError();
    }
  }

  // Always mint the token — it authenticates on LAN or tunnel alike. A null
  // tunnel_url just means "remote not ready yet"; the LAN-first app uses the
  // token against the mDNS-discovered local URL in the meantime.
  const { token, expiresIn } = await mintAccessToken({
    userId:    user.id,
    printerId: row.printer_id,
  });

  return jsonResponse({
    tunnel_url:   tunnelUrl,
    access_token: token,
    expires_in:   expiresIn,
  });
});
