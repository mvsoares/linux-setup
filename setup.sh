#!/usr/bin/env bash
# =============================================================================
#  ███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗
#  ████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
#  ██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝
#  ██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗
#  ██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║
#  ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
#       Linux Workstation Setup — Full Dev Environment
#       Supports: Ubuntu 24+ / Fedora 43+
# =============================================================================
# Idempotent, checkpoint-based — safe to re-run at any time.
#
# Usage:
#   sudo bash setup.sh                        — run all modules (resume from checkpoints)
#   sudo bash setup.sh --profile server       — headless profile (skip GUI/GNOME/fonts)
#   sudo bash setup.sh --profile minimal      — core CLI, shell, languages & workspace
#   sudo bash setup.sh --dry-run              — inspect environment & execution plan
#   sudo bash setup.sh --reset                — clear all checkpoints, run fresh
#   sudo bash setup.sh --reset 5              — re-run only step 5
#   sudo bash setup.sh --only 3,5,7           — run only specific steps
#   sudo bash setup.sh --skip 1               — skip step 1 (Repos & NVIDIA)
#   sudo bash setup.sh --list                 — list all steps
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Globals ───────────────────────────────────────────────────────────────────
export CURRENT_STEP=0
mkdir -p "/var/log/linux-setup" 2>/dev/null || true
export LOG_FILE="/var/log/linux-setup/setup-$(date +%Y%m%d-%H%M%S).log"
export STATE_DIR="/var/cache/workstation-setup"
export ERRORS=0
export SETUP_PROFILE="full"
DRY_RUN=0

# ── Source shared library ─────────────────────────────────────────────────────
source "${SCRIPT_DIR}/lib/common.sh"

# ── Module list ───────────────────────────────────────────────────────────────
MODULES=(
    "01-repos-nvidia.sh:Repositories & NVIDIA Drivers"
    "02-system-cli.sh:System Utilities & Modern CLI Tools"
    "03-shell.sh:Shell Enhancements & Terminal Config"
    "04-fonts-themes.sh:Developer Fonts · GTK Themes · Icons"
    "05-gnome.sh:GNOME Extensions & Desktop Configuration"
    "06-cloud-k8s.sh:Cloud CLIs & Kubernetes Tools"
    "07-languages.sh:Language Runtimes & Version Managers"
    "08-editors.sh:Editor Setup (VSCodium · Neovim · WezTerm)"
    "09-workspace.sh:Workspace Config (Git · Tmux · Direnv)"
    "10-tweaks.sh:System Tweaks · Performance · Cleanup"
)

export TOTAL_STEPS=${#MODULES[@]}

# ── CLI argument parsing ──────────────────────────────────────────────────────
ONLY_STEPS=()
SKIP_STEPS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --reset)
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                reset_step "$2"
                echo -e "  ${YELLOW}⚠${RESET}  Step $2 checkpoint cleared"
                shift
            else
                rm -rf "$STATE_DIR"
                echo -e "  ${YELLOW}⚠${RESET}  All checkpoints cleared — running full install"
            fi
            ;;
        --profile)
            SETUP_PROFILE="${2:-full}"
            case "$SETUP_PROFILE" in
                full|dev)
                    ;;
                minimal)
                    ONLY_STEPS=(1 2 3 7 9)
                    ;;
                server)
                    SKIP_STEPS+=(4 5)
                    ;;
                *)
                    echo -e "${RED}Invalid profile:${RESET} ${SETUP_PROFILE} (use: full, dev, minimal, server)"
                    exit 1
                    ;;
            esac
            shift
            ;;
        --dry-run|--check)
            DRY_RUN=1
            ;;
        --only)
            _only="${2:-}"
            IFS=',' read -ra ONLY_STEPS <<< "${_only// /}"
            shift
            ;;
        --skip)
            _skip="${2:-}"
            IFS=',' read -ra _skip_extra <<< "${_skip// /}"
            SKIP_STEPS+=("${_skip_extra[@]}")
            shift
            ;;
        --list)
            echo ""
            echo -e "${BOLD}Available modules:${RESET}"
            for i in "${!MODULES[@]}"; do
                local_step=$((i + 1))
                local_desc="${MODULES[$i]#*:}"
                local_file="${MODULES[$i]%%:*}"
                echo -e "  ${CYAN}${local_step})${RESET} ${local_desc} ${DIM}(${local_file})${RESET}"
            done
            echo ""
            exit 0
            ;;
        --help|-h)
            echo "Usage: sudo bash setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --profile NAME  Select preset: full (default), dev, minimal, server"
            echo "  --dry-run       Show environment info and execution plan without making changes"
            echo "  --reset [N]     Clear checkpoint(s) and re-run (all or step N)"
            echo "  --only 1,3,5    Run only specific steps"
            echo "  --skip 1        Skip specific steps (e.g., 1 for Repos/NVIDIA)"
            echo "  --list          List all available modules"
            echo "  --help          Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option:${RESET} $1 (see --help)"
            exit 1
            ;;
    esac
    shift
done

# ── Should we run this step? ──────────────────────────────────────────────────
should_run_step() {
    local n="$1"
    if [[ ${#ONLY_STEPS[@]} -gt 0 ]]; then
        for s in "${ONLY_STEPS[@]}"; do [[ "$s" == "$n" ]] && return 0; done
        return 1
    fi
    for s in "${SKIP_STEPS[@]}"; do [[ "$s" == "$n" ]] && return 1; done
    return 0
}

# ── Dry-run / preflight check ─────────────────────────────────────────────────
if [[ "$DRY_RUN" -eq 1 ]]; then
    detect_user
    echo ""
    echo -e "${BOLD}${CYAN}Linux Workstation Setup — Dry-Run / Preflight Check${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────${RESET}"
    echo -e "  Distro    : ${YELLOW}${DISTRO_NAME} ${DISTRO_VERSION}${RESET} (${DISTRO_ID})"
    echo -e "  Arch      : ${YELLOW}$(uname -m)${RESET} (pkg: $(get_pkg_arch), go/k8s: $(get_arch))"
    echo -e "  Kernel    : ${YELLOW}$(uname -r)${RESET}"
    echo -e "  Session   : ${YELLOW}${XDG_SESSION_TYPE:-headless}${RESET} (${XDG_CURRENT_DESKTOP:-none})"
    echo -e "  GPU       : ${YELLOW}$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //' || echo 'unknown')${RESET}"
    echo -e "  User      : ${YELLOW}${REAL_USER:-$(whoami)}${RESET} (${USER_HOME:-$HOME})"
    echo -e "  Profile   : ${YELLOW}${SETUP_PROFILE}${RESET}"
    echo ""
    echo -e "${BOLD}Execution plan:${RESET}"
    for i in "${!MODULES[@]}"; do
        step_num=$((i + 1))
        module_file="${MODULES[$i]%%:*}"
        module_desc="${MODULES[$i]#*:}"
        if ! should_run_step "$step_num"; then
            echo -e "  ${DIM}[skip]${RESET}  Step ${step_num}/${TOTAL_STEPS} — ${module_desc} (${module_file})"
        elif step_done "$step_num"; then
            echo -e "  ${YELLOW}[done]${RESET}  Step ${step_num}/${TOTAL_STEPS} — ${module_desc} [checkpoint exists]"
        else
            echo -e "  ${GREEN}[run] ${RESET}  Step ${step_num}/${TOTAL_STEPS} — ${module_desc} (${module_file})"
        fi
    done
    echo ""
    exit 0
fi

# ── Banner ────────────────────────────────────────────────────────────────────
[[ -t 1 ]] && clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'

  ██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗███████╗████████╗ █████╗ ████████╗██╗ ██████╗ ███╗   ██╗
  ██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝██╔════╝╚══██╔══╝██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║
  ██║ █╗ ██║██║   ██║██████╔╝█████╔╝ ███████╗   ██║   ███████║   ██║   ██║██║   ██║██╔██╗ ██║
  ██║███╗██║██║   ██║██╔══██╗██╔═██╗ ╚════██║   ██║   ██╔══██║   ██║   ██║██║   ██║██║╚██╗██║
  ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗███████║   ██║   ██║  ██║   ██║   ██║╚██████╔╝██║ ╚████║
   ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
            Linux Dev Workstation — Full Environment Setup

BANNER
echo -e "${RESET}"
echo -e "  Distro    : ${YELLOW}${DISTRO_NAME} ${DISTRO_VERSION}${RESET}"
echo -e "  Arch      : ${YELLOW}$(uname -m)${RESET}"
echo -e "  Profile   : ${YELLOW}${SETUP_PROFILE}${RESET}"
echo -e "  Log       : ${YELLOW}${LOG_FILE}${RESET}"
echo -e "  State     : ${YELLOW}${STATE_DIR}${RESET}"
echo -e "  Modules   : ${YELLOW}${#MODULES[@]}${RESET}"
echo -e "  Started   : ${YELLOW}$(date)${RESET}"
echo ""

require_root
detect_user
info "Configuring for user: ${BOLD}${REAL_USER}${RESET} (${USER_HOME})"
ensure_user_local_bin_path

# Keep sudo alive
while true; do sudo -n true; sleep 55; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPER_PID=$!
cleanup() {
    kill $SUDO_KEEPER_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── Run modules ──────────────────────────────────────────────────────────────
for i in "${!MODULES[@]}"; do
    step_num=$((i + 1))
    module_file="${MODULES[$i]%%:*}"
    module_desc="${MODULES[$i]#*:}"
    module_path="${SCRIPT_DIR}/modules/${module_file}"

    if ! should_run_step "$step_num"; then
        CURRENT_STEP=$((CURRENT_STEP + 1))
        ok "Step ${step_num}/${TOTAL_STEPS} — ${module_desc} [skipped by user]"
        continue
    fi

    if step_done "$step_num"; then
        CURRENT_STEP=$((CURRENT_STEP + 1))
        ok "Step ${step_num}/${TOTAL_STEPS} — ${module_desc} [checkpoint — skipping]"
        continue
    fi

    if [[ ! -f "$module_path" ]]; then
        CURRENT_STEP=$((CURRENT_STEP + 1))
        warn "Module not found: ${module_file}"
        continue
    fi

    step "$module_desc"
    source "$module_path"
    mark_done "$step_num"
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║           WORKSTATION SETUP COMPLETE                             ║${RESET}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ Repos    : GitHub CLI · Google Chrome · Flathub"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ NVIDIA   : drivers · Vulkan · power rules"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ CLI      : bat · eza · delta · fd · rg · fzf · atuin · yazi · xh"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ Shell    : Starship · synth-shell · ~/.bashrc.d · completions"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ Fonts    : 20+ Nerd Fonts · Inter · Geist (GTK themes: optional)"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ GNOME    : Dash-to-Panel · Blur · shortcuts · cap-screen"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ Cloud    : AWS · GCP · Azure · kubectl · k9s · tofu · trivy"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ Langs    : nvm · uv · pyenv · rustup · Go · SDKMAN (JDK 25)"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ Editors  : VSCodium · Neovim · WezTerm · AI CLIs"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ Workspace: git-delta · tmux+TPM · direnv · editorconfig"
printf "${BOLD}${GREEN}║${RESET}  %-64s${BOLD}${GREEN}║${RESET}\n" "✔ Tweaks   : ZRAM (zstd, swappiness=100) · BBR · firewall · cleanup"
[[ $ERRORS -gt 0 ]] && \
printf "${BOLD}${GREEN}║${RESET}  ${YELLOW}%-64s${RESET}${BOLD}${GREEN}║${RESET}\n" "⚠  ${ERRORS} non-fatal warning(s) — see ${LOG_FILE}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${BOLD}${GREEN}║${RESET}  ${YELLOW}Reboot recommended to apply all changes.${RESET}                       ${BOLD}${GREEN}║${RESET}"
echo -e "${BOLD}${GREEN}║${RESET}  Re-run a step: ${CYAN}sudo bash setup.sh --reset <N>${RESET}                  ${BOLD}${GREEN}║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Finished  : ${YELLOW}$(date)${RESET}"
echo -e "  Errors    : ${YELLOW}${ERRORS}${RESET}"
echo -e "  Log       : ${YELLOW}${LOG_FILE}${RESET}"
echo ""

# ── Optional: GTK themes, icons & cursors ────────────────────────────────────
THEMES_SCRIPT="${SCRIPT_DIR}/scripts/install-themes.sh"
if [[ -f "$THEMES_SCRIPT" && -t 0 ]] && ! is_server_profile; then
    echo -e "${BOLD}${CYAN}┌─ Optional: GTK Themes · Icons · Cursors ───────────────────────┐${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET}  Dracula · Catppuccin · Arc · Materia · Numix · Greybird        ${BOLD}${CYAN}│${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET}  Papirus · Tela icons   ·   Bibata Modern cursor                ${BOLD}${CYAN}│${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET}  Skipped during main install (slow — optional).                 ${BOLD}${CYAN}│${RESET}"
    echo -e "${BOLD}${CYAN}└────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
    printf "  Install GTK themes now? [y/N] "
    read -r -t 30 _gtk_ans || _gtk_ans="n"
    echo ""
    if [[ "${_gtk_ans,,}" == "y" ]]; then
        echo -e "  ${CYAN}→  Starting GTK theme installer...${RESET}"
        bash "$THEMES_SCRIPT"
    else
        echo -e "  Install later:  ${YELLOW}sudo bash scripts/install-themes.sh${RESET}"
        echo ""
    fi
fi

# ── Final upgrade: indexes + upgrades so the next boot is on a fully current system
final_repo_upgrade
