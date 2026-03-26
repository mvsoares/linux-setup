#!/usr/bin/env bash
# =============================================================================
# common.sh — Shared functions for the master setup script
# Source this before any module.
# Supports: Ubuntu 24+, Fedora 43+
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── OS Detection ──────────────────────────────────────────────────────────────
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-0}"
    DISTRO_NAME="${NAME:-Unknown}"
else
    DISTRO_ID="unknown"
    DISTRO_VERSION="0"
    DISTRO_NAME="Unknown"
fi

DISTRO_MAJOR="${DISTRO_VERSION%%.*}"
export DISTRO_ID DISTRO_VERSION DISTRO_MAJOR DISTRO_NAME

# Legacy compatibility
UBUNTU_VERSION_ID="$DISTRO_VERSION"
UBUNTU_MAJOR="$DISTRO_MAJOR"

is_ubuntu() { [[ "$DISTRO_ID" == "ubuntu" ]]; }
is_fedora() { [[ "$DISTRO_ID" == "fedora" ]]; }
is_debian_based() { [[ -f /etc/debian_version ]]; }
is_rpm_based() { command -v rpm &>/dev/null && [[ -f /etc/redhat-release || "$DISTRO_ID" == "fedora" ]]; }

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

# pipx / rustup / zoxide install to ~/.local/bin — non-interactive subshells need PATH
ensure_user_local_bin_path() {
    [[ -z "${REAL_USER:-}" || -z "${USER_HOME:-}" ]] && return 0
    local marker='# linux-setup: ~/.local/bin (pipx, cargo, user tools)'
    local rc="${USER_HOME}/.bashrc"
    [[ -f "$rc" ]] || touch "$rc"
    chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true
    if grep -qF "$marker" "$rc" 2>/dev/null; then
        return 0
    fi
    cat >> "$rc" << 'EOF'

# linux-setup: ~/.local/bin (pipx, cargo, user tools)
[[ -d "$HOME/.local/bin" ]] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
EOF
    chown "$REAL_USER:$REAL_USER" "$rc"
    ok "~/.local/bin PATH block added to ${REAL_USER}'s .bashrc"
}

# Fedora: avoid "can't create transaction lock" when PackageKit/another dnf holds RPM
wait_for_rpm_lock() {
    is_fedora || return 0
    command -v fuser &>/dev/null || return 0
    local max=120 i=0
    while fuser /usr/lib/sysimage/rpm/.rpm.lock &>/dev/null \
        || fuser /var/lib/rpm/.rpm.lock &>/dev/null; do
        [[ $i -eq 0 ]] && info "Waiting for other RPM/dnf process to release the lock..."
        i=$((i + 1))
        if [[ $i -ge $max ]]; then
            warn "RPM lock still held after ${max}s — continuing (may see transient dnf errors)"
            return 0
        fi
        sleep 1
    done
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
    # Prepend ~/.local/bin so pipx/rustup installs work in same run as setup (non-login shell)
    local _path="${USER_HOME}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    if [[ -n "$bus_addr" ]]; then
        sudo -u "$REAL_USER" \
            DBUS_SESSION_BUS_ADDRESS="$bus_addr" \
            XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
            HOME="$USER_HOME" \
            PATH="$_path" \
            bash -c "$cmd" 2>> "$LOG_FILE"
    else
        sudo -u "$REAL_USER" \
            XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
            HOME="$USER_HOME" \
            PATH="$_path" \
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

# ── APT helpers (Debian/Ubuntu) ───────────────────────────────────────────────
apt_quiet() {
    local rc=0
    DEBIAN_FRONTEND=noninteractive apt-get -y -q "$@" >> "$LOG_FILE" 2>&1 || rc=$?
    [[ $rc -ne 0 ]] && warn "apt-get $* → exit ${rc} (see log)"
    return $rc
}

apt_each() {
    if DEBIAN_FRONTEND=noninteractive apt-get -y -q install "$@" >> "$LOG_FILE" 2>&1; then
        for pkg in "$@"; do ok "${pkg}"; done
    else
        for pkg in "$@"; do
            local rc=0
            DEBIAN_FRONTEND=noninteractive apt-get -y -q install "$pkg" >> "$LOG_FILE" 2>&1 || rc=$?
            if [[ $rc -eq 0 ]]; then ok "${pkg}"; else warn "${pkg} — not found / failed (skipped)"; fi
        done
    fi
}

snap_install() {
    snap install "$@" >> "$LOG_FILE" 2>&1 || warn "snap install $* — skipped"
}

# ── DNF helpers (Fedora/RHEL) ─────────────────────────────────────────────────
dnf_quiet() {
    local rc=0
    local attempt
    for attempt in 1 2 3; do
        wait_for_rpm_lock
        dnf -y -q "$@" >> "$LOG_FILE" 2>&1 && return 0
        rc=$?
        # dnf check-update uses exit 100 when updates exist — not an error
        [[ "$1" == "check-update" && $rc -eq 100 ]] && return 0
        [[ $attempt -lt 3 ]] && sleep 3
    done
    [[ $rc -ne 0 ]] && warn "dnf $* → exit ${rc} (see log)"
    return $rc
}

dnf_each() {
    wait_for_rpm_lock
    if dnf -y -q install "$@" >> "$LOG_FILE" 2>&1; then
        for pkg in "$@"; do ok "${pkg}"; done
    else
        for pkg in "$@"; do
            local rc=0
            wait_for_rpm_lock
            dnf -y -q install "$pkg" >> "$LOG_FILE" 2>&1 || rc=$?
            # Transient RPM DB lock (PackageKit, etc.) — one retry after short wait
            if [[ $rc -ne 0 ]]; then
                wait_for_rpm_lock
                sleep 3
                dnf -y -q install "$pkg" >> "$LOG_FILE" 2>&1 && rc=0 || rc=$?
            fi
            if [[ $rc -eq 0 ]]; then ok "${pkg}"; else warn "${pkg} — not found / failed (skipped)"; fi
        done
    fi
}

# ── Distro-agnostic package helpers ───────────────────────────────────────────
pkg_install() {
    if is_fedora; then
        dnf_each "$@"
    else
        apt_each "$@"
    fi
}

pkg_quiet() {
    if is_fedora; then
        dnf_quiet "$@"
    else
        apt_quiet "$@"
    fi
}

pkg_update() {
    if is_fedora; then
        dnf_quiet check-update || true
    else
        apt_quiet update
    fi
}

# Get system architecture in a portable way
get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *)       echo "$arch" ;;
    esac
}

# Get architecture for dpkg/rpm compatibility
get_pkg_arch() {
    if is_fedora; then
        uname -m
    else
        dpkg --print-architecture 2>/dev/null || uname -m
    fi
}

# Last step of setup.sh: refresh indexes and upgrade so post-reboot session is current
final_repo_upgrade() {
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Final: package refresh & upgrade (reboot readiness) ────────────┐${RESET}"
    echo -e "${BOLD}${BLUE}│${RESET} ${CYAN}apt/dnf · flatpak · snap${RESET}"
    echo -e "${BOLD}${BLUE}└────────────────────────────────────────────────────────────────┘${RESET}"
    info "Refreshing repositories and upgrading installed packages..."
    if is_fedora; then
        local _ug _ok=0
        for _ug in 1 2 3; do
            wait_for_rpm_lock
            if dnf -y upgrade >> "$LOG_FILE" 2>&1; then
                _ok=1
                break
            fi
            [[ $_ug -lt 3 ]] && sleep 6 && info "Retrying dnf upgrade (attempt $((_ug + 1))/3)…"
        done
        [[ $_ok -eq 1 ]] || warn "dnf upgrade — see ${LOG_FILE}"
        dnf -y autoremove >> "$LOG_FILE" 2>&1 || true
    else
        apt-get update -q >> "$LOG_FILE" 2>&1 || warn "apt-get update — see ${LOG_FILE}"
        DEBIAN_FRONTEND=noninteractive apt-get -y -q upgrade >> "$LOG_FILE" 2>&1 \
            || warn "apt-get upgrade — see ${LOG_FILE}"
        DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove >> "$LOG_FILE" 2>&1 || true
    fi
    if command -v flatpak &>/dev/null; then
        flatpak update -y >> "$LOG_FILE" 2>&1 || true
    fi
    if command -v snap &>/dev/null; then
        snap refresh >> "$LOG_FILE" 2>&1 || true
    fi
    ok "Repositories updated — system packages are current (reboot when ready)"
}

# ── GitHub release helper ─────────────────────────────────────────────────────
# Browser-like UA: GitHub HTML and API sometimes return empty/403 without it;
# extensions.gnome.org rejects bare curl with 403/empty.
CURL_UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

# ── Pinned versions (fallback defaults) ──────────────────────────────────────
if [[ -f "${SCRIPT_DIR}/versions.conf" ]]; then
    # shellcheck source=../versions.conf
    source "${SCRIPT_DIR}/versions.conf"
fi

# ── Safe curl wrappers ───────────────────────────────────────────────────────
# These never crash the script under set -euo pipefail.

# Returns JSON body on success, '{}' on failure. Safe for piping to jq.
safe_curl_json() {
    curl -sSf -A "$CURL_UA" ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} \
        -H 'Accept: application/vnd.github+json' "$1" 2>/dev/null || echo '{}'
}

# Returns text body on success, empty string on failure.
safe_curl_text() {
    curl -fsSL "$1" 2>/dev/null || true
}

# Downloads a file. Returns 0 on success, 1 on failure.
safe_download() {
    curl -fsSL -A "$CURL_UA" "$1" -o "$2" >> "$LOG_FILE" 2>&1
}

# Ensure jq is installed
if ! command -v jq &>/dev/null; then
    if is_fedora; then
        dnf -y -q install jq >> "$LOG_FILE" 2>&1 || true
    else
        DEBIAN_FRONTEND=noninteractive apt-get -y -q install jq >> "$LOG_FILE" 2>&1 || true
    fi
fi

# Get latest release tag using GitHub API
_github_latest_tag() {
    safe_curl_json "https://api.github.com/repos/$1/releases/latest" \
        | jq -r '.tag_name // empty'
}

# Reliable asset URL via GitHub API
_github_api_asset_url() {
    local repo="$1" pattern="$2"
    safe_curl_json "https://api.github.com/repos/${repo}/releases/latest" \
        | jq -r ".assets[] | select(.browser_download_url | contains(\"$pattern\")) | .browser_download_url" \
        | head -1
}

# Wrapper for retro-compatibility in the script
_github_asset_url() {
    _github_api_asset_url "$1" "$3"
}

github_latest_version() {
    local tag=""
    tag=$(_github_latest_tag "$1")
    if [[ -n "$tag" ]]; then
        echo "${tag#v}"
        return
    fi
    # Fallback: grep (no jq dependency)
    safe_curl_json "https://api.github.com/repos/$1/releases/latest" \
        | grep tag_name | cut -d'"' -f4 | sed 's/^v//'
}

install_github_deb() {
    local repo="$1" pattern="$2" name="$3"
    local url="" tag=""
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$pattern")
    if [[ -n "$url" ]]; then
        local tmp=$(mktemp -d)
        if safe_download "$url" "$tmp/pkg.deb" \
                && dpkg -i "$tmp/pkg.deb" >> "$LOG_FILE" 2>&1; then
            ok "$name installed"
        else
            apt-get install -f -y >> "$LOG_FILE" 2>&1 || true
            warn "$name install had issues"
        fi
        rm -rf "$tmp"
    else
        warn "$name — could not find release"
    fi
}

install_github_rpm() {
    local repo="$1" pattern="$2" name="$3"
    local url="" tag=""
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$pattern")
    if [[ -n "$url" ]]; then
        local tmp=$(mktemp -d)
        if safe_download "$url" "$tmp/pkg.rpm" \
                && dnf install -y "$tmp/pkg.rpm" >> "$LOG_FILE" 2>&1; then
            ok "$name installed"
        else
            warn "$name install had issues"
        fi
        rm -rf "$tmp"
    else
        warn "$name — could not find release"
    fi
}

install_github_pkg() {
    local repo="$1" deb_pattern="$2" rpm_pattern="$3" name="$4"
    if is_fedora; then
        install_github_rpm "$repo" "$rpm_pattern" "$name"
    else
        install_github_deb "$repo" "$deb_pattern" "$name"
    fi
}

install_github_tar() {
    local repo="$1" pattern="$2" binary="$3" name="$4"
    local url="" tag="" altpat=""
    # Try redirect + HTML scrape (no API quota)
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$pattern")
    # Extra patterns (repos rename assets occasionally)
    if [[ -z "$url" && "$pattern" == *'Linux_x86_64'* ]]; then
        for altpat in 'linux_amd64' 'x86_64'; do
            url=$(_github_asset_url "$repo" "$tag" "$altpat")
            [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$altpat")
            [[ -n "$url" ]] && break
        done
    fi
    if [[ -z "$url" && "$pattern" == *'musl'* ]]; then
        for altpat in 'x86_64-unknown-linux-gnu' 'linux-x86_64'; do
            url=$(_github_asset_url "$repo" "$tag" "$altpat")
            [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$altpat")
            [[ -n "$url" ]] && break
        done
    fi
    if [[ -n "$url" ]]; then
        local tmp=$(mktemp -d)
        if ! safe_download "$url" "$tmp/archive"; then
            warn "$name — download failed"; rm -rf "$tmp"; return 0
        fi
        if ! tar -xf "$tmp/archive" -C "$tmp" >> "$LOG_FILE" 2>&1; then
            warn "$name — extraction failed"; rm -rf "$tmp"; return 0
        fi
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
