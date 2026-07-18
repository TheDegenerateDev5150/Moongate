# 3rd-party printer support

Moongate's normal installer targets Raspberry-Pi-style hosts (MainsailOS,
FluiddPI: bash, systemd, sudo, pip, git). Plenty of interesting machines run a
real Moonraker without any of that - vendor printers with community firmware,
appliance-style embedded builds - and from **plugin 0.6.17** Moongate's
**Direct (LAN/VPN) mode** runs on them too, with zero extra Python
dependencies and no installer: **copy one file, add one config section,
restart Moonraker.**

Cloud mode (tunnel, notifications) is out of scope on these machines - they
rarely have the RAM or the packages for it. Direct mode covers home use out of
the box, and remote use through your own VPN (see
[Remote access](#remote-access-vpn) below).

## Supported machines

| Machine | Firmware | Status |
|---|---|---|
| Elegoo Centauri Carbon | [OpenCentauri COSMOS](https://github.com/OpenCentauri/cosmos) | 🧪 in validation with a community tester |

Running Moongate on a machine that isn't listed? The
[generic recipe](#the-generic-recipe) below works on anything with a real
Moonraker. Please [open an issue](https://github.com/PEEKYPAUL/Moongate/issues)
with your results either way - working reports are how machines get added to
this table.

## What the machine needs

- A genuine [Moonraker](https://github.com/Arksine/moonraker) (0.9+) you can
  drop a component file into - Moonraker forks with the components system
  stripped out won't work
- Python 3.9+ (Moonraker's own requirement; no extra packages needed)
- A writable directory for Moongate's state (a few KB)
- Moonraker's `[authorization] trusted_clients` covering your phone's network
  - vendor images usually ship this for all private ranges
- The app talks to the same host and port Moonraker serves on, so no extra
  ports, proxies, or firewall holes

## The generic recipe

1. Copy `klipper-plugin/moongate_standalone.py` from this repo into
   Moonraker's components directory as `moongate.py`.
2. Add to `moonraker.conf`:

   ```ini
   [moongate]
   lan_only: true
   data_path: /path/to/somewhere/writable
   ```

   `data_path` holds Moongate's state (defaults to `~/.config/moongate`,
   which embedded systems often can't write). A third option,
   `moonraker_port`, exists for the rare setup where Moonraker's port can't
   be auto-detected.
3. Restart Moonraker.
4. Confirm it loaded: `moonraker.log` shows
   `Moongate LAN-only mode: cloud loops disabled (no tunnel, no Supabase).`
5. In the app: **Add Printer → Direct (LAN/VPN)**, enter a name and the
   printer's address (e.g. `http://192.168.1.50`, add `:port` if Moonraker
   isn't on port 80 there). Give the printer a fixed address on your router -
   the app stores it.

## Elegoo Centauri Carbon (OpenCentauri COSMOS)

COSMOS ships a real Moonraker on port 80 with `trusted_clients` preconfigured
for all private networks, which is exactly what Direct mode expects. The OS is
BusyBox-based (no bash, git, pip, or systemd) - which is fine, nothing below
needs them. SSH in as root, then:

```sh
# 1. The plugin file. If wget lacks TLS on your build, scp it from a computer
#    instead:  scp moongate_standalone.py root@<printer-ip>:/usr/share/moonraker/moonraker/components/moongate.py
wget -O /usr/share/moonraker/moonraker/components/moongate.py \
  https://raw.githubusercontent.com/PEEKYPAUL/Moongate/master/klipper-plugin/moongate_standalone.py

# 2. State dir on the writable /etc overlay
mkdir -p /etc/moongate

# 3. Config - append to the WRITABLE conf (not the moonraker-readonly one)
printf '\n[moongate]\nlan_only: true\ndata_path: /etc/moongate\n' \
  >> /etc/klipper/config/moonraker.conf

# 4. Restart
/etc/init.d/moonraker restart
```

Then add the printer in the app as above (plain `http://<printer-ip>`, no
port suffix - COSMOS serves Moonraker on 80).

Known caveats on COSMOS:

- If step 1 fails with a read-only filesystem error, remount first
  (`mount -o remount,rw /`) and re-run it.
- A COSMOS firmware update replaces the Moonraker directory, taking
  `moongate.py` with it - re-run step 1 (and 4) after updating. Your config
  and state on `/etc` survive.
- COSMOS is beta firmware on a very RAM-limited board, and its authors warn
  against piling on plugins. LAN-only Moongate is about as light as they come
  (no tunnel, no timers, no outbound calls), but temper expectations
  accordingly.

## Remote access (VPN)

Direct mode away from home rides your own VPN, and the easy path is a
**subnet router** (Tailscale or WireGuard on any always-on box at home,
advertising your LAN). Your phone's traffic then arrives at the printer
looking like home-LAN traffic, which the stock `trusted_clients` ranges
already cover - no printer-side changes at all.

If instead you address the printer by a Tailscale IP directly, that traffic
comes from `100.64.0.0/10`, which stock configs do **not** trust - add that
range to `trusted_clients` in the writable moonraker.conf.

## What you give up vs a Pi install

- **No print notifications** - they're a cloud feature, and this is the
  cloud-free mode.
- **No update badge / one-tap update** - these machines have no Moonraker
  update_manager. Updating Moongate = re-copying the file.
- **No mDNS discovery** - the app uses the fixed address you gave it.
