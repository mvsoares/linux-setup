#!/usr/bin/env bash
# Deploy the WezTerm loader + repo defaults into a user's config dir.
#
# usage: wezterm-deploy.sh USER_HOME [OWNER[:GROUP]]
#
# Repo-owned (always replaced): wezterm.lua (loader), defaults.json.
# User-owned (never overwritten): settings.json, user.lua, tab_theme.lua.
# A pre-loader wezterm.lua (hand-written config) is backed up first.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${1:?usage: wezterm-deploy.sh USER_HOME [OWNER[:GROUP]]}"
OWNER="${2:-}"
CFG_DIR="${USER_HOME}/.config/wezterm"
LOADER_MARK="-- WezTerm loader"

install -d "$CFG_DIR" "$CFG_DIR/backups"

if [[ -f "$CFG_DIR/wezterm.lua" ]] && ! head -1 "$CFG_DIR/wezterm.lua" | grep -qF -- "$LOADER_MARK"; then
    backup="$CFG_DIR/backups/wezterm.lua.$(date +%Y%m%d-%H%M%S)_pre_loader.bak"
    cp -p "$CFG_DIR/wezterm.lua" "$backup"
    echo "backed up hand-written config to $backup"
fi

install -m 644 "$SRC_DIR/wezterm.lua" "$CFG_DIR/wezterm.lua"
install -m 644 "$SRC_DIR/wezterm-defaults.json" "$CFG_DIR/defaults.json"
[[ -f "$CFG_DIR/settings.json" ]] || echo '{}' > "$CFG_DIR/settings.json"

if [[ -n "$OWNER" ]]; then
    chown -R "$OWNER" "$CFG_DIR"
fi
echo "WezTerm loader + defaults deployed to $CFG_DIR"
