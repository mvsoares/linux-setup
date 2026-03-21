#!/usr/bin/env bash
# =============================================================================
# backup.sh — Backup current workstation configuration
# Creates a timestamped archive of all user/system configs.
# Usage:  bash backup.sh [destination-dir]
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✔${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
skip() { echo -e "  ${YELLOW}⏭${RESET}  $* (not found)"; }

# ── Setup ─────────────────────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEST_BASE="${1:-${HOME}/workstation-backups}"
BACKUP_DIR="${DEST_BASE}/backup-${TIMESTAMP}"
ARCHIVE="${DEST_BASE}/workstation-backup-${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo ""
echo -e "${BOLD}${CYAN}  Workstation Config Backup${RESET}"
echo -e "  ${BOLD}─────────────────────────────────────${RESET}"
echo -e "  Destination : ${YELLOW}${BACKUP_DIR}${RESET}"
echo -e "  Date        : ${YELLOW}$(date)${RESET}"
echo ""

# ── Helper: copy if exists ────────────────────────────────────────────────────
backup_file() {
    local src="$1" dest_subdir="$2" label="${3:-$1}"
    if [[ -f "$src" ]]; then
        mkdir -p "${BACKUP_DIR}/${dest_subdir}"
        cp -a "$src" "${BACKUP_DIR}/${dest_subdir}/"
        ok "$label"
    else
        skip "$label"
    fi
}

backup_dir() {
    local src="$1" dest_subdir="$2" label="${3:-$1}"
    if [[ -d "$src" ]]; then
        mkdir -p "${BACKUP_DIR}/${dest_subdir}"
        cp -a "$src" "${BACKUP_DIR}/${dest_subdir}/"
        ok "$label"
    else
        skip "$label"
    fi
}

# ── 1. Shell configs ─────────────────────────────────────────────────────────
info "Backing up shell configs..."
backup_file "$HOME/.bashrc"                    "shell"  ".bashrc"
backup_file "$HOME/.bash_aliases"              "shell"  ".bash_aliases"
backup_file "$HOME/.bash_profile"              "shell"  ".bash_profile"
backup_file "$HOME/.profile"                   "shell"  ".profile"
backup_file "$HOME/.inputrc"                   "shell"  ".inputrc"

# ── 2. Git config ────────────────────────────────────────────────────────────
info "Backing up git config..."
backup_file "$HOME/.gitconfig"                 "git"    ".gitconfig"
backup_file "$HOME/.gitignore_global"          "git"    ".gitignore_global"

# ── 3. Starship ──────────────────────────────────────────────────────────────
info "Backing up Starship..."
backup_file "$HOME/.config/starship.toml"      "starship" "starship.toml"

# ── 4. synth-shell ───────────────────────────────────────────────────────────
info "Backing up synth-shell..."
backup_dir  "$HOME/.config/synth-shell"        "synth-shell" "synth-shell config"

# ── 5. WezTerm ───────────────────────────────────────────────────────────────
info "Backing up WezTerm..."
backup_file "$HOME/.config/wezterm/wezterm.lua" "wezterm" "wezterm.lua"

# ── 6. tmux ──────────────────────────────────────────────────────────────────
info "Backing up tmux..."
backup_file "$HOME/.tmux.conf"                 "tmux"   ".tmux.conf"

# ── 7. Cursor IDE ────────────────────────────────────────────────────────────
info "Backing up Cursor IDE..."
backup_file "$HOME/.config/Cursor/User/settings.json"     "cursor" "settings.json"
backup_file "$HOME/.config/Cursor/User/keybindings.json"  "cursor" "keybindings.json"
backup_dir  "$HOME/.config/Cursor/User/snippets"           "cursor" "snippets"

# ── 8. VSCode ────────────────────────────────────────────────────────────────
info "Backing up VSCode..."
backup_file "$HOME/.config/Code/User/settings.json"       "vscode" "settings.json"
backup_file "$HOME/.config/Code/User/keybindings.json"    "vscode" "keybindings.json"
backup_dir  "$HOME/.config/Code/User/snippets"             "vscode" "snippets"

# VSCode extension list
if command -v code &>/dev/null; then
    code --list-extensions > "${BACKUP_DIR}/vscode/extensions.txt" 2>/dev/null \
        && ok "VSCode extension list" || skip "VSCode extension list"
fi

# ── 9. VSCodium ──────────────────────────────────────────────────────────────
info "Backing up VSCodium..."
backup_file "$HOME/.config/VSCodium/User/settings.json"    "vscodium" "settings.json"
backup_file "$HOME/.config/VSCodium/User/keybindings.json" "vscodium" "keybindings.json"
backup_dir  "$HOME/.config/VSCodium/User/snippets"          "vscodium" "snippets"

if command -v codium &>/dev/null; then
    codium --list-extensions > "${BACKUP_DIR}/vscodium/extensions.txt" 2>/dev/null \
        && ok "VSCodium extension list" || skip "VSCodium extension list"
fi

# ── 10. Neovim ───────────────────────────────────────────────────────────────
info "Backing up Neovim..."
backup_dir "$HOME/.config/nvim" "nvim" "nvim config"

# ── 11. SSH config (NOT keys) ────────────────────────────────────────────────
info "Backing up SSH config (keys are NOT backed up)..."
backup_file "$HOME/.ssh/config"                "ssh" "ssh config"
backup_file "$HOME/.ssh/known_hosts"           "ssh" "known_hosts"

# ── 12. direnv ───────────────────────────────────────────────────────────────
info "Backing up direnv..."
backup_dir  "$HOME/.config/direnv"             "direnv" "direnv config"

# ── 13. .editorconfig ────────────────────────────────────────────────────────
backup_file "$HOME/.editorconfig"              "misc" ".editorconfig"

# ── 14. GNOME / dconf ────────────────────────────────────────────────────────
info "Backing up GNOME / dconf settings..."
mkdir -p "${BACKUP_DIR}/gnome"

if command -v dconf &>/dev/null; then
    dconf dump / > "${BACKUP_DIR}/gnome/dconf-full-dump.ini" 2>/dev/null \
        && ok "Full dconf dump" || warn "dconf dump failed"
fi

if command -v gsettings &>/dev/null; then
    # Targeted schema backups for easy reading
    for schema in \
        org.gnome.desktop.interface \
        org.gnome.desktop.wm.preferences \
        org.gnome.desktop.wm.keybindings \
        org.gnome.desktop.peripherals.touchpad \
        org.gnome.desktop.peripherals.mouse \
        org.gnome.desktop.peripherals.keyboard \
        org.gnome.desktop.session \
        org.gnome.desktop.privacy \
        org.gnome.desktop.sound \
        org.gnome.desktop.calendar \
        org.gnome.desktop.screensaver \
        org.gnome.desktop.search-providers \
        org.gnome.mutter \
        org.gnome.shell \
        org.gnome.shell.keybindings \
        org.gnome.nautilus.preferences \
        org.gnome.nautilus.list-view \
        org.gnome.settings-daemon.plugins.power \
        org.gnome.settings-daemon.plugins.color \
    ; do
        gsettings list-recursively "$schema" >> "${BACKUP_DIR}/gnome/gsettings-targeted.txt" 2>/dev/null || true
    done
    ok "Targeted gsettings backup"

    # Enabled extensions
    gsettings get org.gnome.shell enabled-extensions > "${BACKUP_DIR}/gnome/enabled-extensions.txt" 2>/dev/null || true
    ok "GNOME extension list"
fi
backup_file "$HOME/.config/dconf/user" "gnome" "dconf user db (binary)"

# ── 15. System profile.d scripts ─────────────────────────────────────────────
info "Backing up /etc/profile.d custom scripts..."
mkdir -p "${BACKUP_DIR}/system"
for f in /etc/profile.d/97-cloud-aliases.sh \
         /etc/profile.d/98-golang.sh \
         /etc/profile.d/99-improvements.sh \
         /etc/profile.d/99-workstation.sh; do
    [[ -f "$f" ]] && cp "$f" "${BACKUP_DIR}/system/" && ok "$(basename $f)" || true
done

# /etc/sysctl.d custom
for f in /etc/sysctl.d/99-desktop-tweaks.conf /etc/sysctl.d/99-workstation.conf; do
    [[ -f "$f" ]] && cp "$f" "${BACKUP_DIR}/system/" && ok "$(basename $f)" || true
done

# ── 16. Package lists ────────────────────────────────────────────────────────
info "Saving installed package lists..."
dpkg --get-selections | grep -v deinstall > "${BACKUP_DIR}/system/dpkg-packages.txt" 2>/dev/null && ok "dpkg package list"
snap list 2>/dev/null > "${BACKUP_DIR}/system/snap-packages.txt" && ok "snap package list" || true
flatpak list 2>/dev/null > "${BACKUP_DIR}/system/flatpak-packages.txt" && ok "flatpak package list" || true
pip3 list --user 2>/dev/null > "${BACKUP_DIR}/system/pip-packages.txt" && ok "pip package list" || true
command -v pipx &>/dev/null && pipx list --short > "${BACKUP_DIR}/system/pipx-packages.txt" 2>/dev/null && ok "pipx package list" || true

# ── 17. Installed CLI tool versions ──────────────────────────────────────────
info "Recording tool versions..."
{
    echo "# Tool versions — $(date)"
    echo ""
    for cmd in git node npm python3 pip3 go rustc cargo docker kubectl helm \
               aws gcloud az bat eza fd rg fzf zoxide delta lazygit lazydocker \
               dust procs tokei duf glow btm just hyperfine starship nvim tmux \
               codium code cursor pre-commit pipx k9s stern kubectx helm; do
        ver=$(command -v "$cmd" &>/dev/null && "$cmd" --version 2>/dev/null | head -1 || echo "not installed")
        printf "%-16s %s\n" "$cmd" "$ver"
    done
} > "${BACKUP_DIR}/system/tool-versions.txt"
ok "Tool versions"

# ── Create archive ───────────────────────────────────────────────────────────
info "Creating archive..."
tar czf "$ARCHIVE" -C "$DEST_BASE" "backup-${TIMESTAMP}" 2>/dev/null
ok "Archive: ${ARCHIVE}"

# Cleanup uncompressed dir (keep the archive)
rm -rf "$BACKUP_DIR"

# ── Summary ───────────────────────────────────────────────────────────────────
SIZE=$(du -sh "$ARCHIVE" | cut -f1)
echo ""
echo -e "${BOLD}${GREEN}  Backup complete!${RESET}"
echo -e "  ${BOLD}─────────────────────────────────────${RESET}"
echo -e "  Archive  : ${YELLOW}${ARCHIVE}${RESET}"
echo -e "  Size     : ${YELLOW}${SIZE}${RESET}"
echo ""
echo -e "  Restore with: ${CYAN}bash restore.sh ${ARCHIVE}${RESET}"
echo ""
