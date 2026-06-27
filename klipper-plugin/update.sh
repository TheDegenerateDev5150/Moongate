#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Moongate - post-update hook
#
# Called automatically by Moonraker's update manager after every git pull.
# Ensures the plugin symlink is in place and refreshes the QR pair page.
# Does NOT re-install cloudflared or the systemd service - those only run
# once during the initial install.sh.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[moongate]${NC} $*"; }
ok()   { echo -e "${GREEN}[moongate]${NC} $*"; }
warn() { echo -e "${YELLOW}[moongate]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOONGATE_DIR="$(dirname "$SCRIPT_DIR")"          # repo root  (~/moongate)
PLUGIN_SRC="$SCRIPT_DIR/moongate_standalone.py"

MOONRAKER_DIR="${MOONRAKER_DIR:-$HOME/moonraker}"
COMPONENTS_DIR="$MOONRAKER_DIR/moonraker/components"

# ── 1. Re-create symlink (in case it was removed) ────────────────────────────
if [[ -d "$COMPONENTS_DIR" ]]; then
    ln -sf "$PLUGIN_SRC" "$COMPONENTS_DIR/moongate.py"
    ok "Plugin symlink updated → $COMPONENTS_DIR/moongate.py"
else
    warn "Moonraker components dir not found at $COMPONENTS_DIR"
    warn "Set MOONRAKER_DIR= if Moonraker is installed elsewhere."
fi

# ── 2. Refresh QR pair page in common web-root locations ─────────────────────
HTML_SRC="$SCRIPT_DIR/moongate-pair.html"
DEPLOYED=0
for webroot in "$HOME/mainsail" "$HOME/printer_data/www" "$HOME/fluidd"; do
    if [[ -d "$webroot" ]]; then
        cp "$HTML_SRC" "$webroot/moongate-pair.html"
        ok "Pair page updated → $webroot/moongate-pair.html"
        DEPLOYED=1
    fi
done
[[ $DEPLOYED -eq 0 ]] && warn "No web-root found - pair page not deployed"

ok "Update complete."
