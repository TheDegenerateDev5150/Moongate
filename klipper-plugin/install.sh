#!/usr/bin/env bash
# Moongate plugin installer for Moonraker on Raspberry Pi
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOONRAKER_HOME="${MOONRAKER_HOME:-$HOME/moonraker}"
EXTRAS_DIR="$MOONRAKER_HOME/moonraker/components"
PRINTER_DATA="${PRINTER_DATA:-$HOME/printer_data}"
MOONRAKER_CONF="$PRINTER_DATA/config/moonraker.conf"
PRINTER_CFG="$PRINTER_DATA/config/printer.cfg"
WG_DIR="/etc/wireguard"
WG_IFACE="wg0"
WG_PORT=51820
VPN_SUBNET="10.13.13"          # phone peers get 10.13.13.2, .3, …
SERVER_VPN_IP="10.13.13.1"

echo "==> Moongate plugin installer"
echo "    Moonraker home : $MOONRAKER_HOME"
echo "    Extras dir     : $EXTRAS_DIR"
echo "    moonraker.conf : $MOONRAKER_CONF"

# ── 1. Copy plugin ────────────────────────────────────────────────────────────
if [ ! -d "$EXTRAS_DIR" ]; then
    echo "ERROR: Moonraker components dir not found at $EXTRAS_DIR"
    echo "       Set MOONRAKER_HOME if Moonraker is installed elsewhere."
    exit 1
fi

echo "==> Copying plugin to $EXTRAS_DIR/moongate/"
cp -r "$SCRIPT_DIR/moongate" "$EXTRAS_DIR/"
echo "    Done."

# ── 2. Install WireGuard ──────────────────────────────────────────────────────
echo "==> Installing WireGuard..."
sudo apt-get update -qq
sudo apt-get install -y wireguard iptables

# ── 3. Generate server WireGuard keys (only if not already present) ───────────
if [ ! -f "$WG_DIR/server_private.key" ]; then
    echo "==> Generating WireGuard server keys..."
    sudo mkdir -p "$WG_DIR"
    sudo chmod 700 "$WG_DIR"
    wg genkey | sudo tee "$WG_DIR/server_private.key" | \
        wg pubkey | sudo tee "$WG_DIR/server_public.key"
    sudo chmod 600 "$WG_DIR/server_private.key"
    echo "    Keys generated."
else
    echo "==> WireGuard server keys already present — skipping key generation."
fi

SERVER_PRIVATE_KEY=$(sudo cat "$WG_DIR/server_private.key")
SERVER_PUBLIC_KEY=$(sudo cat "$WG_DIR/server_public.key")

# Detect the default outbound network interface
DEFAULT_IFACE=$(ip route | awk '/^default/ {print $5; exit}')

# ── 4. Create wg0.conf (only if missing) ─────────────────────────────────────
if [ ! -f "$WG_DIR/$WG_IFACE.conf" ]; then
    echo "==> Creating $WG_DIR/$WG_IFACE.conf..."
    sudo bash -c "cat > $WG_DIR/$WG_IFACE.conf" <<EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address    = $SERVER_VPN_IP/24
ListenPort = $WG_PORT

# NAT so phones can reach Moonraker via the VPN
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; \\
           iptables -t nat -A POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; \\
           iptables -t nat -D POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE

# Peers are appended here by the Moongate plugin at pairing time
EOF
    sudo chmod 600 "$WG_DIR/$WG_IFACE.conf"
    echo "    Done."
else
    echo "==> $WG_DIR/$WG_IFACE.conf already exists — skipping."
fi

# ── 5. Enable IP forwarding ───────────────────────────────────────────────────
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "==> Enabling IP forwarding..."
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
fi

# ── 6. Start + enable WireGuard ──────────────────────────────────────────────
echo "==> Starting WireGuard ($WG_IFACE)..."
sudo systemctl enable wg-quick@$WG_IFACE
sudo wg-quick up $WG_IFACE 2>/dev/null || sudo systemctl restart wg-quick@$WG_IFACE
echo "    WireGuard running on port $WG_PORT."

# ── 7. Save public key for plugin to read ────────────────────────────────────
sudo cp "$WG_DIR/server_public.key" "$WG_DIR/server_public.key"

# ── 8. moonraker.conf ────────────────────────────────────────────────────────
if [ -f "$MOONRAKER_CONF" ]; then
    if grep -q "\[moongate\]" "$MOONRAKER_CONF"; then
        echo "==> [moongate] already in moonraker.conf — skipping."
    else
        echo "==> Adding [moongate] to moonraker.conf"
        cat >> "$MOONRAKER_CONF" <<EOF

[moongate]
# Moongate secure pairing + WireGuard VPN plugin
# wireguard_endpoint: the IP:port phones will connect to externally.
# Set to your router's public IP or DDNS hostname:51820.
# Leave blank to use local LAN IP (good for home-network-only use).
# wireguard_endpoint =
EOF
        echo "    Done."
    fi
else
    echo "WARN: moonraker.conf not found at $MOONRAKER_CONF"
fi

# ── 9. MOONGATE_PAIR macro ───────────────────────────────────────────────────
if [ -f "$PRINTER_CFG" ]; then
    if grep -q "MOONGATE_PAIR" "$PRINTER_CFG"; then
        echo "==> MOONGATE_PAIR macro already in printer.cfg — skipping."
    else
        echo "==> Adding MOONGATE_PAIR macro to printer.cfg"
        cat >> "$PRINTER_CFG" <<'EOF'

[gcode_macro MOONGATE_PAIR]
description: Generate a Moongate pairing code
gcode:
    {action_call_remote_method("moongate_generate_pair_code")}
EOF
        echo "    Done."
    fi
else
    echo "WARN: printer.cfg not found at $PRINTER_CFG"
fi

# ── 10. Restart Moonraker ────────────────────────────────────────────────────
echo "==> Restarting Moonraker..."
if systemctl is-active --quiet moonraker; then
    sudo systemctl restart moonraker
    echo "    Moonraker restarted."
else
    echo "    Moonraker not active — start it manually."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Moongate installed successfully!                        ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  WireGuard server public key:                            ║"
echo "║  $SERVER_PUBLIC_KEY"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  For remote access, forward UDP port $WG_PORT on your   ║"
echo "║  router to this Pi ($LOCAL_IP) then set               ║"
echo "║  wireguard_endpoint in moonraker.conf.                   ║"
echo "║                                                          ║"
echo "║  Run  MOONGATE_PAIR  in Klipper console to pair a phone. ║"
echo "╚══════════════════════════════════════════════════════════╝"
