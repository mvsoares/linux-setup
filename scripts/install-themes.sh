#!/usr/bin/env bash
# =============================================================================
# GTK Themes · Icon Packs · Cursors — optional standalone installer
# Usage: sudo bash scripts/install-themes.sh
# =============================================================================
set -uo pipefail
[[ $EUID -ne 0 ]] && { echo "Run with sudo."; exit 1; }

LOG_FILE="/tmp/install-themes-$(date +%Y%m%d-%H%M%S).log"
REAL_USER="${SUDO_USER:-$USER}"

ok()   { echo "  ✔  $*"; }
info() { echo "  →  $*"; }
warn() { echo "  ⚠  $*"; }
skip() { echo "  ↷  $* (already installed)"; }

echo "┌─ GTK Themes · Icons · Cursors ─────────────────────────────────┐"
echo "│  Log: ${LOG_FILE}"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

# ── GTK Themes ───────────────────────────────────────────────────────────────

# Dracula GTK
DRACULA_DEST="/usr/share/themes/Dracula"
if [[ -d "$DRACULA_DEST" ]]; then
    skip "Dracula GTK theme"
else
    info "Installing Dracula GTK theme..."
    local_tmp=$(mktemp -d)
    if curl -fsSL "https://github.com/dracula/gtk/archive/master.zip" \
            -o "${local_tmp}/dracula-gtk.zip" >> "$LOG_FILE" 2>&1; then
        unzip -qo "${local_tmp}/dracula-gtk.zip" -d "${local_tmp}" >> "$LOG_FILE" 2>&1
        mv "${local_tmp}/gtk-master" "$DRACULA_DEST" 2>/dev/null \
            && ok "Dracula GTK theme" || warn "Dracula GTK theme move failed"
    else
        warn "Dracula GTK theme download failed"
    fi
    rm -rf "$local_tmp"
fi

# Catppuccin Mocha GTK
CATPPUCCIN_DEST="/usr/share/themes/catppuccin-mocha-mauve-standard+default"
if [[ -d "$CATPPUCCIN_DEST" ]] || ls /usr/share/themes/catppuccin-* &>/dev/null 2>&1; then
    skip "Catppuccin GTK theme"
else
    info "Installing Catppuccin Mocha GTK theme..."
    local_tmp=$(mktemp -d)
    CAPP_URL=$(curl -sSf "https://api.github.com/repos/catppuccin/gtk/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep -i "mocha" | grep -i "mauve" | head -1 | cut -d'"' -f4 || echo "")
    if [[ -n "$CAPP_URL" ]]; then
        curl -fsSL "$CAPP_URL" -o "${local_tmp}/catppuccin.zip" >> "$LOG_FILE" 2>&1
        unzip -qo "${local_tmp}/catppuccin.zip" -d /usr/share/themes/ >> "$LOG_FILE" 2>&1 \
            && ok "Catppuccin Mocha GTK theme" || warn "Catppuccin GTK unzip failed"
    else
        warn "Catppuccin GTK — release URL not found"
    fi
    rm -rf "$local_tmp"
fi

# Arc GTK Theme
if dpkg -l arc-theme &>/dev/null 2>&1 || [[ -d /usr/share/themes/Arc ]]; then
    skip "Arc GTK theme"
else
    info "Installing Arc GTK theme..."
    apt-get update -q >> "$LOG_FILE" 2>&1
    apt-get install -y -qq arc-theme >> "$LOG_FILE" 2>&1 \
        && ok "Arc GTK theme" || warn "Arc GTK install failed"
fi

# Materia GTK Theme
if dpkg -l materia-gtk-theme &>/dev/null 2>&1 || [[ -d /usr/share/themes/Materia ]]; then
    skip "Materia GTK theme"
else
    info "Installing Materia GTK theme..."
    apt-get update -q >> "$LOG_FILE" 2>&1
    apt-get install -y -qq materia-gtk-theme >> "$LOG_FILE" 2>&1 \
        && ok "Materia GTK theme" || warn "Materia GTK install failed"
fi

# Numix GTK Theme
if dpkg -l numix-gtk-theme &>/dev/null 2>&1 || [[ -d /usr/share/themes/Numix ]]; then
    skip "Numix GTK theme"
else
    info "Installing Numix GTK theme..."
    apt-get update -q >> "$LOG_FILE" 2>&1
    apt-get install -y -qq numix-gtk-theme >> "$LOG_FILE" 2>&1 \
        && ok "Numix GTK theme" || warn "Numix GTK install failed"
fi

# Greybird GTK Theme
if dpkg -l greybird-gtk-theme &>/dev/null 2>&1 || [[ -d /usr/share/themes/Greybird ]]; then
    skip "Greybird GTK theme"
else
    info "Installing Greybird GTK theme..."
    apt-get update -q >> "$LOG_FILE" 2>&1
    apt-get install -y -qq greybird-gtk-theme >> "$LOG_FILE" 2>&1 \
        && ok "Greybird GTK theme" || warn "Greybird GTK install failed"
fi

# Yaru GTK Theme (Ubuntu Default, good to have if missing)
if dpkg -l yaru-theme-gtk &>/dev/null 2>&1 || [[ -d /usr/share/themes/Yaru ]]; then
    skip "Yaru GTK theme"
else
    info "Installing Yaru GTK theme..."
    apt-get update -q >> "$LOG_FILE" 2>&1
    apt-get install -y -qq yaru-theme-gtk >> "$LOG_FILE" 2>&1 \
        && ok "Yaru GTK theme" || warn "Yaru GTK install failed"
fi

echo ""

# ── Icon themes ───────────────────────────────────────────────────────────────

# Papirus
if dpkg -l papirus-icon-theme &>/dev/null 2>&1 || [[ -d /usr/share/icons/Papirus ]]; then
    skip "Papirus icons"
else
    info "Installing Papirus icons..."
    add-apt-repository -y ppa:papirus/papirus >> "$LOG_FILE" 2>&1 || true
    apt-get update -q >> "$LOG_FILE" 2>&1
    apt-get install -y -qq papirus-icon-theme >> "$LOG_FILE" 2>&1 \
        && ok "Papirus icons" || warn "Papirus install failed"
fi

# Tela icons
if ls /usr/share/icons/Tela* &>/dev/null 2>&1; then
    skip "Tela icons"
else
    info "Installing Tela icon theme..."
    local_tmp=$(mktemp -d)
    if git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git \
            "${local_tmp}/tela" >> "$LOG_FILE" 2>&1; then
        bash "${local_tmp}/tela/install.sh" -c purple >> "$LOG_FILE" 2>&1 \
            && ok "Tela icon theme" || warn "Tela install had errors"
    else
        warn "Tela clone failed"
    fi
    rm -rf "$local_tmp"
fi

echo ""

# ── Cursor themes ─────────────────────────────────────────────────────────────

# Bibata Modern Classic
if [[ -d /usr/share/icons/Bibata-Modern-Classic ]]; then
    skip "Bibata Modern Classic cursor"
else
    info "Installing Bibata Modern cursor..."
    BIBATA_URL=$(curl -sSf "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "Bibata-Modern-Classic.tar.xz" | head -1 | cut -d'"' -f4 || echo "")
    if [[ -n "$BIBATA_URL" ]]; then
        local_tmp=$(mktemp -d)
        curl -fsSL "$BIBATA_URL" -o "${local_tmp}/bibata.tar.xz" >> "$LOG_FILE" 2>&1
        tar xf "${local_tmp}/bibata.tar.xz" -C /usr/share/icons/ >> "$LOG_FILE" 2>&1 \
            && ok "Bibata Modern Classic cursor" || warn "Bibata extract failed"
        rm -rf "$local_tmp"
    else
        warn "Bibata cursor — release not found"
    fi
fi

# Bibata Modern Ice
if [[ -d /usr/share/icons/Bibata-Modern-Ice ]]; then
    skip "Bibata Modern Ice cursor"
else
    BIBATA_ICE_URL=$(curl -sSf "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "Bibata-Modern-Ice.tar.xz" | head -1 | cut -d'"' -f4 || echo "")
    if [[ -n "$BIBATA_ICE_URL" ]]; then
        local_tmp=$(mktemp -d)
        curl -fsSL "$BIBATA_ICE_URL" -o "${local_tmp}/bibata-ice.tar.xz" >> "$LOG_FILE" 2>&1
        tar xf "${local_tmp}/bibata-ice.tar.xz" -C /usr/share/icons/ >> "$LOG_FILE" 2>&1 \
            && ok "Bibata Modern Ice cursor" || warn "Bibata Ice extract failed"
        rm -rf "$local_tmp"
    fi
fi

echo ""

# ── nwg-look ─────────────────────────────────────────────────────────────────
if command -v nwg-look &>/dev/null; then
    skip "nwg-look"
elif apt-cache show nwg-look &>/dev/null 2>&1; then
    apt-get install -y -qq nwg-look >> "$LOG_FILE" 2>&1 && ok "nwg-look"
else
    info "nwg-look — not in APT for this release (optional)"
fi

echo ""
echo "  ✔  Done. Log: ${LOG_FILE}"
