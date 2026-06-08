# Troubleshooting

The common failure modes and how to diagnose them, in roughly the order people hit them. v0.2.x-specific fixes that landed long ago are no longer listed here — see [CHANGELOG.md](CHANGELOG.md) for the bug-fix history.

## Tile shows "Connecting…" longer than ~10 seconds

The app gives every printer up to one full poll cycle (4 s) before falling back to the tunnel, then up to another 8 s for the tunnel attempt. If a tile stays on "Connecting…" longer than ~15 s on a fresh launch:

- Check Moonraker is running on the Pi:
  ```bash
  sudo systemctl status moonraker
  ```
- Check the Moongate plugin loaded:
  ```bash
  grep -i moongate ~/printer_data/logs/moonraker.log | tail -20
  ```
- Check the auth proxy is running (v0.4+):
  ```bash
  sudo systemctl status moongate-authproxy
  ```
- Check the tunnel service:
  ```bash
  sudo systemctl status moongate-tunnel
  ```

All four (`moonraker`, `klipper`, `moongate-authproxy`, `moongate-tunnel`) need to be `active (running)` for the tile to flip from "Connecting…" to a live status.

## Tile shows "Connected — Printer idle"

This is **not** an error — it's the v0.4 way of saying "the Pi is reachable, but Klipper isn't producing usable status right now". Common causes:

- The printer's power toggle inside Mainsail is off (Creality K3 and similar — Klipper isn't running until the printer-power switch is on).
- Klipper crashed or is in an error state. Check `~/printer_data/logs/klippy.log` for the cause.
- The Pi is rebooting and Klipper hasn't come back up yet.

If the printer should be ready and the tile still shows "Connected — Printer idle":
- Restart Klipper: `sudo systemctl restart klipper`
- Restart Moonraker: `sudo systemctl restart moonraker`

The tile will flip to live status within a couple of poll cycles after the underlying issue clears.

## Tile shows "Offline — Printer unreachable"

The app's reachability probe got no response from either the LAN URL or the tunnel URL. Either the Pi is fully unreachable (powered off, network cable out, WiFi router down) or every service on it is down. Verify with:

```bash
ping <pi-ip>
curl -s -o /dev/null -w "%{http_code}\n" http://<pi-ip>/
curl -s -o /dev/null -w "%{http_code}\n" https://<your-tunnel-url>/
```

- The first should respond.
- The second should return `200` (or `301`/`302`) if nginx is up.
- The third should return `401` if the auth proxy is running. ANY HTTP code (even 401, 502) proves the tunnel side is alive.

If none of the three respond, the Pi is fully offline. If only the third fails, restart `moongate-tunnel` and `moongate-authproxy`.

## Tile shows "Tunnel" badge when I'm on home WiFi

In v0.4.0 the app retries LAN on every poll, so this should self-correct within one cycle (~4 s). If it doesn't:

- Force-close the app and re-open. The LAN URL is rebuilt from the cached config + the current status reply.
- Verify the Pi's LAN IP hasn't changed (DHCP lease expired and got a new address):
  ```bash
  ip -4 addr show | grep -A1 'state UP'
  ```
- If the IP changed: remove the printer in the app and re-pair on the new IP. The LAN URL persists across launches but isn't auto-discovered after a DHCP change.

## Remote tunnel not connecting

- Check the systemd unit:
  ```bash
  sudo systemctl status moongate-tunnel
  ```
- View the captured stdout (this is where the tunnel URL appears):
  ```bash
  cat /run/moongate-tunnel.log
  ```
- The Cloudflare Quick Tunnel URL changes on **every** restart of `cloudflared`. The app fetches the latest URL automatically — you do not need to re-pair when this happens.

## Auth proxy returns 401 for me, not just attackers

If your own app is getting 401s from the tunnel side (status tile is stuck offline, but LAN works):

- Verify the access proxy is running and the plugin can sign valid tokens:
  ```bash
  sudo systemctl status moongate-authproxy
  journalctl -u moongate-authproxy -n 50
  ```
- Check `~/.config/moongate/owner.json` exists and references your user. If it's missing or refers to a stale pair, run `MOONGATE_RESET_OWNER` in the Klipper console and re-pair.
- A token mismatch can happen if the device signing key was regenerated (uninstall / re-install / manual `~/.config/moongate/` wipe). The app's cached token becomes invalid. Force-close and re-open the app — it'll refresh on next poll.

## Webcam not showing

- The app uses the snapshot path Moonraker reports for your webcam — typically `/webcam/?action=snapshot` for mjpg-streamer setups.
- Make sure your webcam is configured in Mainsail / Fluidd under Settings → Webcams, and the snapshot URL works in a browser on your LAN.
- If you don't have a webcam, the tile falls back to the **Mainsail or Fluidd logo** (whichever you run). That's the expected v0.4 behaviour — it's not an error.

## QR scan won't work / camera fails

- Grant camera permission when prompted, or via **Settings → Apps → Moongate → Permissions → Camera**.
- The QR scanner only works in **release** builds with the ProGuard rules in [`mobile/android/app/proguard-rules.pro`](mobile/android/app/proguard-rules.pro). Debug builds also work; R8 doesn't run in debug.
- If the camera opens but fails to read the code: type the **GATE code** instead. Tap **+** to open Add Printer; the two 4-digit boxes for the `GATE-XXXX-XXXX` code shown in the Klipper console are right below the Scan QR button (numpad keyboard).

## Pairing fails / "already paired" error

In **v0.4.2+** the recovery is one macro: `MOONGATE_RESET_OWNER` on the Pi (Klipper console) wipes the local owner record **and** releases the cloud-side association (the Pi signs the release request with its own device key — same key it already uses for heartbeats). Then `MOONGATE_PAIR` and pair again from any app install.

Before v0.4.2 the cloud row could be orphaned by a fresh app install (new anonymous identity), which would cause `already_paired` on re-pair. That's gone now — the Pi can clean up its own cloud row without the original app being reachable.

## All tiles offline after reinstalling the app (or a new phone)

**Symptom:** You reinstalled Moongate, or switched to a new phone, and every printer shows offline — even sitting on your home WiFi.

**Cause:** A fresh install creates a new anonymous app identity. Your printers are still associated with the *previous* identity in the cloud, so the new install owns nothing and every tile reads offline. Importing a config backup brings back the printer names and layout, but not the cloud association.

**Fix:** Re-pair each printer. On the Pi, run `MOONGATE_RESET_OWNER` in the Klipper console, then `MOONGATE_PAIR`, and scan the QR (or type the GATE code) in the app.

> **Save yourself a step:** run `MOONGATE_RESET_OWNER` *before* you uninstall the old app. Then a fresh install just needs `MOONGATE_PAIR` and a scan.

## Tunnel URL leakage — what's actually exposed in v0.4?

**Nothing.** This was a real concern in v0.2.x where the tunnel terminated at nginx serving Mainsail without auth. In v0.4 the tunnel terminates at the auth proxy, which returns flat 401s for every request without a valid short-lived token. The URL alone is useless. Share it with anyone — they get 401s.

See [SECURITY.md → "What the tunnel actually exposes (v0.4)"](SECURITY.md#what-the-tunnel-actually-exposes-v04) for the empirical 35-vector attack-matrix verification.

If you're still running v0.2.x: upgrade. The known browser-direct-to-Mainsail hole was the explicit driver for v0.4.0.

## Moonraker behind a reverse proxy (Traefik, Caddy, NPM) or in Docker

Moongate assumes the standard Klipper layout: it connects to your printer **directly over plain HTTP, by IP address, on your LAN** — by default port 80, where one web server serves the Mainsail/Fluidd page *and* proxies the Moonraker API. A homelab where Moonraker sits behind a hostname-routing reverse proxy (Traefik, Caddy, Nginx Proxy Manager) or runs in Docker breaks that assumption:

- Moongate talks to an **IP over plain HTTP** — no hostname, no HTTPS — so a proxy that terminates TLS on 443 and routes by hostname is never in a form Moongate can use.
- The LAN address Moongate advertises comes from the printer host's own "which interface reaches the internet" lookup. Inside a Docker bridge network that returns a container-internal address (e.g. `172.x.x.x`) your phone can't reach.

You don't have to route Moongate *through* your proxy — you just have to give it a plain-HTTP door straight to your Klipper web stack. Your existing `https://…` proxy hostname can stay exactly as it is; Moongate simply doesn't use it. (Remote access, when you're away from home, runs over Moongate's own tunnel and is independent of your proxy.)

### "Connection refused" right after adding the printer

Adding a printer is a cloud step, so the tile appears even with no local connectivity. The first status poll then tries `http://<ip>:<http_port>/server/moongate/status`, nothing is listening there, and you get connection refused.

**Easiest — set the address in the app:** when adding the printer, expand **Advanced — printer on a custom network?** and enter the address you use to open its web page in a browser (e.g. `192.168.1.50:7125`). Already added it? Open the printer, tap the ✏️ icon, and set **Printer address** there. This points the app straight at your printer and skips the auto-discovery a reverse-proxy / Docker setup breaks — no server changes needed. Use an address that serves the Mainsail/Fluidd **page**, since that same origin also proxies the API — that's what fixes "Bad Gateway" below, too.

**Server-side alternative** — makes the QR and auto-discovery advertise the right port for *every* device:

1. Expose your Klipper web server (the one serving Mainsail/Fluidd) on the LAN on a normal HTTP port — not only the proxy's `https://…` hostname. If it runs in Docker, publish that port to the **host's LAN**, not just the container network.
2. On the machine running Moonraker, edit (create if missing) `~/.config/moongate/config.json` and set that port:
   ```json
   { "http_port": 80 }
   ```
   Use whatever port that web server actually listens on — `80` is the default; set e.g. `"http_port": 8080` if that's what you exposed. (In Docker this file lives under the home of the user Moonraker runs as, *inside* the container.)
3. Restart Moonraker so the plugin reloads, then **re-pair** in the app — remove the printer and add it again so the new pairing carries the right port.
4. Pair while your phone is on the **same WiFi/LAN** as the printer; initial pairing is LAN-only by design.

If the address still looks wrong (the app lands on a `172.x` Docker address it can't reach), run the Moonraker container with **host networking** so it advertises your real LAN IP.

### Tile connects, but opening the printer shows "Bad Gateway" (502)

The dashboard tile only uses the Moonraker **API** (`/server/…`). Tapping into a printer opens the **full Mainsail/Fluidd web page** in a built-in browser, by loading `http://<ip>:<http_port>/`. A 502 there is emitted by *your* web server or proxy — the app reached that layer, but it couldn't get the page from its upstream.

The usual cause: `http_port` points at **Moonraker directly (port 7125)**, which serves the API but has no web page, or at a proxy whose web-UI backend is down. `http_port` must point at the origin that serves **both** the Mainsail/Fluidd page **and** proxies the Moonraker API — the same single URL a browser uses to open your printer's interface.

**Confirm it's server-side, not the app** — on a computer on the same network, open the exact URL the app uses, `http://<the-ip-and-http_port-you-set>/`, in a browser:

- Bad Gateway in the browser too → it's your server/proxy config, not Moongate. Whatever serves that port can't reach its upstream (the Mainsail/Fluidd files, or Moonraker).
- The interface loads fine in the browser but not in the app → [open an issue](https://github.com/PEEKYPAUL/Moongate/issues/new); that's unusual.

**Fix:** point Moongate at the origin that serves the Mainsail/Fluidd page *and* proxies `/server`, `/websocket`, `/printer` to Moonraker. Quickest is in the app — open the printer, tap ✏️, and set **Printer address** to the address you open the web page at. Server-side, set `http_port` to that same port and restart Moonraker. Then re-open the printer.

## Need to capture a fresh log

For mobile-side issues:

```bash
# Stream logs from the running app process
adb logcat --pid=$(adb shell pidof com.moongate.app.moongate)

# Or filter by tag — the app uses "MOONGATE" for its own dev.log() calls
adb logcat -s MOONGATE
```

For plugin-side issues:

```bash
# Live tail of Moonraker (the moongate plugin logs here)
journalctl -u moonraker -f

# or directly:
tail -f ~/printer_data/logs/moonraker.log
```

For auth-proxy issues (v0.4+):

```bash
journalctl -u moongate-authproxy -f
```

For tunnel issues:

```bash
journalctl -u moongate-tunnel -f
tail -f /run/moongate-tunnel.log
```

## Anything else

- Read [CHANGELOG.md](CHANGELOG.md) for the version history — many issues from earlier releases have known fixes
- Read [SECURITY.md](SECURITY.md) for auth / transport / threat-model questions
- Open a [GitHub issue](https://github.com/PEEKYPAUL/Moongate/issues/new) with the relevant logcat / journalctl output if none of the above match
