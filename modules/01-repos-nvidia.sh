# =============================================================================
# Module 01 — Extra Repositories & NVIDIA Drivers
# =============================================================================
init_sub 11

# ── Repositories ──────────────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
    info "Installing curl (required for repo setup)..."
    pkg_install curl
fi

if is_fedora; then
    wait_for_rpm_lock
    # ── Fedora Repositories ───────────────────────────────────────────────────
    info "Enabling RPM Fusion repositories..."
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
            >> "$LOG_FILE" 2>&1 && ok "RPM Fusion (free + nonfree)" || warn "RPM Fusion setup failed"
    else
        tick "RPM Fusion — already enabled"
    fi

    # GitHub CLI (Fedora)
    if command -v gh &>/dev/null; then
        tick "GitHub CLI — already present"
    else
        info "Adding GitHub CLI repo..."
        dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo \
            >> "$LOG_FILE" 2>&1 || warn "GH CLI repo failed"
        tick "GitHub CLI repo added"
    fi

    # VSCode (Fedora)
    if command -v code &>/dev/null || [[ -f /etc/yum.repos.d/vscode.repo ]]; then
        tick "VSCode repo — already present"
    else
        info "Adding Microsoft VSCode repo..."
        rpm --import https://packages.microsoft.com/keys/microsoft.asc >> "$LOG_FILE" 2>&1
        cat > /etc/yum.repos.d/vscode.repo << 'VSCODE'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
VSCODE
        tick "VSCode repo added"
    fi

    # Google Chrome (Fedora)
    if command -v google-chrome-stable &>/dev/null || [[ -f /etc/yum.repos.d/google-chrome.repo ]]; then
        tick "Google Chrome repo — already present"
    else
        info "Adding Google Chrome repo..."
        cat > /etc/yum.repos.d/google-chrome.repo << 'CHROME'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
CHROME
        tick "Google Chrome repo added"
    fi

    # Flatpak (Fedora has it by default)
    if command -v flatpak &>/dev/null; then
        flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
        tick "Flatpak + Flathub — ready"
    fi

    info "dnf check-update..."
    dnf check-update -q >> "$LOG_FILE" 2>&1 || true
    tick "Package index refreshed"

else
    # ── Ubuntu Repositories ───────────────────────────────────────────────────
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

    # Google Chrome
    if command -v google-chrome &>/dev/null \
            || { [[ -f /etc/apt/sources.list.d/google-chrome.list ]] \
                 && [[ -s /usr/share/keyrings/google-chrome.gpg ]]; }; then
        tick "Google Chrome repo — already present"
    else
        info "Adding Google Chrome repo..."
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
            | gpg --batch --yes --dearmor -o /usr/share/keyrings/google-chrome.gpg >> "$LOG_FILE" 2>&1 || warn "Chrome key failed"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-chrome.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" \
            > /etc/apt/sources.list.d/google-chrome.list
        tick "Google Chrome repo added"
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
    if command -v node &>/dev/null \
            || { [[ -f /etc/apt/sources.list.d/nodesource.list ]] \
                 && [[ -s /etc/apt/keyrings/nodesource.gpg ]]; }; then
        tick "NodeSource — already present"
    else
        info "Adding NodeSource LTS repo..."
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
            | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg >> "$LOG_FILE" 2>&1 || warn "NodeSource key failed"
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
            > /etc/apt/sources.list.d/nodesource.list
        tick "NodeSource LTS repo added"
    fi

    info "apt update..."
    apt-get update -q >> "$LOG_FILE" 2>&1 || warn "apt update had errors"
    tick "Package index refreshed"
fi

# ── NVIDIA Optimizations ─────────────────────────────────────────────────────
if ! command -v nvidia-smi &>/dev/null; then
    info "No NVIDIA GPU detected — skipping NVIDIA optimizations"
    tick "NVIDIA — skipped (no GPU)"
else
    NVIDIA_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "unknown")
    info "Detected NVIDIA driver: ${NVIDIA_VER}"

    if is_fedora; then
        dnf_each akmod-nvidia xorg-x11-drv-nvidia-cuda vulkan vdpauinfo libva-utils mesa-vulkan-drivers
    else
        apt_quiet install nvidia-settings nvidia-prime
        apt_each libvulkan1 vulkan-tools mesa-vulkan-drivers \
                 vdpauinfo vainfo mesa-utils mesa-opencl-icd
    fi
    tick "NVIDIA support packages"

    if ! is_fedora; then
        PRIME_STATUS=$(prime-select query 2>/dev/null || echo "unknown")
        if [[ "$PRIME_STATUS" == "on-demand" ]]; then
            ok "GPU on-demand mode — optimal for laptop"
        else
            warn "GPU mode: '${PRIME_STATUS}' — consider: sudo prime-select on-demand"
        fi
        tick "GPU mode: ${PRIME_STATUS}"
    fi

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
