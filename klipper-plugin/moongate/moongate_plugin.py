"""
Moongate Moonraker component.

Registers:
  POST /moongate/pair    — generate a pairing code (called by MOONGATE_PAIR macro)
  POST /moongate/auth    — exchange a pairing code for a JWT + WireGuard config
  GET  /moongate/status  — check plugin status (authenticated)
  GET  /moongate/tokens  — list active tokens (authenticated)
  POST /moongate/revoke  — revoke a token (authenticated)
"""

from __future__ import annotations

import logging
from typing import Any

from .auth_manager import AuthManager
from .wireguard_manager import WireGuardManager

logger = logging.getLogger("moonraker.moongate")


def load_component(config: Any) -> "MoongatePlugin":
    return MoongatePlugin(config)


class MoongatePlugin:
    def __init__(self, config: Any) -> None:
        self.server = config.get_server()
        self.auth = AuthManager()
        self.wg   = WireGuardManager()

        # Optional: administrator-configured external endpoint for WireGuard
        self._wg_endpoint_override: str | None = config.get("wireguard_endpoint", None)

        app: Any = self.server.get_app()
        app.register_route("/moongate/pair",   ["POST"], self._handle_pair)
        app.register_route("/moongate/auth",   ["POST"], self._handle_auth)
        app.register_route("/moongate/status", ["GET"],  self._handle_status)
        app.register_route("/moongate/tokens", ["GET"],  self._handle_list_tokens)
        app.register_route("/moongate/revoke", ["POST"], self._handle_revoke)

        logger.info("Moongate plugin loaded (WireGuard: %s)",
                    "ready" if self.wg.server_public_key() else "not configured")

    # ── Route handlers ────────────────────────────────────────────────────────

    async def _handle_pair(self, request: Any) -> dict:
        """
        Called by the MOONGATE_PAIR Klipper macro.
        Returns the display code + QR payload.
        """
        display_code, qr_payload = self.auth.generate_pair_code()
        logger.info("Pair code requested: %s", display_code)
        return {
            "code":              display_code,
            "qr_payload":        qr_payload,
            "expires_in_seconds": 600,
        }

    async def _handle_auth(self, request: Any) -> dict:
        """
        Exchange a pairing code for a JWT.

        Request body (JSON):
          code         str   — pairing code
          device_name  str   — human-readable phone name
          ttl_days     int?  — optional token lifetime
          wg_pubkey    str?  — phone's WireGuard public key (base64)
                               if provided, returns a wg_config block the
                               phone can use to connect without Tailscale.
        """
        body = await request.json()
        raw_code:    str       = body.get("code", "")
        device_name: str       = body.get("device_name", "Unknown device")
        ttl_days               = body.get("ttl_days")
        phone_pubkey: str | None = body.get("wg_pubkey")

        if not raw_code:
            request.set_status(400)
            return {"error": "code is required"}

        result = self.auth.exchange_code(
            raw_code=raw_code,
            device_name=device_name,
            requested_ttl_days=ttl_days,
        )

        if result is None:
            request.set_status(401)
            return {"error": "invalid or expired code"}

        # result is (token, token_id)
        token, token_id = result if isinstance(result, tuple) else (result, None)

        response: dict = {"token": token}

        # ── WireGuard config (optional) ──────────────────────────────────────
        if phone_pubkey:
            server_pubkey = self.wg.server_public_key()
            endpoint      = self.wg.endpoint(self._wg_endpoint_override)

            if server_pubkey and endpoint:
                peer_info = self.wg.add_peer(
                    device_id=token_id or device_name,
                    phone_pubkey=phone_pubkey,
                )
                if peer_info:
                    # Build the WireGuard INI config that the phone will store
                    wg_config = (
                        "[Interface]\n"
                        f"Address    = {peer_info['vpn_ip']}/32\n"
                        "DNS        = 1.1.1.1\n"
                        "\n"
                        "[Peer]\n"
                        f"PublicKey           = {server_pubkey}\n"
                        f"Endpoint            = {endpoint}\n"
                        f"AllowedIPs          = {peer_info['server_vpn_ip']}/32\n"
                        "PersistentKeepalive = 25\n"
                    )
                    response["wg_config"]    = wg_config
                    response["wg_server_ip"] = peer_info["server_vpn_ip"]
                    response["wg_phone_ip"]  = peer_info["vpn_ip"]
                    logger.info(
                        "WireGuard peer created for '%s' → %s",
                        device_name, peer_info["vpn_ip"]
                    )
            else:
                logger.info(
                    "WireGuard not configured on server — skipping wg_config"
                )

        return response

    async def _handle_status(self, request: Any) -> dict:
        token_id = self._authenticate(request)
        if token_id is None:
            request.set_status(401)
            return {"error": "unauthorized"}
        return {
            "status":    "ok",
            "token_id":  token_id,
            "wg_active": self.wg.server_public_key() is not None,
        }

    async def _handle_list_tokens(self, request: Any) -> dict:
        token_id = self._authenticate(request)
        if token_id is None:
            request.set_status(401)
            return {"error": "unauthorized"}
        return {"tokens": self.auth.list_tokens()}

    async def _handle_revoke(self, request: Any) -> dict:
        token_id = self._authenticate(request)
        if token_id is None:
            request.set_status(401)
            return {"error": "unauthorized"}
        body = await request.json()
        target_id = body.get("token_id", token_id)
        # Also remove WireGuard peer
        self.wg.remove_peer(target_id)
        success = self.auth.revoke_token(target_id)
        return {"revoked": success}

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _authenticate(self, request: Any) -> str | None:
        auth_header: str = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return None
        jwt = auth_header[7:]
        return self.auth.validate_token(jwt)
