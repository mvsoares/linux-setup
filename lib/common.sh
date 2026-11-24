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
    (( pct > 100 )) && pct=100
    local filled=$(( pct * 22 / 100 ))
    local bar=""
    for ((i=0; i<filled; i++));  do bar+="█"; done
    for ((i=filled; i<22; i++)); do bar+="░"; done
    echo -e "  ${CYAN}▸${RESET} [${GREEN}${bar}${RESET}] ${BOLD}${pct}%${RESET}  $*"
}

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    (( pct > 100 )) && pct=100
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
    USER_GROUP=$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")
    export REAL_USER USER_HOME USER_ID USER_GROUP
}

# pipx / rustup / zoxide install to ~/.local/bin — non-interactive subshells need PATH
ensure_user_local_bin_path() {
    [[ -z "${REAL_USER:-}" || -z "${USER_HOME:-}" ]] && return 0
    local grp="${USER_GROUP:-$REAL_USER}"
    # Pre-create standard XDG user dirs owned by the real user so running as root
    # never leaves ~/.local or ~/.config owned by root:root (breaks pipx, synth-shell, etc.)
    local d
    for d in \
        "${USER_HOME}/.local" \
        "${USER_HOME}/.local/bin" \
        "${USER_HOME}/.local/share" \
        "${USER_HOME}/.local/share/applications" \
        "${USER_HOME}/.local/share/man" \
        "${USER_HOME}/.local/state" \
        "${USER_HOME}/.config" \
        "${USER_HOME}/.cache" \
        "${USER_HOME}/.bashrc.d"; do
        mkdir -p "$d"
        chown "${REAL_USER}:${grp}" "$d" 2>/dev/null || true
    done

    local marker='# linux-setup: ~/.local/bin (pipx, cargo, user tools)'
    local rc="${USER_HOME}/.bashrc"
    [[ -f "$rc" ]] || touch "$rc"
    chown "${REAL_USER}:${grp}" "$rc" 2>/dev/null || true
    if ! grep -qF "$marker" "$rc" 2>/dev/null; then
        cat >> "$rc" << 'EOF'

# linux-setup: ~/.local/bin (pipx, cargo, user tools)
[[ -d "$HOME/.local/bin" ]] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
EOF
        chown "${REAL_USER}:${grp}" "$rc"
        ok "~/.local/bin PATH block added to ${REAL_USER}'s .bashrc"
    fi
    ensure_bashrc_d
}

# Ensure ~/.bashrc.d/ exists and is sourced by ~/.bashrc so non-login interactive
# terminals (GNOME Terminal, WezTerm on Ubuntu) load modular shell configs too.
ensure_bashrc_d() {
    [[ -z "${REAL_USER:-}" || -z "${USER_HOME:-}" ]] && return 0
    local grp="${USER_GROUP:-$REAL_USER}"
    local rc="${USER_HOME}/.bashrc"
    local d="${USER_HOME}/.bashrc.d"
    mkdir -p "$d"
    chown "${REAL_USER}:${grp}" "$d" 2>/dev/null || true
    [[ -f "$rc" ]] || touch "$rc"
    local marker='# linux-setup: load ~/.bashrc.d/*.sh'
    if ! grep -qF "$marker" "$rc" 2>/dev/null; then
        cat >> "$rc" << 'EOF'

# linux-setup: load ~/.bashrc.d/*.sh
if [[ -d "$HOME/.bashrc.d" ]]; then
    for _rc_snip in "$HOME/.bashrc.d"/*.sh; do
        [[ -r "$_rc_snip" ]] && source "$_rc_snip"
    done
    unset _rc_snip
fi
EOF
        chown "${REAL_USER}:${grp}" "$rc"
    fi
}

# Install a drop-in shell snippet to both /etc/profile.d (login shells) and
# ~/.bashrc.d (interactive non-login shells).
install_shell_snippet() {
    local filename="$1"
    local src_content="$2"
    local grp="${USER_GROUP:-${REAL_USER:-root}}"
    printf '%s\n' "$src_content" > "/etc/profile.d/${filename}"
    chmod 644 "/etc/profile.d/${filename}"
    if [[ -n "${REAL_USER:-}" && -n "${USER_HOME:-}" ]]; then
        mkdir -p "${USER_HOME}/.bashrc.d"
        chown "${REAL_USER}:${grp}" "${USER_HOME}/.bashrc.d" 2>/dev/null || true
        printf '%s\n' "$src_content" > "${USER_HOME}/.bashrc.d/${filename}"
        chown "${REAL_USER}:${grp}" "${USER_HOME}/.bashrc.d/${filename}"
        chmod 644 "${USER_HOME}/.bashrc.d/${filename}"
    fi
}

# Profile helper (full | dev | minimal | server)
is_server_profile() { [[ "${SETUP_PROFILE:-full}" == "server" ]]; }

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

# GNOME Shell extensions ship their gsettings schema inside their own
# extension directory, not compiled into /usr/share/glib-2.0/schemas. Plain
# `gsettings` calls can't see those schemas unless GSETTINGS_SCHEMA_DIR points
# at them (glib treats it as additive to the standard search path).
ext_schema_dirs() {
    local dirs=() d
    for base in "${USER_HOME}/.local/share/gnome-shell/extensions" "/usr/share/gnome-shell/extensions"; do
        [[ -d "$base" ]] || continue
        for d in "$base"/*/schemas; do
            [[ -d "$d" ]] && dirs+=("$d")
        done
    done
    local IFS=:
    echo "${dirs[*]}"
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
    local _schema_dir; _schema_dir="$(ext_schema_dirs)"
    if [[ -n "$bus_addr" ]]; then
        sudo -u "$REAL_USER" \
            DBUS_SESSION_BUS_ADDRESS="$bus_addr" \
            XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
            HOME="$USER_HOME" \
            PATH="$_path" \
            GSETTINGS_SCHEMA_DIR="$_schema_dir" \
            bash -c "$cmd" 2>> "$LOG_FILE"
    else
        sudo -u "$REAL_USER" \
            XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
            HOME="$USER_HOME" \
            PATH="$_path" \
            GSETTINGS_SCHEMA_DIR="$_schema_dir" \
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

# ── Repository Helpers ────────────────────────────────────────────────────────
# Curl timeouts to avoid indefinite hangs on flaky networks
CURL_TIMEOUT_OPTS=(--connect-timeout 15 --max-time 300)

add_apt_repo() {
    local name="$1" key_url="$2" key_file="$3" repo_list_file="$4" repo_content="$5"
    if [[ -f "$repo_list_file" && -s "$key_file" ]]; then
        tick "${name} repo — already present"
        return 0
    fi
    info "Adding ${name} repo..."
    if [[ -n "$key_url" && -n "$key_file" ]]; then
        mkdir -p "$(dirname "$key_file")"
        local tmp_key
        tmp_key=$(mktemp)
        if ! curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "$key_url" -o "$tmp_key" >> "$LOG_FILE" 2>&1; then
            rm -f "$tmp_key"
            warn "${name} key failed"
            return 1
        fi
        # Only dearmor ASCII-armored PGP keys; binary keyrings (.gpg) must not be
        # passed to gpg --dearmor (GnuPG 2.4+ fails or corrupts binary keyrings).
        if grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$tmp_key" 2>/dev/null; then
            if ! gpg --batch --yes --dearmor -o "$key_file" < "$tmp_key" >> "$LOG_FILE" 2>&1; then
                rm -f "$tmp_key"
                warn "${name} key dearmor failed"
                return 1
            fi
        else
            cp "$tmp_key" "$key_file"
        fi
        chmod 644 "$key_file"
        rm -f "$tmp_key"
    fi
    echo "$repo_content" > "$repo_list_file"
    tick "${name} repo added"
}

add_dnf_repo() {
    local name="$1" repo_url_or_content="$2" repo_file="$3" key_url="${4:-}"
    if [[ -f "$repo_file" ]]; then
        tick "${name} repo — already present"
        return 0
    fi
    info "Adding ${name} repo..."
    if [[ -n "$key_url" ]]; then
        if ! rpm --import "$key_url" >> "$LOG_FILE" 2>&1; then
            warn "${name} key failed"
            return 1
        fi
    fi
    if [[ "$repo_url_or_content" == http* ]]; then
        if ! dnf config-manager addrepo --from-repofile="$repo_url_or_content" >> "$LOG_FILE" 2>&1; then
            warn "${name} repo failed"
            return 1
        fi
    else
        echo "$repo_url_or_content" > "$repo_file"
    fi
    tick "${name} repo added"
}

# ── APT helpers (Debian/Ubuntu) ───────────────────────────────────────────────
APT_LOCK_OPT=(-o DPkg::Lock::Timeout=120)

apt_quiet() {
    local rc=0
    DEBIAN_FRONTEND=noninteractive apt-get "${APT_LOCK_OPT[@]}" -y -q "$@" >> "$LOG_FILE" 2>&1 || rc=$?
    [[ $rc -ne 0 ]] && warn "apt-get $* → exit ${rc} (see log)"
    return $rc
}

apt_each() {
    for pkg in "$@"; do
        local rc=0
        DEBIAN_FRONTEND=noninteractive apt-get "${APT_LOCK_OPT[@]}" -y -q install "$pkg" >> "$LOG_FILE" 2>&1 || rc=$?
        if [[ $rc -eq 0 ]]; then ok "${pkg}"; else warn "${pkg} — not found / failed (skipped)"; fi
    done
}

snap_install() {
    snap install "$@" >> "$LOG_FILE" 2>&1 || warn "snap install $* — skipped"
}

# ── DNF helpers (Fedora/RHEL) ─────────────────────────────────────────────────
dnf_quiet() {
    local rc=0
    local attempt
    for attempt in {1..5}; do
        wait_for_rpm_lock
        dnf -y -q "$@" >> "$LOG_FILE" 2>&1 && return 0
        rc=$?
        # dnf check-update uses exit 100 when updates exist — not an error
        [[ "$1" == "check-update" && $rc -eq 100 ]] && return 0
        [[ $attempt -lt 5 ]] && sleep 5
    done
    [[ $rc -ne 0 ]] && warn "dnf $* → exit ${rc} (see log)"
    return $rc
}

dnf_each() {
    for pkg in "$@"; do
        local rc=0
        local attempt
        for attempt in {1..5}; do
            wait_for_rpm_lock
            dnf -y -q install "$pkg" >> "$LOG_FILE" 2>&1 && { rc=0; break; }
            rc=$?
            [[ $attempt -lt 5 ]] && sleep 5
        done
        if [[ $rc -eq 0 ]]; then ok "${pkg}"; else warn "${pkg} — not found / failed (skipped)"; fi
    done
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

# Get system architecture in a portable way (amd64 / arm64)
get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *)       echo "$arch" ;;
    esac
}

# Get system architecture in x86_64 / arm64 form (used by Neovim, etc.)
get_arch_x86_arm64() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "x86_64" ;;
        aarch64) echo "arm64" ;;
        *)       echo "$arch" ;;
    esac
}

# Get system architecture in Rust target form (x86_64 / aarch64)
get_arch_rust() {
    uname -m
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

# Optional: export GITHUB_TOKEN for higher GitHub API rate limits (CI / many VMs).

_gh_api_curl() {
    local auth_header=()
    [[ -n "${GITHUB_TOKEN:-}" ]] && auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    curl -sSf "${CURL_TIMEOUT_OPTS[@]}" -A "$CURL_UA" "${auth_header[@]}" -H 'Accept: application/vnd.github+json' "$@"
}

# Get latest release tag via redirect header (no API quota used)
_github_latest_tag() {
    local loc tag
    loc=$(curl -sSIL "${CURL_TIMEOUT_OPTS[@]}" -A "$CURL_UA" "https://github.com/$1/releases/latest" 2>/dev/null \
        | grep -i '^location:' | tail -1)
    tag=$(echo "$loc" | sed 's|.*/tag/||; s/\r//; s/[[:space:]]//g')
    if [[ -z "$tag" ]]; then
        tag=$(_gh_api_curl "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
            | grep '"tag_name"' | head -1 | cut -d'"' -f4)
    fi
    echo "$tag"
}

# Find asset download URL from release HTML page (no API quota used)
_github_asset_url() {
    local repo="$1" tag="$2" pattern="$3"
    local html url
    html=$(curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -A "$CURL_UA" -L "https://github.com/${repo}/releases/expanded_assets/${tag}" 2>/dev/null) || html=""
    # Prefer Perl \K (fast); fall back to grep -E (no PCRE / uutils grep)
    url=$(echo "$html" | grep -oP 'href="\K[^"]*'"$pattern"'[^"]*' 2>/dev/null | head -1)
    [[ -z "$url" ]] && url=$(echo "$html" | grep -oE 'href="[^"]+"' | sed 's/^href="//;s/"$//' | grep -F "$pattern" | head -1)
    if [[ -n "$url" && ! "$url" =~ ^https ]]; then
        [[ "$url" =~ ^// ]] && url="https:${url}"
        [[ "$url" =~ ^/ ]] && url="https://github.com${url}"
    fi
    echo "$url"
}

# Reliable asset URL via GitHub API (uses GITHUB_TOKEN if set)
_github_api_asset_url() {
    local repo="$1" pattern="$2"
    _gh_api_curl "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep -F "$pattern" | head -1 | cut -d'"' -f4
}

github_latest_version() {
    local tag
    tag=$(_github_latest_tag "$1")
    if [[ -n "$tag" ]]; then
        echo "${tag#v}"
        return
    fi
    _gh_api_curl "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
        | grep tag_name | cut -d'"' -f4 | sed 's/^v//'
}

install_github_deb() {
    local repo="$1" pattern="$2" name="$3"
    local url="" tag
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$pattern")
    if [[ -n "$url" ]]; then
        local tmp
        tmp=$(mktemp -d)
        if curl -sSfL "${CURL_TIMEOUT_OPTS[@]}" -A "$CURL_UA" "$url" -o "$tmp/pkg.deb" >> "$LOG_FILE" 2>&1; then
            dpkg -i "$tmp/pkg.deb" >> "$LOG_FILE" 2>&1 \
                && ok "$name installed" \
                || { apt-get install -f -y >> "$LOG_FILE" 2>&1; warn "$name install had issues"; }
        else
            warn "$name — download failed"
        fi
        rm -rf "$tmp"
    else
        warn "$name — could not find release"
    fi
}

install_github_rpm() {
    local repo="$1" pattern="$2" name="$3"
    local url="" tag
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$pattern")
    if [[ -n "$url" ]]; then
        local tmp
        tmp=$(mktemp -d)
        if curl -sSfL "${CURL_TIMEOUT_OPTS[@]}" -A "$CURL_UA" "$url" -o "$tmp/pkg.rpm" >> "$LOG_FILE" 2>&1; then
            dnf install -y "$tmp/pkg.rpm" >> "$LOG_FILE" 2>&1 \
                && ok "$name installed" \
                || warn "$name install had issues"
        else
            warn "$name — download failed"
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
    local url="" tag altpat
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
        local rarch; rarch=$(get_arch_rust)
        for altpat in "${rarch}-unknown-linux-gnu" "linux-${rarch}"; do
            url=$(_github_asset_url "$repo" "$tag" "$altpat")
            [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$altpat")
            [[ -n "$url" ]] && break
        done
    fi
    if [[ -n "$url" ]]; then
        local tmp
        tmp=$(mktemp -d)
        # Download to file first — tar can auto-detect compression from file but not from stdin pipe
        if curl -sSfL "${CURL_TIMEOUT_OPTS[@]}" -A "$CURL_UA" "$url" -o "$tmp/archive" >> "$LOG_FILE" 2>&1; then
            if tar -xf "$tmp/archive" -C "$tmp" >> "$LOG_FILE" 2>&1; then
                local bin_path
                bin_path=$(find "$tmp" -name "$binary" -type f 2>/dev/null | head -1)
                if [[ -n "$bin_path" ]]; then
                    install -m 755 "$bin_path" /usr/local/bin/"$binary"
                    ok "$name installed"
                else
                    warn "$name — binary not found in archive"
                fi
            else
                warn "$name — archive extraction failed"
            fi
        else
            warn "$name — download failed"
        fi
        rm -rf "$tmp"
    else
        warn "$name — could not find release"
    fi
}

install_github_zip() {
    local repo="$1" pattern="$2" binary="$3" name="$4"
    local url="" tag
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$pattern")
    if [[ -n "$url" ]]; then
        local tmp
        tmp=$(mktemp -d)
        if curl -sSfL "${CURL_TIMEOUT_OPTS[@]}" -A "$CURL_UA" "$url" -o "$tmp/archive.zip" >> "$LOG_FILE" 2>&1; then
            if unzip -qo "$tmp/archive.zip" -d "$tmp" >> "$LOG_FILE" 2>&1; then
                local bin_path
                bin_path=$(find "$tmp" -name "$binary" -type f 2>/dev/null | head -1)
                if [[ -n "$bin_path" ]]; then
                    install -m 755 "$bin_path" /usr/local/bin/"$binary"
                    ok "$name installed"
                else
                    warn "$name — binary not found in zip"
                fi
            else
                warn "$name — zip extraction failed"
            fi
        else
            warn "$name — download failed"
        fi
        rm -rf "$tmp"
    else
        warn "$name — could not find release"
    fi
}

install_github_bin() {
    local repo="$1" pattern="$2" binary="$3" name="$4"
    local url="" tag
    tag=$(_github_latest_tag "$repo")
    [[ -n "$tag" ]] && url=$(_github_asset_url "$repo" "$tag" "$pattern")
    [[ -z "$url" ]] && url=$(_github_api_asset_url "$repo" "$pattern")
    if [[ -n "$url" ]]; then
        local tmp
        tmp=$(mktemp)
        if curl -sSfL "${CURL_TIMEOUT_OPTS[@]}" -A "$CURL_UA" "$url" -o "$tmp" >> "$LOG_FILE" 2>&1; then
            install -m 755 "$tmp" /usr/local/bin/"$binary"
            ok "$name installed"
        else
            warn "$name — download failed"
        fi
        rm -f "$tmp"
    else
        warn "$name — could not find release"
    fi
}
