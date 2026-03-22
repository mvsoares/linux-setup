# =============================================================================
# Module 01 — Extra Repositories & NVIDIA Drivers
# =============================================================================
init_sub 11

# ── Repositories ──────────────────────────────────────────────────────────────
info "Enabling universe / multiverse / restricted..."
for comp in universe multiverse restricted; do
    add-apt-repository -y -n "$comp" >> "$LOG_FILE" 2>&1 || true
done
tick "Core repositories enabled"

# GitHub CLI
if command -v gh &>/dev/null \
        || { [[ -f /etc/apt/sources.list.d/github-cli.list ]] \
             && [[ -s /usr/share/keyrings/githubcli-archive-keyring.gpg ]]; }; then
    tick "GitHub CLI repo — already present"
else
    info "Adding GitHub CLI repo..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg >> "$LOG_FILE" 2>&1 || warn "GH CLI key fetch failed"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
    tick "GitHub CLI repo added"
fi

# Docker CE
if command -v docker &>/dev/null \
        || { [[ -f /etc/apt/sources.list.d/docker.list ]] \
             && [[ -s /etc/apt/keyrings/docker.gpg ]]; }; then
    tick "Docker CE repo — already present"
else
    info "Adding Docker CE repo..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg >> "$LOG_FILE" 2>&1 || warn "Docker key failed"
    chmod a+r /etc/apt/keyrings/docker.gpg
    # Use VERSION_CODENAME; fall back to UBUNTU_CODENAME or noble if Docker
    # doesn't have a repo for the current release yet (e.g. Ubuntu 26 resolute)
    DOCKER_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME}")
    if ! curl -fsSL "https://download.docker.com/linux/ubuntu/dists/${DOCKER_CODENAME}/Release" \
            &>/dev/null; then
        DOCKER_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-noble}")
        info "Docker has no repo for $(. /etc/os-release && echo "$VERSION_CODENAME"), falling back to ${DOCKER_CODENAME}"
    fi
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${DOCKER_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list
    tick "Docker CE repo added"
fi

# Brave Browser
if command -v brave-browser &>/dev/null \
        || { [[ -f /etc/apt/sources.list.d/brave-browser-release.list ]] \
             && [[ -s /usr/share/keyrings/brave-browser-archive-keyring.gpg ]]; }; then
    tick "Brave Browser repo — already present"
else
    info "Adding Brave Browser repo..."
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >> "$LOG_FILE" 2>&1 || warn "Brave key failed"
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list
    tick "Brave Browser repo added"
fi

# VSCode
if command -v code &>/dev/null \
        || { [[ -f /etc/apt/sources.list.d/vscode.list ]] \
             && [[ -s /etc/apt/keyrings/microsoft.gpg ]]; }; then
    tick "VSCode repo — already present"
else
    info "Adding Microsoft VSCode repo..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --batch --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg >> "$LOG_FILE" 2>&1 || warn "MS key failed"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list
    tick "VSCode repo added"
fi

# Flatpak + Flathub
if command -v flatpak &>/dev/null; then
    tick "Flatpak — already present"
else
    info "Installing Flatpak..."
    apt_quiet install flatpak gnome-software-plugin-flatpak
    flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || warn "Flathub remote failed"
    tick "Flatpak + Flathub added"
fi

# NodeSource LTS
if command -v node &>/dev/null; then
    tick "NodeSource — already present"
else
    info "Adding NodeSource LTS repo..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >> "$LOG_FILE" 2>&1 || warn "NodeSource setup had errors"
    tick "NodeSource LTS repo added"
fi

info "apt update..."
apt-get update -q >> "$LOG_FILE" 2>&1 || warn "apt update had errors"
tick "Package index refreshed"

# ── NVIDIA Optimizations ─────────────────────────────────────────────────────
if ! command -v nvidia-smi &>/dev/null; then
    info "No NVIDIA GPU detected — skipping NVIDIA optimizations"
    tick "NVIDIA — skipped (no GPU)"
else
    NVIDIA_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "unknown")
    info "Detected NVIDIA driver: ${NVIDIA_VER}"

    apt_quiet install nvidia-settings nvidia-prime
    apt_each libvulkan1 vulkan-tools mesa-vulkan-drivers \
             vdpauinfo vainfo mesa-utils mesa-opencl-icd
    tick "NVIDIA support packages"

    PRIME_STATUS=$(prime-select query 2>/dev/null || echo "unknown")
    if [[ "$PRIME_STATUS" == "on-demand" ]]; then
        ok "GPU on-demand mode — optimal for laptop"
    else
        warn "GPU mode: '${PRIME_STATUS}' — consider: sudo prime-select on-demand"
    fi
    tick "GPU mode: ${PRIME_STATUS}"

    if systemctl is-enabled nvidia-persistenced &>/dev/null 2>&1; then
        ok "nvidia-persistenced already enabled"
    else
        systemctl enable --now nvidia-persistenced >> "$LOG_FILE" 2>&1 \
            && ok "nvidia-persistenced enabled" || warn "nvidia-persistenced unavailable"
    fi

    UDEV_RULE="/etc/udev/rules.d/80-nvidia-pm.rules"
    if [[ ! -f "$UDEV_RULE" ]]; then
        cat > "$UDEV_RULE" << 'UDEV'
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"
UDEV
        udevadm control --reload-rules >> "$LOG_FILE" 2>&1 || true
    fi
    tick "NVIDIA udev power rules + persistenced"
fi

ok "Repositories & NVIDIA complete"
