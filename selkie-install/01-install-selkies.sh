#!/usr/bin/env bash
# =============================================================================
# 01-install-selkies.sh — Selkies HTML5 remote desktop + coturn TURN relay
#
# Run ON the target VM, logged in AS the desktop user, with sudo:
#   sudo bash 01-install-selkies.sh
#
# Installs Selkies (attaches to CRD's virtual display :20, falls back to :0),
# a correctly configured coturn TURN-over-TCP relay, and fixes the two other
# issues that silently break this stack on a headless VM:
#   - PipeWire has no default audio *source*, so pulsesrc kills the whole
#     WebRTC session (video included) in a reconnect loop
#   - xsel is missing, so clipboard sync fails
#
# Re-running is safe: existing credentials/config are kept, only the Selkies
# binaries are skipped if already installed (set FORCE_REINSTALL=1 to redo).
# =============================================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash $0"; exit 1; }

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
[[ -n "$REAL_USER" ]] || { echo "Could not determine the invoking user — run via 'sudo bash $0' from that user's own login shell"; exit 1; }
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
USER_ID=$(id -u "$REAL_USER")

SELKIES_PORT=8080
TURN_PORT=3478
TURN_USER="selkies"
IAP_RANGE="35.235.240.0/20"
SELKIES_INSTALL_DIR="/opt/selkies-gstreamer"
LOG_FILE="/tmp/install-selkies-$(date +%s).log"
CURL_UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

. /etc/os-release
_ubuntu_major="${VERSION_ID%%.*}"
if   [[ "$_ubuntu_major" -ge 25 ]]; then _ubuntu_build="ubuntu24.04"
elif [[ "$_ubuntu_major" -ge 23 ]]; then _ubuntu_build="ubuntu22.04"
else                                      _ubuntu_build="ubuntu20.04"
fi

ok()      { echo -e "  \033[0;32m✔\033[0m  $*"; }
info()    { echo -e "  \033[0;36m→\033[0m  $*"; }
warn()    { echo -e "  \033[1;33m⚠\033[0m  $*"; }
fail()    { echo -e "  \033[0;31m✖\033[0m  $*"; exit 1; }
as_user() { sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/${USER_ID}" HOME="$USER_HOME" bash -c "$*"; }

echo ""
echo "┌─ Selkies + TURN relay — HTML5 Remote Desktop ────────────────────────┐"
echo "│  Log  : ${LOG_FILE}"
echo "│  Build: ${_ubuntu_build} (host: ${VERSION_ID})"
echo "└────────────────────────────────────────────────────────────────────┘"
echo ""

# ── 1. System dependencies ───────────────────────────────────────────────────
info "Installing system dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get -y -q install \
    python3-pip \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav gstreamer1.0-vaapi \
    libx11-xcb1 libxcb-dri3-0 libxdamage1 libxfixes3 libxtst6 libxext6 \
    libpulse0 gir1.2-gst-plugins-bad-1.0 \
    coturn pulseaudio-utils xsel \
    >> "$LOG_FILE" 2>&1 \
    && ok "System dependencies" \
    || warn "Some dependencies failed — see ${LOG_FILE}"

# ── 2-7. Fetch + install Selkies (skip if already present) ──────────────────
if [[ -z "${FORCE_REINSTALL:-}" ]] && as_user "python3 -c 'import selkies_gstreamer'" &>/dev/null; then
    ok "selkies_gstreamer already installed — skipping download (FORCE_REINSTALL=1 to redo)"
else
    info "Fetching latest Selkies release..."
    _release_json=$(curl -sSf -A "$CURL_UA" \
        "https://api.github.com/repos/selkies-project/selkies/releases/latest" 2>/dev/null) \
        || fail "GitHub API unreachable"

    _version=$(echo "$_release_json" | python3 -c \
        "import sys,json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))")
    [[ -z "$_version" ]] && fail "Could not parse Selkies version"
    ok "Latest version: ${_version}"

    _asset_url() {
        echo "$_release_json" | python3 -c \
            "import sys,json,re; assets=[a['browser_download_url'] for a in json.load(sys.stdin)['assets'] if re.search(r'$1', a['name'])]; print(assets[0] if assets else '')"
    }

    _whl_url=$(_asset_url "selkies_gstreamer-.*-py3-none-any\\.whl")
    _gst_url=$(_asset_url "gstreamer-selkies_gpl_v.*_${_ubuntu_build}_amd64\\.tar\\.gz")
    _web_url=$(_asset_url "selkies-gstreamer-web_v.*\\.tar\\.gz")

    [[ -z "$_whl_url" ]] && fail "Could not find Python wheel in release assets"
    [[ -z "$_gst_url" ]] && fail "Could not find GStreamer tarball for ${_ubuntu_build}"
    [[ -z "$_web_url" ]] && fail "Could not find web assets tarball"

    _tmp=$(mktemp -d)
    trap 'rm -rf "${_tmp}"' EXIT

    info "Downloading Python wheel..."
    _whl_filename=$(basename "$_whl_url")
    curl -fsSL -A "$CURL_UA" "$_whl_url" -o "${_tmp}/${_whl_filename}" >> "$LOG_FILE" 2>&1 \
        || fail "Wheel download failed"
    ok "Wheel downloaded"

    info "Downloading GStreamer plugins (${_ubuntu_build})..."
    curl -fsSL -A "$CURL_UA" "$_gst_url" -o "${_tmp}/gstreamer.tar.gz" >> "$LOG_FILE" 2>&1 \
        || fail "GStreamer tarball download failed"
    ok "GStreamer plugins downloaded"

    info "Downloading web assets..."
    curl -fsSL -A "$CURL_UA" "$_web_url" -o "${_tmp}/web.tar.gz" >> "$LOG_FILE" 2>&1 \
        || fail "Web assets download failed"
    ok "Web assets downloaded"

    info "Extracting GStreamer plugins -> ${SELKIES_INSTALL_DIR}..."
    mkdir -p "${SELKIES_INSTALL_DIR}"
    tar -xzf "${_tmp}/gstreamer.tar.gz" -C "${SELKIES_INSTALL_DIR}" >> "$LOG_FILE" 2>&1 \
        && ok "GStreamer plugins extracted" \
        || fail "GStreamer extraction failed"

    info "Extracting web assets -> ${SELKIES_INSTALL_DIR}..."
    tar -xzf "${_tmp}/web.tar.gz" -C "${SELKIES_INSTALL_DIR}" >> "$LOG_FILE" 2>&1 \
        && ok "Web assets extracted" \
        || fail "Web assets extraction failed"

    info "Installing selkies Python package..."
    PIP_BREAK_SYSTEM_PACKAGES=1 pip3 install --no-cache-dir --ignore-installed \
        "${_tmp}/${_whl_filename}" >> "$LOG_FILE" 2>&1 \
        && ok "selkies ${_version} installed" \
        || fail "pip install failed — check ${LOG_FILE}"

    # asyncio.get_event_loop() no longer creates a loop implicitly in Python 3.10+
    _main_py=$(python3 -c "import selkies_gstreamer; import os; print(os.path.dirname(selkies_gstreamer.__file__))")/__main__.py
    if grep -q "get_event_loop()" "$_main_py" 2>/dev/null; then
        sed -i 's/    loop = asyncio.get_event_loop()/    loop = asyncio.new_event_loop()\n    asyncio.set_event_loop(loop)/' "$_main_py" \
            && ok "asyncio patch applied (Python 3.10+ compat)" \
            || warn "asyncio patch failed — selkies may not start on Python 3.10+"
    fi
fi

# ── 8. TURN relay (coturn) ────────────────────────────────────────────────────
# Required because the browser reaches this VM only through an IAP TCP tunnel:
# without a TURN-over-TCP relay, WebRTC ICE only gathers host/STUN UDP
# candidates, none of which can cross a TCP-only tunnel, and the browser hangs
# on "Connection failed". coturn must use ONLY static long-term credentials —
# mixing in use-auth-secret makes coturn silently ignore the static `user=`
# list and reject every allocation with "Cannot find credentials".
info "Configuring coturn TURN relay..."
_cfg="${USER_HOME}/.config/selkies"
mkdir -p "$_cfg"
_turn_pass_file="${_cfg}/turn_password"
if [[ ! -f "$_turn_pass_file" ]]; then
    openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c24 > "$_turn_pass_file"
fi
chown "${REAL_USER}:${REAL_USER}" "$_turn_pass_file"
chmod 600 "$_turn_pass_file"
TURN_PASS=$(cat "$_turn_pass_file")

cat > /etc/turnserver.conf << EOF
listening-port=${TURN_PORT}
listening-ip=0.0.0.0
fingerprint
lt-cred-mech
user=${TURN_USER}:${TURN_PASS}
realm=localhost
no-tls
no-dtls
no-cli
EOF

if grep -q '^TURNSERVER_ENABLED=' /etc/default/coturn 2>/dev/null; then
    sed -i 's/^TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
else
    echo 'TURNSERVER_ENABLED=1' >> /etc/default/coturn
fi
systemctl enable coturn >> "$LOG_FILE" 2>&1 || true
systemctl restart coturn >> "$LOG_FILE" 2>&1 \
    && ok "coturn running (TURN-over-TCP on :${TURN_PORT})" \
    || warn "coturn failed to start — check: systemctl status coturn"

# ── 9. Host firewall (ufw) ───────────────────────────────────────────────────
if command -v ufw &>/dev/null; then
    ufw allow from "$IAP_RANGE" to any port "${SELKIES_PORT}" proto tcp >> "$LOG_FILE" 2>&1
    ufw allow from "$IAP_RANGE" to any port "${TURN_PORT}" proto tcp >> "$LOG_FILE" 2>&1
    ok "ufw: allowed tcp/${SELKIES_PORT} and tcp/${TURN_PORT} from ${IAP_RANGE}"
else
    warn "ufw not found — skipping host firewall rules (make sure ${SELKIES_PORT}/${TURN_PORT} are reachable)"
fi
info "Also run 02-gcp-firewall.sh from your LOCAL machine (VPC-level firewall)"

# ── 10. Startup script ────────────────────────────────────────────────────────
info "Writing startup script..."
_auth="${_cfg}/auth"
if [[ ! -f "${_auth}" ]]; then
    _pass="$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c20)"
    echo "user:${_pass}" > "${_auth}"
else
    ok "Keeping existing basic-auth credentials (${_auth})"
fi
chmod 600 "${_auth}"
chown -R "${REAL_USER}:${REAL_USER}" "${_cfg}"

mkdir -p "${USER_HOME}/.local/bin"
cat > "${USER_HOME}/.local/bin/start-selkies.sh" << SCRIPT
#!/usr/bin/env bash
PASS=\$(cut -d: -f2 "\${HOME}/.config/selkies/auth" 2>/dev/null || echo "changeme")
TURN_PASS=\$(cat "\${HOME}/.config/selkies/turn_password" 2>/dev/null || echo "changeme")

# Share CRD's virtual display (:20) so both remote-desktop paths show the same
# session; fall back to :0 if CRD isn't installed.
if [[ -S /tmp/.X11-unix/X20 ]]; then
    export DISPLAY="\${DISPLAY:-:20}"
else
    export DISPLAY="\${DISPLAY:-:0}"
fi
export XAUTHORITY="\${XAUTHORITY:-\${HOME}/.Xauthority}"
export XDG_RUNTIME_DIR="\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}"
export PULSE_SERVER="unix:\${XDG_RUNTIME_DIR}/pulse/native"
export GSTREAMER_PATH="${SELKIES_INSTALL_DIR}"
export PATH="\${GSTREAMER_PATH}/bin\${PATH:+:\${PATH}}"
export LD_LIBRARY_PATH="\${GSTREAMER_PATH}/lib/x86_64-linux-gnu\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
export GST_PLUGIN_PATH="\${GSTREAMER_PATH}/lib/x86_64-linux-gnu/gstreamer-1.0\${GST_PLUGIN_PATH:+:\${GST_PLUGIN_PATH}}"
export GST_PLUGIN_SYSTEM_PATH="\${XDG_DATA_HOME:-\${HOME}/.local/share}/gstreamer-1.0/plugins:/usr/lib/x86_64-linux-gnu/gstreamer-1.0\${GST_PLUGIN_SYSTEM_PATH:+:\${GST_PLUGIN_SYSTEM_PATH}}"
export GI_TYPELIB_PATH="\${GSTREAMER_PATH}/lib/x86_64-linux-gnu/girepository-1.0:/usr/lib/x86_64-linux-gnu/girepository-1.0\${GI_TYPELIB_PATH:+:\${GI_TYPELIB_PATH}}"
export PYTHONPATH="\${GSTREAMER_PATH}/lib/python3/dist-packages\${PYTHONPATH:+:\${PYTHONPATH}}"

until [[ -S "/tmp/.X11-unix/X\${DISPLAY#*:}" ]]; do sleep 2; done

# Headless VMs have no real audio hardware — PipeWire's dummy sink exists but
# no default *source* gets picked, so pulsesrc fails with "No such entity"
# and kills the whole WebRTC session (video included) in a reconnect loop.
until [[ -S "\${XDG_RUNTIME_DIR}/pulse/native" ]]; do sleep 1; done
_sink=\$(pactl list short sinks 2>/dev/null | head -1 | cut -f2)
[[ -n "\$_sink" ]] && pactl set-default-source "\${_sink}.monitor" 2>/dev/null

exec selkies-gstreamer \\
    --addr=0.0.0.0 \\
    --port=${SELKIES_PORT} \\
    --web_root=${SELKIES_INSTALL_DIR}/gst-web \\
    --enable_https=false \\
    --enable_basic_auth=true \\
    --basic_auth_user=user \\
    --basic_auth_password="\${PASS}" \\
    --turn_host=localhost \\
    --turn_port=${TURN_PORT} \\
    --turn_protocol=tcp \\
    --turn_username=${TURN_USER} \\
    --turn_password="\${TURN_PASS}" \\
    --encoder=x264enc \\
    --enable_resize=true
SCRIPT

chmod +x "${USER_HOME}/.local/bin/start-selkies.sh"
chown "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.local/bin/start-selkies.sh"
ok "Startup script -> ${USER_HOME}/.local/bin/start-selkies.sh"

# ── 11. systemd user service ─────────────────────────────────────────────────
info "Installing systemd user service..."
_svc_dir="${USER_HOME}/.config/systemd/user"
mkdir -p "${_svc_dir}"

cat > "${_svc_dir}/selkies.service" << UNIT
[Unit]
Description=Selkies HTML5 Remote Desktop
After=default.target coturn.service

[Service]
Type=simple
ExecStart=%h/.local/bin/start-selkies.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT

chown -R "${REAL_USER}:${REAL_USER}" "${_svc_dir}"

as_user "systemctl --user daemon-reload" 2>/dev/null || true
as_user "systemctl --user enable selkies.service" >> "$LOG_FILE" 2>&1 \
    && ok "selkies.service enabled" \
    || warn "Could not enable service — run: systemctl --user enable selkies"

info "Starting selkies.service..."
as_user "systemctl --user restart selkies.service" >> "$LOG_FILE" 2>&1 \
    && ok "selkies.service started" \
    || warn "Service did not start — check: journalctl --user -u selkies -f"

# ── Summary ───────────────────────────────────────────────────────────────────
_pass=$(cut -d: -f2 "${_auth}")

echo ""
echo -e "\033[1;36m┌─ Selkies ready ────────────────────────────────────────────────────┐\033[0m"
printf "\033[1;36m│\033[0m  Basic auth : \033[0;32muser\033[0m / \033[0;32m%s\033[0m\n" "${_pass}"
printf "\033[1;36m│\033[0m  TURN creds : \033[0;32m%s\033[0m / \033[0;32m%s\033[0m (tcp/%s)\n" "${TURN_USER}" "${TURN_PASS}" "${TURN_PORT}"
echo -e "\033[1;36m│\033[0m"
echo -e "\033[1;36m│\033[0m  Next, from your LOCAL machine:"
echo -e "\033[1;36m│\033[0m   1. ./02-gcp-firewall.sh <project> <network>"
echo -e "\033[1;36m│\033[0m   2. ./connect.sh <instance> <zone> [project]"
echo -e "\033[1;36m│\033[0m"
echo -e "\033[1;36m│\033[0m  Logs : sudo journalctl _SYSTEMD_USER_UNIT=selkies.service -f"
echo -e "\033[1;36m│\033[0m         (plain 'journalctl --user -u selkies' is permission-denied"
echo -e "\033[1;36m│\033[0m          over a non-interactive SSH session on most images)"
echo -e "\033[1;36m│\033[0m  Stop : systemctl --user stop selkies"
echo -e "\033[1;36m└────────────────────────────────────────────────────────────────────┘\033[0m"
echo ""
