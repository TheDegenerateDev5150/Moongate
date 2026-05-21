"""
WireGuard peer manager for Moongate.

Manages /etc/wireguard/wg0.conf peer entries.
Each paired phone gets a unique VPN IP (10.13.13.2, .3, …).
"""
from __future__ import annotations

import json
import logging
import os
import re
import subprocess
from pathlib import Path

logger = logging.getLogger("moonraker.moongate.wg")

WG_IFACE      = "wg0"
WG_CONF       = f"/etc/wireguard/{WG_IFACE}.conf"
WG_PUB_KEY    = "/etc/wireguard/server_public.key"
VPN_SUBNET    = "10.13.13"
SERVER_VPN_IP = f"{VPN_SUBNET}.1"
PEERS_DB      = Path(os.path.expanduser("~/.config/moongate/peers.json"))


class WireGuardManager:
    def __init__(self) -> None:
        PEERS_DB.parent.mkdir(parents=True, exist_ok=True)
        self._peers: dict[str, dict] = self._load_peers()

    # ── Public API ────────────────────────────────────────────────────────────

    def server_public_key(self) -> str | None:
        """Return the server's WireGuard public key, or None if WireGuard isn't set up."""
        try:
            return Path(WG_PUB_KEY).read_text().strip()
        except FileNotFoundError:
            return None

    def endpoint(self, configured: str | None) -> str | None:
        """
        Return the WireGuard endpoint (IP:port) phones should connect to.
        Uses the configured value from moonraker.conf if set, otherwise
        falls back to the machine's primary LAN IP.
        """
        if configured:
            ep = configured.strip()
            if ep and ":" not in ep:
                ep = f"{ep}:51820"
            return ep or None
        # Auto-detect LAN IP
        try:
            result = subprocess.run(
                ["hostname", "-I"], capture_output=True, text=True
            )
            ip = result.stdout.strip().split()[0]
            return f"{ip}:51820"
        except Exception:
            return None

    def add_peer(self, device_id: str, phone_pubkey: str) -> dict | None:
        """
        Register a new phone peer.  Returns the WireGuard config the phone
        should use, or None if WireGuard is not configured on this server.
        """
        if self.server_public_key() is None:
            return None

        # Allocate the next available VPN IP
        used = {p["vpn_ip"] for p in self._peers.values()}
        vpn_ip = None
        for i in range(2, 255):
            candidate = f"{VPN_SUBNET}.{i}"
            if candidate not in used:
                vpn_ip = candidate
                break
        if vpn_ip is None:
            logger.error("No free VPN IPs")
            return None

        # Add peer to wg0.conf
        peer_block = (
            f"\n[Peer]\n"
            f"# device_id={device_id}\n"
            f"PublicKey  = {phone_pubkey}\n"
            f"AllowedIPs = {vpn_ip}/32\n"
        )
        try:
            with open(WG_CONF, "a") as f:
                f.write(peer_block)
            # Hot-add without dropping existing tunnels
            subprocess.run(
                ["sudo", "wg", "set", WG_IFACE,
                 "peer", phone_pubkey,
                 "allowed-ips", f"{vpn_ip}/32"],
                check=True
            )
        except Exception as exc:
            logger.warning("Could not add WireGuard peer: %s", exc)
            return None

        self._peers[device_id] = {"pubkey": phone_pubkey, "vpn_ip": vpn_ip}
        self._save_peers()
        logger.info("Added WireGuard peer %s → %s", device_id, vpn_ip)

        return {
            "vpn_ip":         vpn_ip,
            "server_vpn_ip":  SERVER_VPN_IP,
        }

    def remove_peer(self, device_id: str) -> None:
        peer = self._peers.pop(device_id, None)
        if peer is None:
            return
        try:
            subprocess.run(
                ["sudo", "wg", "set", WG_IFACE, "peer", peer["pubkey"], "remove"],
                check=True,
            )
            # Also remove from conf file
            self._rewrite_conf_without(peer["pubkey"])
        except Exception as exc:
            logger.warning("Could not remove WireGuard peer: %s", exc)
        self._save_peers()

    # ── Persistence ───────────────────────────────────────────────────────────

    def _load_peers(self) -> dict:
        try:
            return json.loads(PEERS_DB.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def _save_peers(self) -> None:
        PEERS_DB.write_text(json.dumps(self._peers, indent=2))

    def _rewrite_conf_without(self, pubkey: str) -> None:
        """Remove a peer block from wg0.conf by public key."""
        try:
            text = Path(WG_CONF).read_text()
            # Remove the [Peer] block that contains this pubkey
            pattern = rf"\n\[Peer\][^\[]*?PublicKey\s*=\s*{re.escape(pubkey)}[^\[]*"
            cleaned = re.sub(pattern, "", text, flags=re.DOTALL)
            Path(WG_CONF).write_text(cleaned)
        except Exception as exc:
            logger.warning("Could not rewrite wg conf: %s", exc)
