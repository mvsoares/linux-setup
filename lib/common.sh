#!/usr/bin/env bash
# =============================================================================
# common.sh — Shared functions for the master setup script
# Source this before any module.
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
# ── OS version ────────────────────────────────────────────────────────────────
UBUNTU_VERSION_ID=$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID}" || echo "0")
UBUNTU_MAJOR="${UBUNTU_VERSION_ID%%.*}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
ok()     { echo -e "  ${GREEN}✔${RESET}  $*"; }
info()   { echo -e "  ${CYAN}→${RESET}  $*"; }
warn()   { echo -e "  ${YELLOW}⚠${RESET}  $*"; ERRORS=$((ERRORS+1)); }
fail()   { echo -e "  ${RED}✖${RESET}  $*"; ERRORS=$((ERRORS+1)); }
skip()   { echo -e "  ${YELLOW}⏭${RESET}  $* — already installed, skipping"; }

# ── Progress ──────────────────────────────────────────────────────────────────
_ST_TOTAL=1; _ST_CUR=0
init_sub() { _ST_TOTAL=${1:-1}; _ST_CUR=0; }
tick() {
    _ST_CUR=$(( _ST_CUR + 1 ))
    local pct=$(( _ST_CUR * 100 / _ST_TOTAL ))
    local filled=$(( pct * 22 / 100 ))
    local bar=""
    for ((i=0; i<filled; i++));  do bar+="█"; done
    for ((i=filled; i<22; i++)); do bar+="░"; done
    echo -e "  ${CYAN}▸${RESET} [${GREEN}${bar}${RESET}] ${BOLD}${pct}%${RESET}  $*"
}

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local filled=$(( pct * 40 / 100 ))
    local bar=""
    for ((i=0; i<filled; i++));  do bar+="█"; done
    for ((i=filled; i<40; i++)); do bar+="░"; done
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Step ${CURRENT_STEP}/${TOTAL_STEPS} ──────────────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${BLUE}│${RESET} ${CYAN}${1}${RESET}"
    echo -e "${BOLD}${BLUE}│${RESET} Overall  [${GREEN}${bar}${RESET}] ${pct}%"
    echo -e "${BOLD}${BLUE}└────────────────────────────────────────────────────────────┘${RESET}"
}

# ── Checkpoint system ─────────────────────────────────────────────────────────
step_done()  { [[ -f "${STATE_DIR}/step_${1}.done" ]]; }
mark_done()  { mkdir -p "$STATE_DIR"; touch "${STATE_DIR}/step_${1}.done"; }
reset_step() { rm -f "${STATE_DIR}/step_${1}.done"; }

# ── Root / user detection ─────────────────────────────────────────────────────
require_root() {
    [[ $EUID -eq 0 ]] && return
    echo -e "${RED}Run with sudo:${RESET}  sudo bash $0"; exit 1
}

detect_user() {
    REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
    [[ -z "$REAL_USER" ]] && REAL_USER="$(id -un 1000 2>/dev/null || echo "")"
    USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6 2>/dev/null || echo "/root")
    USER_ID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")
    export REAL_USER USER_HOME USER_ID
}

as_user() {
    local cmd="$*"
    local bus_addr=""
    if [[ -S "/run/user/${USER_ID}/bus" ]]; then
        bus_addr="unix:path=/run/user/${USER_ID}/bus"
    else
        local _pid
        _pid=$(pgrep -u "$REAL_USER" -n 2>/dev/null || echo "")
        if [[ -n "$_pid" && -r "/proc/${_pid}/environ" ]]; then
            bus_addr=$(tr '\0' '\n' < "/proc/${_pid}/environ" \
                | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2- || echo "")
        fi
    fi
    if [[ -n "$bus_addr" ]]; then
        sudo -u "$REAL_USER" \
            DBUS_SESSION_BUS_ADDRESS="$bus_addr" \
            XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
            HOME="$USER_HOME" \
            bash -c "$cmd" 2>> "$LOG_FILE"
    else
        sudo -u "$REAL_USER" \
            XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
            HOME="$USER_HOME" \
            bash -c "$cmd" 2>> "$LOG_FILE"
    fi
}

gset() {
    local schema="$1"; shift
    local key="$1"; shift
    local val="$*"
    as_user "gsettings set ${schema} ${key} \"${val}\"" \
        && ok "  ${schema} ${key} = ${val}" \
        || warn "gsettings failed: ${schema} ${key}"
}

# ── APT helpers ───────────────────────────────────────────────────────────────
apt_quiet() {
    local rc=0
    DEBIAN_FRONTEND=noninteractive apt-get -y -q "$@" >> "$LOG_FILE" 2>&1 || rc=$?
    [[ $rc -ne 0 ]] && warn "apt-get $* → exit ${rc} (see log)"
    return $rc
}

apt_each() {
    for pkg in "$@"; do
        local rc=0
        DEBIAN_FRONTEND=noninteractive apt-get -y -q install "$pkg" >> "$LOG_FILE" 2>&1 || rc=$?
        if [[ $rc -eq 0 ]]; then ok "${pkg}"; else warn "${pkg} — not found / failed (skipped)"; fi
    done
}

snap_install() {
    snap install "$@" >> "$LOG_FILE" 2>&1 || warn "snap install $* — skipped"
}

# ── GitHub release helper ─────────────────────────────────────────────────────
# Get latest release tag via redirect header (no API quota used)
_github_latest_tag() {
    local loc
    loc=$(curl -sI "https://github.com/$1/releases/latest" 2>/dev/null \
        | grep -i '^location:' | head -1)
    echo "$loc" | sed 's|.*/tag/||; s/\r//; s/[[:space:]]//g'
}

# Find asset download URL from release HTML page (no API quota used)
_github_asset_url() {
    local repo="$1" tag="$2" pattern="$3"
    local url
    url=$(curl -fsSL "https://github.com/${repo}/releases/expanded_assets/${tag}" 2>/dev/null \
        | grep -oP 'href="\K[^"]*'"$pattern"'[^"]*' | head -1)
    if [[ -n "$url" && ! "$url" =~ ^https ]]; then
        url="https://github.com${url}"
    fi
    echo "$url"
}

github_latest_version() {
    local tag
    tag=$(_github_latest_tag "$1")
    if [[ -n "$tag" ]]; then
        echo "${tag#v}"
        return
    fi
    # Fall back to API (counts against rate limit)
    curl -sSf "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
        | grep tag_name | cut -d'"' -f4 | sed 's/^v//'
}

install_github_deb() {
    local repo="$1" pattern="$2" name="$3"
    local url tag
    # Try redirect + HTML scrape (no API quota)
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    # Fall back to API
    [[ -z "$url" ]] && url=$(curl -sSf "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "$pattern" | head -1 | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        local tmp=$(mktemp -d)
        curl -sSfL "$url" -o "$tmp/pkg.deb" >> "$LOG_FILE" 2>&1 \
            && dpkg -i "$tmp/pkg.deb" >> "$LOG_FILE" 2>&1 \
            && ok "$name installed" \
            || { apt-get install -f -y >> "$LOG_FILE" 2>&1; warn "$name install had issues"; }
        rm -rf "$tmp"
    else
        warn "$name — could not find release"
    fi
}

install_github_tar() {
    local repo="$1" pattern="$2" binary="$3" name="$4"
    local url tag
    # Try redirect + HTML scrape (no API quota)
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    # Fall back to API
    [[ -z "$url" ]] && url=$(curl -sSf "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "$pattern" | head -1 | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        local tmp=$(mktemp -d)
        curl -sSfL "$url" | tar xz -C "$tmp" 2>> "$LOG_FILE"
        local bin_path
        bin_path=$(find "$tmp" -name "$binary" -type f 2>/dev/null | head -1)
        if [[ -n "$bin_path" ]]; then
            install "$bin_path" /usr/local/bin/"$binary"
            ok "$name installed"
        else
            warn "$name — binary not found in archive"
        fi
        rm -rf "$tmp"
    else
        warn "$name — could not find release"
    fi
}
