#!/usr/bin/env bash
# =============================================================================
# restore.sh — Restore workstation configuration from backup archive
# Usage:  bash restore.sh <backup-archive.tar.gz> [--dry-run] [--only section]
#
# Sections: shell git starship synth-shell wezterm tmux vscode
#           vscodium nvim ssh direnv misc gnome system extensions
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✔${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
fail() { echo -e "  ${RED}✖${RESET}  $*"; }
skip() { echo -e "  ${DIM}⏭  $* — skipped${RESET}"; }

DRY_RUN=false
ONLY_SECTION=""
ARCHIVE=""

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true ;;
        --only)     ONLY_SECTION="$2"; shift ;;
        --help|-h)
            echo "Usage: bash restore.sh <backup.tar.gz> [--dry-run] [--only section]"
            echo ""
            echo "Sections: shell git starship synth-shell wezterm tmux vscode"
            echo "          vscodium nvim ssh direnv misc gnome system extensions"
            echo ""
            echo "Options:"
            echo "  --dry-run     Show what would be restored without changing anything"
            echo "  --only sec    Restore only a specific section"
            exit 0
            ;;
        *)
            if [[ -f "$1" ]]; then
                ARCHIVE="$1"
            else
                fail "File not found: $1"; exit 1
            fi
            ;;
    esac
    shift
done

if [[ -z "$ARCHIVE" ]]; then
    fail "No archive specified. Usage: bash restore.sh <backup.tar.gz>"
    exit 1
fi

# ── Extract to temp dir ──────────────────────────────────────────────────────
WORK_DIR=$(mktemp -d)
trap "rm -rf '$WORK_DIR'" EXIT

info "Extracting ${ARCHIVE}..."
tar xzf "$ARCHIVE" -C "$WORK_DIR"

# Find the backup-* directory inside
BACKUP_DIR=$(ls -d "$WORK_DIR"/backup-* 2>/dev/null | head -1)
if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
    fail "Invalid archive — no backup-* directory found"
    exit 1
fi

echo ""
echo -e "${BOLD}${CYAN}  Workstation Config Restore${RESET}"
echo -e "  ${BOLD}─────────────────────────────────────${RESET}"
echo -e "  Archive  : ${YELLOW}${ARCHIVE}${RESET}"
echo -e "  Dry run  : ${YELLOW}${DRY_RUN}${RESET}"
if [[ -n "$ONLY_SECTION" ]]; then
    echo -e "  Section  : ${YELLOW}${ONLY_SECTION}${RESET}"
fi
echo ""

# ── Should we restore this section? ──────────────────────────────────────────
should_restore() {
    [[ -z "$ONLY_SECTION" ]] && return 0
    [[ "$ONLY_SECTION" == "$1" ]] && return 0
    return 1
}

# ── Safe restore: backup existing, then copy ─────────────────────────────────
RESTORE_LOG=()

restore_file() {
    local src="$1" dest="$2" label="${3:-$(basename $2)}"

    if [[ ! -f "$src" ]]; then
        return
    fi

    if $DRY_RUN; then
        echo -e "  ${CYAN}[dry]${RESET} Would restore: ${dest}"
        return
    fi

    mkdir -p "$(dirname "$dest")"

    # Create .pre-restore backup of existing file
    if [[ -f "$dest" ]]; then
        cp -a "$dest" "${dest}.pre-restore" 2>/dev/null || true
    fi

    cp -a "$src" "$dest"
    RESTORE_LOG+=("$label → $dest")
    ok "$label"
}

restore_dir() {
    local src="$1" dest="$2" label="${3:-$(basename $2)}"

    if [[ ! -d "$src" ]]; then
        return
    fi

    if $DRY_RUN; then
        echo -e "  ${CYAN}[dry]${RESET} Would restore dir: ${dest}"
        return
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ -d "$dest" ]]; then
        cp -a "$dest" "${dest}.pre-restore" 2>/dev/null || true
    fi

    cp -a "$src" "$dest"
    RESTORE_LOG+=("$label → $dest")
    ok "$label"
}

# ── 1. Shell ──────────────────────────────────────────────────────────────────
if should_restore "shell"; then
    info "Restoring shell configs..."
    restore_file "${BACKUP_DIR}/shell/.bashrc"        "$HOME/.bashrc"        ".bashrc"
    restore_file "${BACKUP_DIR}/shell/.bash_aliases"   "$HOME/.bash_aliases"   ".bash_aliases"
    restore_file "${BACKUP_DIR}/shell/.bash_profile"   "$HOME/.bash_profile"   ".bash_profile"
    restore_file "${BACKUP_DIR}/shell/.profile"        "$HOME/.profile"        ".profile"
    restore_file "${BACKUP_DIR}/shell/.inputrc"        "$HOME/.inputrc"        ".inputrc"
fi

# ── 2. Git ────────────────────────────────────────────────────────────────────
if should_restore "git"; then
    info "Restoring git config..."
    restore_file "${BACKUP_DIR}/git/.gitconfig"        "$HOME/.gitconfig"        ".gitconfig"
    restore_file "${BACKUP_DIR}/git/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"
fi

# ── 3. Starship ──────────────────────────────────────────────────────────────
if should_restore "starship"; then
    info "Restoring Starship config..."
    restore_file "${BACKUP_DIR}/starship/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
fi

# ── 4. synth-shell ───────────────────────────────────────────────────────────
if should_restore "synth-shell"; then
    info "Restoring synth-shell..."
    restore_dir "${BACKUP_DIR}/synth-shell/synth-shell" "$HOME/.config/synth-shell" "synth-shell"
fi

# ── 5. WezTerm ───────────────────────────────────────────────────────────────
if should_restore "wezterm"; then
    info "Restoring WezTerm..."
    restore_file "${BACKUP_DIR}/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua" "wezterm.lua"
fi

# ── 6. tmux ──────────────────────────────────────────────────────────────────
if should_restore "tmux"; then
    info "Restoring tmux..."
    restore_file "${BACKUP_DIR}/tmux/.tmux.conf" "$HOME/.tmux.conf" ".tmux.conf"
fi

# ── 8. VSCode ────────────────────────────────────────────────────────────────
if should_restore "vscode"; then
    info "Restoring VSCode..."
    restore_file "${BACKUP_DIR}/vscode/settings.json"    "$HOME/.config/Code/User/settings.json"    "VSCode settings.json"
    restore_file "${BACKUP_DIR}/vscode/keybindings.json" "$HOME/.config/Code/User/keybindings.json" "VSCode keybindings.json"
    restore_dir  "${BACKUP_DIR}/vscode/snippets"          "$HOME/.config/Code/User/snippets"          "VSCode snippets"
fi

# ── 9. VSCodium ──────────────────────────────────────────────────────────────
if should_restore "vscodium"; then
    info "Restoring VSCodium..."
    restore_file "${BACKUP_DIR}/vscodium/settings.json"    "$HOME/.config/VSCodium/User/settings.json"    "VSCodium settings.json"
    restore_file "${BACKUP_DIR}/vscodium/keybindings.json" "$HOME/.config/VSCodium/User/keybindings.json" "VSCodium keybindings.json"
    restore_dir  "${BACKUP_DIR}/vscodium/snippets"          "$HOME/.config/VSCodium/User/snippets"          "VSCodium snippets"
fi

# ── 10. Neovim ───────────────────────────────────────────────────────────────
if should_restore "nvim"; then
    info "Restoring Neovim..."
    restore_dir "${BACKUP_DIR}/nvim/nvim" "$HOME/.config/nvim" "nvim config"
fi

# ── 11. SSH ──────────────────────────────────────────────────────────────────
if should_restore "ssh"; then
    info "Restoring SSH config..."
    restore_file "${BACKUP_DIR}/ssh/ssh config"   "$HOME/.ssh/config"      "ssh config"
    restore_file "${BACKUP_DIR}/ssh/known_hosts"  "$HOME/.ssh/known_hosts" "known_hosts"
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
fi

# ── 12. direnv ───────────────────────────────────────────────────────────────
if should_restore "direnv"; then
    info "Restoring direnv..."
    restore_dir "${BACKUP_DIR}/direnv/direnv" "$HOME/.config/direnv" "direnv config"
fi

# ── 13. Misc ─────────────────────────────────────────────────────────────────
if should_restore "misc"; then
    info "Restoring misc..."
    restore_file "${BACKUP_DIR}/misc/.editorconfig" "$HOME/.editorconfig" ".editorconfig"
fi

# ── 14. GNOME / dconf ────────────────────────────────────────────────────────
if should_restore "gnome"; then
    DCONF_DUMP="${BACKUP_DIR}/gnome/dconf-full-dump.ini"
    if [[ -f "$DCONF_DUMP" ]] && command -v dconf &>/dev/null; then
        if $DRY_RUN; then
            echo -e "  ${CYAN}[dry]${RESET} Would load dconf dump ($(wc -l < "$DCONF_DUMP") lines)"
        else
            info "Restoring GNOME/dconf settings..."
            # Back up current dconf first
            dconf dump / > "$HOME/.dconf-backup-pre-restore-$(date +%Y%m%d%H%M%S).ini" 2>/dev/null || true
            ok "Current dconf backed up to ~/.dconf-backup-pre-restore-*.ini"
            dconf load / < "$DCONF_DUMP" 2>/dev/null \
                && ok "dconf settings restored" \
                || warn "dconf load had errors (partial restore likely)"
        fi
    else
        skip "dconf dump"
    fi
fi

# ── 15. Extensions (re-install) ──────────────────────────────────────────────
if should_restore "extensions"; then
    info "Restoring editor extensions..."

    # VSCode
    VSCODE_EXTS="${BACKUP_DIR}/vscode/extensions.txt"
    if [[ -f "$VSCODE_EXTS" ]] && command -v code &>/dev/null; then
        if $DRY_RUN; then
            echo -e "  ${CYAN}[dry]${RESET} Would install $(wc -l < "$VSCODE_EXTS") VSCode extensions"
        else
            while IFS= read -r ext; do
                [[ -z "$ext" ]] && continue
                code --install-extension "$ext" --force >> /dev/null 2>&1 && ok "VSCode: $ext" || true
            done < "$VSCODE_EXTS"
        fi
    fi

    # VSCodium
    CODIUM_EXTS="${BACKUP_DIR}/vscodium/extensions.txt"
    if [[ -f "$CODIUM_EXTS" ]] && command -v codium &>/dev/null; then
        if $DRY_RUN; then
            echo -e "  ${CYAN}[dry]${RESET} Would install $(wc -l < "$CODIUM_EXTS") VSCodium extensions"
        else
            while IFS= read -r ext; do
                [[ -z "$ext" ]] && continue
                codium --install-extension "$ext" --force >> /dev/null 2>&1 && ok "VSCodium: $ext" || true
            done < "$CODIUM_EXTS"
        fi
    fi
fi

# ── 16. System files (require sudo) ──────────────────────────────────────────
if should_restore "system"; then
    info "Restoring system files (may need sudo)..."
    SYS_DIR="${BACKUP_DIR}/system"

    if [[ -d "$SYS_DIR" ]]; then
        for f in 97-cloud-aliases.sh 98-golang.sh 99-improvements.sh 99-workstation.sh; do
            if [[ -f "${SYS_DIR}/${f}" ]]; then
                if $DRY_RUN; then
                    echo -e "  ${CYAN}[dry]${RESET} Would restore /etc/profile.d/${f}"
                else
                    if [[ $EUID -eq 0 ]]; then
                        cp "${SYS_DIR}/${f}" "/etc/profile.d/${f}"
                        ok "/etc/profile.d/${f}"
                    else
                        sudo cp "${SYS_DIR}/${f}" "/etc/profile.d/${f}" 2>/dev/null \
                            && ok "/etc/profile.d/${f}" || warn "${f} — needs sudo"
                    fi
                fi
            fi
        done

        for f in 99-desktop-tweaks.conf 99-workstation.conf; do
            if [[ -f "${SYS_DIR}/${f}" ]]; then
                if $DRY_RUN; then
                    echo -e "  ${CYAN}[dry]${RESET} Would restore /etc/sysctl.d/${f}"
                else
                    if [[ $EUID -eq 0 ]]; then
                        cp "${SYS_DIR}/${f}" "/etc/sysctl.d/${f}"
                        sysctl --system >> /dev/null 2>&1 || true
                        ok "/etc/sysctl.d/${f}"
                    else
                        sudo cp "${SYS_DIR}/${f}" "/etc/sysctl.d/${f}" 2>/dev/null \
                            && ok "/etc/sysctl.d/${f}" || warn "${f} — needs sudo"
                    fi
                fi
            fi
        done
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
    echo -e "${BOLD}${YELLOW}  Dry run complete — no changes were made.${RESET}"
    echo -e "  Run without ${CYAN}--dry-run${RESET} to apply."
else
    echo -e "${BOLD}${GREEN}  Restore complete!${RESET}"
    echo -e "  ${BOLD}─────────────────────────────────────${RESET}"
    echo -e "  Restored ${YELLOW}${#RESTORE_LOG[@]}${RESET} items."
    echo ""
    echo -e "  ${YELLOW}Pre-restore backups saved as *.pre-restore${RESET}"
    echo -e "  ${YELLOW}dconf backup saved as ~/.dconf-backup-pre-restore-*.ini${RESET}"
    echo ""
    echo -e "  To undo: rename ${CYAN}.pre-restore${RESET} files back, or reload dconf:"
    echo -e "    ${CYAN}dconf load / < ~/.dconf-backup-pre-restore-*.ini${RESET}"
    echo ""
    echo -e "  ${YELLOW}Restart your shell and GNOME to apply all changes.${RESET}"
fi
echo ""
