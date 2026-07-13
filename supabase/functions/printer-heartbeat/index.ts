// POST /functions/v1/printer-heartbeat
//
// Called by the Pi on boot and whenever cloudflared rotates the tunnel URL.
// Updates the encrypted tunnel URL on the printer record and bumps last_seen.
//
// Auth model: the Pi has no Supabase user. Authenticity is established by
// the Pi signing a canonical payload with its Ed25519 device key. The server
// looks up the printer by pi_public_key and verifies the signature against
// it. Replay is bounded by a 60-second window on the timestamp.
//
// Request body:
//   {
//     "pi_public_key": "<base64 Ed25519 pubkey>",
//     "tunnel_url":    "https://xxx.trycloudflare.com",
//     "timestamp":     <unix seconds>,
//     "signature":     "<base64 Ed25519 signature over canonical payload>"
//   }
//
// Canonical payload (UTF-8 bytes signed by Pi):
//   "moongate-heartbeat\n" + pi_public_key + "\n" + tunnel_url + "\n" + timestamp
//
// Response 204 on success.
//
// Errors:
//   400 - malformed body
//   401 - signature invalid OR timestamp out of window
//   404 - no printer with this pi_public_key (Pi should treat as unpaired)
//   410 - the owner deliberately released this printer (revoked_at tombstone,
//         kept 1 week) - plugin 0.6.15 stops heartbeating immediately on this
//   500 - internal

import { handleCorsPreflight } from "../_shared/cors.ts";
import {
  emptyResponse, badRequest, unauthorized, notFound, gone,
  methodNotAllowed, internalError,
} from "../_shared/responses.ts";
import { adminClient } from "../_shared/supabaseClients.ts";
import { encryptTunnelUrl, verifyEd25519, base64ToBytes } from "../_shared/cryptoUtils.ts";

const REPLAY_WINDOW_SECONDS = 60;
const MAX_TUNNEL_URL_LENGTH = 256;

// MOONGATE_MUTED_IPS: comma-separated caller IPs whose ROWLESS heartbeats get
// a 204 instead of 404/410. Surgical mute for an orphaned Pi spinning on an
// old (pre-0.6.10) plugin, which treats any non-success as "keep retrying
// fast" - it reads the 204 as success and settles to its steady cadence, no
// owner cooperation needed. Only the rowless path is muted: a muted Pi that
// re-pairs has a live row again and takes the normal 'ok' path, so a mute
// never blocks a comeback. (Designed 2026-06-24 during the Schlonky spinner
// hunt; built 2026-07-13 for the 87.122.x spinner.)
const MUTED_IPS = new Set(
  (Deno.env.get("MOONGATE_MUTED_IPS") ?? "")
    .split(",").map((s) => s.trim()).filter((s) => s.length > 0),
);

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return methodNotAllowed();

  let body: {
    pi_public_key?: unknown;
    tunnel_url?:    unknown;
    timestamp?:     unknown;
    signature?:     unknown;
  };
  try {
    body = await req.json();
  } catch {
    return badRequest("invalid_json");
  }

  const piPubKey  = body.pi_public_key;
  const tunnelUrl = body.tunnel_url;
  const timestamp = body.timestamp;
  const signature = body.signature;

  if (typeof piPubKey  !== "string") return badRequest("pi_public_key required");
  if (typeof tunnelUrl !== "string" || tunnelUrl.length === 0 || tunnelUrl.length > MAX_TUNNEL_URL_LENGTH) {
    return badRequest(`tunnel_url required (1-${MAX_TUNNEL_URL_LENGTH} chars)`);
  }
  if (typeof timestamp !== "number" || !Number.isFinite(timestamp)) {
    return badRequest("timestamp required (unix seconds)");
  }
  if (typeof signature !== "string") return badRequest("signature required");

  // Sanity-check pubkey length before doing crypto
  try {
    const pkBytes = base64ToBytes(piPubKey);
    if (pkBytes.length !== 32) return badRequest("pi_public_key must decode to 32 bytes");
  } catch {
    return badRequest("invalid pi_public_key base64");
  }

  // Replay window check (server time vs claimed timestamp)
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - timestamp) > REPLAY_WINDOW_SECONDS) {
    return unauthorized();
  }

  // Verify signature
  const canonical = `moongate-heartbeat\n${piPubKey}\n${tunnelUrl}\n${timestamp}`;
  const message   = new TextEncoder().encode(canonical);
  const ok        = await verifyEd25519(piPubKey, signature, message);
  if (!ok) return unauthorized();

  // Encrypt the new tunnel URL
  let ciphertextB64: string, nonceB64: string;
  try {
    const enc = await encryptTunnelUrl(tunnelUrl);
    ciphertextB64 = enc.ciphertextB64;
    nonceB64      = enc.nonceB64;
  } catch (e) {
    console.error("encryptTunnelUrl failed", e);
    return internalError();
  }

  // Update the printer row (lookup by pi_public_key)
  const db = adminClient();
  const { data, error } = await db.rpc("record_heartbeat_v2", {
    p_pi_public_key:        piPubKey,
    p_tunnel_url_enc_b64:   ciphertextB64,
    p_tunnel_url_nonce_b64: nonceB64,
  });

  if (error) {
    console.error("record_heartbeat_v2 rpc error", error);
    return internalError();
  }

  // record_heartbeat_v2 answers 'ok' (row updated), 'revoked' (owner released
  // this Pi; tombstone still present) or 'not_found' (no row at all).
  if (data === "ok") return emptyResponse(204);

  // Rowless outcome. A muted spinner gets a calming 204 before anything else.
  const callerIp = req.headers.get("cf-connecting-ip")
                ?? req.headers.get("x-real-ip") ?? "";
  if (MUTED_IPS.has(callerIp)) return emptyResponse(204);

  if (data === "revoked") return gone("printer_released");
  return notFound();
});
