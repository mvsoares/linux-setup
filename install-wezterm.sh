#!/usr/bin/env bash
# =============================================================================
# install-wezterm.sh — Standalone WezTerm installer + config deployment
# =============================================================================
# Installs WezTerm (apt → Flatpak fallback) and deploys the project config:
#   • Monokai Remastered color scheme
#   • JetBrainsMono Nerd Font
#   • Google-colored tab bar with process name display
#   • GPU-accelerated (WebGpu) rendering
#   • Tmux-style pane/tab keybindings (Super+d, Super+D, etc.)
#
# Usage:
#   sudo bash install-wezterm.sh          — install + deploy config
#   sudo bash install-wezterm.sh --config — deploy config only (skip install)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors & logging ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✔${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
fail() { echo -e "  ${RED}✖${RESET}  $*"; exit 1; }

# ── Root / user detection ────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || fail "Run with sudo:  sudo bash $0"

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
[[ -z "$REAL_USER" ]] && REAL_USER="$(id -un 1000 2>/dev/null || echo "")"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6 2>/dev/null || echo "/root")

LOG_FILE="/tmp/wezterm-install-$(date +%Y%m%d-%H%M%S).log"

echo ""
echo -e "${BOLD}${CYAN}  WezTerm Installer${RESET}"
echo -e "  Log: ${LOG_FILE}"
echo ""

# ── Parse arguments ──────────────────────────────────────────────────────────
CONFIG_ONLY=false
[[ "${1:-}" == "--config" ]] && CONFIG_ONLY=true

# ── Install WezTerm ──────────────────────────────────────────────────────────
if [[ "$CONFIG_ONLY" == true ]]; then
    info "Config-only mode — skipping installation"
elif command -v wezterm &>/dev/null || flatpak list 2>/dev/null | grep -q org.wezfurlong.wezterm; then
    ok "WezTerm already installed ($(wezterm --version 2>/dev/null || echo 'flatpak'))"
else
    info "Installing WezTerm..."
    _wez_installed=false

    # Try apt repo first (native package)
    if curl -fsSL https://apt.fury.io/wez/gpg.key \
            | gpg --batch --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >> "$LOG_FILE" 2>&1 \
        && chmod 644 /usr/share/keyrings/wezterm-fury.gpg \
        && echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
            > /etc/apt/sources.list.d/wezterm.list \
        && apt-get update -q >> "$LOG_FILE" 2>&1 \
        && apt-get install -y -qq wezterm >> "$LOG_FILE" 2>&1; then
        ok "WezTerm installed (apt)"
        _wez_installed=true
    fi

    # Fallback: Flatpak
    if ! $_wez_installed && command -v flatpak &>/dev/null; then
        info "Trying WezTerm via Flatpak..."
        if flatpak install -y flathub org.wezfurlong.wezterm >> "$LOG_FILE" 2>&1; then
            cat > /usr/local/bin/wezterm << 'WEZWRAP'
#!/bin/sh
exec flatpak run org.wezfurlong.wezterm "$@"
WEZWRAP
            chmod +x /usr/local/bin/wezterm
            ok "WezTerm installed (Flatpak)"
            _wez_installed=true
        fi
    fi

    $_wez_installed || fail "WezTerm install failed — check ${LOG_FILE}"
fi

# ── Deploy config ────────────────────────────────────────────────────────────
WEZTERM_CFG="${USER_HOME}/.config/wezterm/wezterm.lua"
SRC_CFG="${SCRIPT_DIR}/lib/wezterm.lua"

if [[ ! -f "$SRC_CFG" ]]; then
    fail "Config source not found: ${SRC_CFG}"
fi

if [[ -f "$WEZTERM_CFG" ]]; then
    if diff -q "$SRC_CFG" "$WEZTERM_CFG" &>/dev/null; then
        ok "WezTerm config already up to date"
    else
        # Back up existing config before overwriting
        cp "$WEZTERM_CFG" "${WEZTERM_CFG}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$SRC_CFG" "$WEZTERM_CFG"
        chown "$REAL_USER:$REAL_USER" "$WEZTERM_CFG"
        ok "WezTerm config updated (backup saved as .bak.*)"
    fi
else
    info "Deploying WezTerm config..."
    install -d -o "$REAL_USER" -g "$REAL_USER" "$(dirname "$WEZTERM_CFG")"
    cp "$SRC_CFG" "$WEZTERM_CFG"
    chown "$REAL_USER:$REAL_USER" "$WEZTERM_CFG"
    ok "WezTerm config deployed"
fi

# ── Bash hook for process name in tab titles ─────────────────────────────────
BASHRC="${USER_HOME}/.bashrc"
if [[ -f "$BASHRC" ]] && grep -q '__wezterm_set_user_var' "$BASHRC"; then
    ok "WezTerm bash hook already present"
else
    cat >> "$BASHRC" << 'WEZTERM_HOOK'

# ── WezTerm tab title: show running command ──────────────────────────────────
__wezterm_set_user_var() {
    printf "\033]1337;SetUserVar=%s=%s\007" "$1" "$(printf '%s' "$2" | base64)"
}

__wezterm_preexec_fired=1
__wezterm_debug() {
    [[ "$__wezterm_preexec_fired" == "1" ]] && return
    [[ -n "${COMP_LINE:-}" ]] && return
    __wezterm_preexec_fired=1
    local cmd="${BASH_COMMAND%% *}"
    cmd="${cmd##*/}"
    __wezterm_set_user_var cmd "$cmd"
}
trap '__wezterm_debug' DEBUG

__wezterm_osc7() {
    printf "\033]7;file://%s%s\033\\" "${HOSTNAME}" "${PWD}"
}

PROMPT_COMMAND="${PROMPT_COMMAND:-}"'; __wezterm_osc7; __wezterm_set_user_var cmd ""; __wezterm_preexec_fired=0'
WEZTERM_HOOK
    chown "$REAL_USER:$REAL_USER" "$BASHRC"
    ok "WezTerm bash hook added (process name in tab titles)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Config highlights:${RESET}"
echo -e "    Color scheme   Monokai Remastered"
echo -e "    Font           JetBrainsMono Nerd Font 14pt"
echo -e "    Tab bar        Bottom, Google-colored, shows process|dir"
echo -e "    Rendering      WebGpu accelerated"
echo -e "    Opacity        95%"
echo -e "    Keybindings    Super+d split, Super+w close, Super+t tab"
echo ""
echo -e "  ${GREEN}${BOLD}Done!${RESET} Restart WezTerm to apply changes."
