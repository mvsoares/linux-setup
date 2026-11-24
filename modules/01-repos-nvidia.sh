# =============================================================================
# Module 01 — Extra Repositories & NVIDIA Drivers
# =============================================================================
init_sub 6

# ── Repositories ──────────────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
    info "Installing curl (required for repo setup)..."
    pkg_install curl
fi

ARCH_NOW=$(uname -m)

if is_fedora; then
    wait_for_rpm_lock
    # ── Fedora Repositories ───────────────────────────────────────────────────
    info "Enabling RPM Fusion repositories..."
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
            >> "$LOG_FILE" 2>&1 && ok "RPM Fusion (free + nonfree)" || warn "RPM Fusion setup failed"
    fi
    tick "RPM Fusion (free + nonfree)"

    # GitHub CLI (Fedora)
    add_dnf_repo "GitHub CLI" "https://cli.github.com/packages/rpm/gh-cli.repo" "/etc/yum.repos.d/gh-cli.repo"

    # Google Chrome (Fedora — x86_64 desktop only)
    if is_server_profile || [[ "$ARCH_NOW" != "x86_64" ]]; then
        tick "Google Chrome repo — skipped (${SETUP_PROFILE}/${ARCH_NOW})"
    else
        add_dnf_repo "Google Chrome" \
"[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub" \
            "/etc/yum.repos.d/google-chrome.repo" "https://dl.google.com/linux/linux_signing_key.pub"
    fi

    # Flatpak (desktop profiles)
    if is_server_profile; then
        tick "Flatpak + Flathub — skipped (server profile)"
    elif command -v flatpak &>/dev/null; then
        flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
        tick "Flatpak + Flathub — ready"
    else
        dnf_each flatpak
        flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
        tick "Flatpak + Flathub added"
    fi

    info "dnf check-update..."
    dnf check-update -q >> "$LOG_FILE" 2>&1 || true
    tick "Package index refreshed"

else
    # ── Ubuntu Repositories ───────────────────────────────────────────────────
    info "Enabling universe / multiverse / restricted..."
    if command -v add-apt-repository &>/dev/null; then
        for comp in universe multiverse restricted; do
            add-apt-repository -y -n "$comp" >> "$LOG_FILE" 2>&1 || true
        done
    else
        info "add-apt-repository not present (Ubuntu 26+ DEB822 default) — skipping legacy enable"
    fi
    tick "Core repositories enabled"

    # GitHub CLI
    add_apt_repo "GitHub CLI" "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "/usr/share/keyrings/githubcli-archive-keyring.gpg" \
        "/etc/apt/sources.list.d/github-cli.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

    # Google Chrome (amd64 desktop only)
    if is_server_profile || [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
        tick "Google Chrome repo — skipped (${SETUP_PROFILE}/${ARCH_NOW})"
    else
        add_apt_repo "Google Chrome" "https://dl.google.com/linux/linux_signing_key.pub" \
            "/usr/share/keyrings/google-chrome.gpg" \
            "/etc/apt/sources.list.d/google-chrome.list" \
            "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main"
    fi

    # Flatpak + Flathub (desktop profiles)
    if is_server_profile; then
        tick "Flatpak + Flathub — skipped (server profile)"
    elif command -v flatpak &>/dev/null; then
        flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
        tick "Flatpak + Flathub — ready"
    else
        info "Installing Flatpak..."
        apt_quiet install flatpak gnome-software-plugin-flatpak
        flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || warn "Flathub remote failed"
        tick "Flatpak + Flathub added"
    fi

    # Note: Node.js is managed cleanly via nvm in Module 07 (avoiding dual NodeSource + nvm installs)
    info "apt update..."
    apt-get update -q >> "$LOG_FILE" 2>&1 || warn "apt update had errors"
    tick "Package index refreshed"
fi

# ── NVIDIA Drivers & Optimizations ───────────────────────────────────────────
HAS_NVIDIA_HW=0
if command -v nvidia-smi &>/dev/null || lspci 2>/dev/null | grep -qiE 'nvidia.*(vga|3d|display)'; then
    HAS_NVIDIA_HW=1
fi

if [[ "$HAS_NVIDIA_HW" -eq 0 ]]; then
    info "No NVIDIA GPU detected — skipping NVIDIA optimizations"
    tick "NVIDIA — skipped (no GPU)"
elif ! command -v nvidia-smi &>/dev/null; then
    info "NVIDIA GPU detected via lspci, but driver is not loaded yet."
    if is_fedora; then
        dnf_each akmod-nvidia xorg-x11-drv-nvidia-cuda vulkan vdpauinfo libva-utils mesa-vulkan-drivers
        ok "NVIDIA driver packages installed (reboot to load akmod-nvidia)"
    else
        if command -v ubuntu-drivers &>/dev/null; then
            info "Installing recommended NVIDIA driver via ubuntu-drivers..."
            ubuntu-drivers autoinstall >> "$LOG_FILE" 2>&1 \
                && ok "NVIDIA driver installed via ubuntu-drivers (reboot to activate)" \
                || warn "ubuntu-drivers autoinstall failed — install manually via Software & Updates"
        else
            warn "NVIDIA GPU detected but nvidia-smi/ubuntu-drivers unavailable — install driver manually"
        fi
    fi
    tick "NVIDIA driver setup (reboot required)"
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

    if ! is_fedora; then
        PRIME_STATUS=$(prime-select query 2>/dev/null || echo "unknown")
        if [[ "$PRIME_STATUS" == "on-demand" ]]; then
            ok "GPU on-demand mode — optimal for laptop"
        else
            warn "GPU mode: '${PRIME_STATUS}' — consider: sudo prime-select on-demand"
        fi
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
    tick "NVIDIA driver (${NVIDIA_VER}) + Vulkan + power rules"
fi

ok "Repositories & NVIDIA complete"
