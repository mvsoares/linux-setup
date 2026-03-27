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
    add_dnf_repo "GitHub CLI" "https://cli.github.com/packages/rpm/gh-cli.repo" "/etc/yum.repos.d/gh-cli.repo"

    # VSCode (Fedora)
    add_dnf_repo "VSCode" \
"[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
        "/etc/yum.repos.d/vscode.repo" "https://packages.microsoft.com/keys/microsoft.asc"

    # Google Chrome (Fedora)
    add_dnf_repo "Google Chrome" \
"[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub" \
        "/etc/yum.repos.d/google-chrome.repo" "https://dl.google.com/linux/linux_signing_key.pub"

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
    add_apt_repo "GitHub CLI" "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "/usr/share/keyrings/githubcli-archive-keyring.gpg" \
        "/etc/apt/sources.list.d/github-cli.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

    # Brave Browser
    add_apt_repo "Brave Browser" "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
        "/usr/share/keyrings/brave-browser-archive-keyring.gpg" \
        "/etc/apt/sources.list.d/brave-browser-release.list" \
        "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"

    # VSCode
    add_apt_repo "VSCode" "https://packages.microsoft.com/keys/microsoft.asc" \
        "/etc/apt/keyrings/microsoft.gpg" \
        "/etc/apt/sources.list.d/vscode.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main"

    # Google Chrome
    add_apt_repo "Google Chrome" "https://dl.google.com/linux/linux_signing_key.pub" \
        "/usr/share/keyrings/google-chrome.gpg" \
        "/etc/apt/sources.list.d/google-chrome.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main"

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
