// Apple Push Notification service (APNs) sender, provider-token (JWT) auth.
//
// This is the "final hop" to an iPhone: every background alert to a closed app
// must go through Apple. We talk to APNs directly over HTTP/2 with a JWT signed
// by the team's APNs auth key (.p8). No Firebase, no third party.
//
// All credentials come from Supabase function secrets (set with
// `supabase secrets set ...`), never committed and never on the Pi:
//   MOONGATE_APNS_KEY_P8    the .p8 key contents (PEM, "-----BEGIN PRIVATE KEY----- ...")
//   MOONGATE_APNS_KEY_ID    the 10-char Key ID for that .p8
//   MOONGATE_APNS_TEAM_ID   the 10-char Apple Team ID
//   MOONGATE_APNS_BUNDLE_ID the app bundle id, used as apns-topic (com.moongate.app.moongate)
//   MOONGATE_APNS_HOST      optional; which APNs host to TRY FIRST. Defaults to
//                           the production host. A device token belongs to one
//                           environment (sandbox for dev/local builds,
//                           production for TestFlight + App Store) and the two
//                           are indistinguishable server-side, so sendApns falls
//                           back to the other host on BadDeviceToken — meaning
//                           one deploy serves dev and shipped builds at once and
//                           this secret never has to be flipped.
//
// NOTE: untestable end to end until the $99 Apple Developer account exists
// (the .p8 key is issued there). The structure follows Apple's documented
// provider API; we verify against a real device once the account is active.

import { base64ToBytes } from "../_shared/cryptoUtils.ts";

const PROD_HOST = "api.push.apple.com";
const SANDBOX_HOST = "api.sandbox.push.apple.com";

// APNs JWTs are valid up to 60 min and Apple rejects regenerating them too
// often, so we sign once and reuse for ~50 min.
const TOKEN_TTL_MS = 50 * 60 * 1000;

interface CachedToken {
  jwt: string;
  mintedAt: number;
}
let cached: CachedToken | null = null;

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing secret ${name}`);
  return v;
}

function base64UrlFromBytes(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlFromString(s: string): string {
  return base64UrlFromBytes(new TextEncoder().encode(s));
}

// Pull the base64 DER out of a PEM ".p8" and import it as an ECDSA P-256
// private key for signing.
async function importP8(pem: string): Promise<CryptoKey> {
  const der = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  return await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(der),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

// Mint (or reuse) the APNs provider JWT: header {alg:ES256, kid}, payload
// {iss:teamId, iat}. Signature is raw r||s, which is exactly ES256.
async function providerToken(): Promise<string> {
  const now = Date.now();
  if (cached && now - cached.mintedAt < TOKEN_TTL_MS) return cached.jwt;

  const keyId = env("MOONGATE_APNS_KEY_ID");
  const teamId = env("MOONGATE_APNS_TEAM_ID");
  const key = await importP8(env("MOONGATE_APNS_KEY_P8"));

  const header = base64UrlFromString(JSON.stringify({ alg: "ES256", kid: keyId }));
  const payload = base64UrlFromString(
    JSON.stringify({ iss: teamId, iat: Math.floor(now / 1000) }),
  );
  const signingInput = `${header}.${payload}`;

  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );

  const jwt = `${signingInput}.${base64UrlFromBytes(sig)}`;
  cached = { jwt, mintedAt: now };
  return jwt;
}

export interface ApnsResult {
  ok: boolean;
  // true when APNs says this token is permanently dead (410 Unregistered, or
  // 400 BadDeviceToken) so the caller can prune it.
  unregistered: boolean;
  status: number;
  reason?: string;
}

export interface ApnsAlert {
  title: string;
  body: string;
}

// One POST of one alert to one APNs host. Returns the raw status and APNs
// reason string (empty on success or a body-less response).
async function postToHost(
  host: string,
  deviceToken: string,
  topic: string,
  jwt: string,
  alert: ApnsAlert,
): Promise<{ status: number; reason: string }> {
  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({
      aps: { alert: { title: alert.title, body: alert.body }, sound: "default" },
    }),
  });

  if (res.status === 200) {
    await res.body?.cancel();
    return { status: 200, reason: "" };
  }

  let reason = "";
  try {
    reason = ((await res.json()) as { reason?: string }).reason ?? "";
  } catch {
    // no/!json body
  }
  return { status: res.status, reason };
}

// Deliver one alert to one device token, picking the APNs environment
// automatically. A token is only valid against the host matching the build it
// came from (sandbox for dev/local, production for TestFlight + App Store), and
// APNs answers 400 BadDeviceToken when a token hits the wrong host. Since the
// two environments can't be told apart server-side, we try the preferred host
// (MOONGATE_APNS_HOST, default production) and retry the other on BadDeviceToken
// before treating the token as dead. One deploy thus serves dev and shipped
// builds simultaneously, with no host secret to flip.
export async function sendApns(deviceToken: string, alert: ApnsAlert): Promise<ApnsResult> {
  const topic = env("MOONGATE_APNS_BUNDLE_ID");
  const jwt = await providerToken();

  const primary = Deno.env.get("MOONGATE_APNS_HOST") || PROD_HOST;
  const secondary = primary === PROD_HOST ? SANDBOX_HOST : PROD_HOST;

  const r = await postToHost(primary, deviceToken, topic, jwt, alert);
  if (r.status === 200) return { ok: true, unregistered: false, status: 200 };

  // Wrong environment — the token belongs to the other host. Retry there before
  // giving up; only a failure in BOTH environments means it is truly dead.
  if (r.reason === "BadDeviceToken") {
    const r2 = await postToHost(secondary, deviceToken, topic, jwt, alert);
    if (r2.status === 200) return { ok: true, unregistered: false, status: 200 };
    const unregistered = r2.status === 410 || r2.reason === "BadDeviceToken" ||
      r2.reason === "Unregistered";
    return { ok: false, unregistered, status: r2.status, reason: r2.reason };
  }

  // 410 Unregistered (app uninstalled) on the matching environment → prune.
  const unregistered = r.status === 410 || r.reason === "Unregistered";
  return { ok: false, unregistered, status: r.status, reason: r.reason };
}
