# =============================================================================
# Module 10 — System Tweaks · Performance Tuning · Cleanup
# =============================================================================
init_sub 10

# ── Kernel parameters ────────────────────────────────────────────────────────
info "Applying kernel parameters..."
# Remove older config that may contain duplicate values
rm -f /etc/sysctl.d/99-desktop-tweaks.conf 2>/dev/null || true
cat > /etc/sysctl.d/99-workstation.conf << 'SYSCTL'
# Desktop responsiveness
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Network performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 5000

# IDE / dev tools (file watchers)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
fs.file-max = 2097152
SYSCTL
sysctl --system >> "$LOG_FILE" 2>&1 || warn "sysctl errors"
tick "Kernel parameters (swappiness=10, inotify, network)"

# ── Services ──────────────────────────────────────────────────────────────────
systemctl enable preload     >> "$LOG_FILE" 2>&1 && ok "preload enabled"     || true
systemctl enable fstrim.timer >> "$LOG_FILE" 2>&1 && ok "fstrim.timer enabled" || true
tick "Services: preload + fstrim"

# ── Boot speed: Disable slow & unnecessary services ──────────────────────────
info "Optimizing boot services..."
systemctl disable --now apport.service apport-autoreport.service >> "$LOG_FILE" 2>&1 || true
if [[ -f /etc/default/apport ]]; then
    sed -i 's/enabled=1/enabled=0/' /etc/default/apport 2>/dev/null || true
fi
systemctl disable NetworkManager-wait-online.service >> "$LOG_FILE" 2>&1 || true
tick "Boot optimization (disabled apport & NM-wait-online)"

# ── Storage & Memory: noatime + ZRAM ──────────────────────────────────────────
info "Optimizing filesystem mount options (noatime)..."
if grep -q " / ext4 " /etc/fstab && ! grep -q " / ext4 [^ ]*noatime" /etc/fstab; then
    cp /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    sed -i 's|\(/ ext4 *defaults\)|\1,noatime|' /etc/fstab 2>/dev/null || true
    mount -o remount,noatime / >> "$LOG_FILE" 2>&1 || true
    systemctl daemon-reload >> "$LOG_FILE" 2>&1 || true
    ok "Added noatime to / in /etc/fstab"
fi

info "Configuring ZRAM compressed swap..."
if is_fedora; then
    dnf_each zram-generator
else
    apt_each zram-tools
    if [[ -f /etc/default/zramswap ]]; then
        sed -i 's/^#*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
        sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
        sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
        systemctl restart zramswap.service >> "$LOG_FILE" 2>&1 || true
    fi
fi
tick "Storage & RAM: noatime + zram (zstd, prio 100)"

# ── Battery Health: ASUS charge threshold (80%) ──────────────────────────────
if [[ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]]; then
    info "Configuring ASUS battery charge threshold (80%)..."
    echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || true
    cat > /etc/systemd/system/battery-charge-threshold.service << 'BAT_EOF'
[Unit]
Description=Set ASUS battery charge threshold to 80%
After=multi-user.target suspend.target hibernate.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'if [ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]; then echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold; fi'

[Install]
WantedBy=multi-user.target suspend.target hibernate.target
BAT_EOF
    cat > /etc/udev/rules.d/99-battery-charge-threshold.rules << 'UDEV_EOF'
SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="80"
UDEV_EOF
    systemctl daemon-reload >> "$LOG_FILE" 2>&1 || true
    systemctl enable --now battery-charge-threshold.service >> "$LOG_FILE" 2>&1 || true
    ok "ASUS battery threshold set to 80%"
    tick "Battery protection (80% charge threshold)"
fi

# ── Network: Wi-Fi power saving disable (low latency) ────────────────────────
if [[ -f /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf ]]; then
    sed -i 's/wifi.powersave = 3/wifi.powersave = 2/' /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf 2>/dev/null || true
    systemctl reload NetworkManager >> "$LOG_FILE" 2>&1 || true
    ok "Wi-Fi powersave disabled (wifi.powersave = 2)"
    tick "Wi-Fi power saving disabled for lower latency"
fi

# ── Hardware sensors ─────────────────────────────────────────────────────────
sensors-detect --auto >> "$LOG_FILE" 2>&1 || true
tick "Hardware sensors detected"

# ── Firewall ──────────────────────────────────────────────────────────────────
if is_fedora; then
    # Fedora uses firewalld
    if systemctl is-active --quiet firewalld; then
        ok "firewalld already active"
    else
        systemctl enable --now firewalld >> "$LOG_FILE" 2>&1 || true
    fi
    firewall-cmd --permanent --add-service=ssh >> "$LOG_FILE" 2>&1 || true
    firewall-cmd --reload >> "$LOG_FILE" 2>&1 || true
    tick "firewalld (SSH allowed)"
else
    # Ubuntu uses UFW
    if command -v ufw &>/dev/null; then
        if ! ufw status | grep -q "Status: active"; then
            info "Configuring UFW firewall..."
            ufw default deny incoming >> "$LOG_FILE" 2>&1
            ufw default allow outgoing >> "$LOG_FILE" 2>&1
            ufw allow ssh >> "$LOG_FILE" 2>&1
            ufw --force enable >> "$LOG_FILE" 2>&1 \
                && ok "UFW enabled (deny incoming, allow SSH)" \
                || warn "UFW enable failed"
        else
            ok "UFW already active"
        fi
    else
        apt_each ufw
        if command -v ufw &>/dev/null; then
            ufw default deny incoming >> "$LOG_FILE" 2>&1
            ufw default allow outgoing >> "$LOG_FILE" 2>&1
            ufw allow ssh >> "$LOG_FILE" 2>&1
            ufw --force enable >> "$LOG_FILE" 2>&1 || true
        fi
    fi
    tick "UFW firewall"
fi

# ── Display setup helper ─────────────────────────────────────────────────────
cat > /usr/local/bin/display-setup << 'DISP'
#!/usr/bin/env bash
_is_wayland() { [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; }

case "${1:-info}" in
    gamma)
        if _is_wayland; then
            echo "Gamma adjustment is not supported on Wayland sessions."
            echo "Use GNOME Night Light instead: gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature <value>"
        else
            xgamma -gamma "${2:-1.0}"
        fi
        ;;
    brightness)
        if _is_wayland; then
            gdbus call --session --dest org.gnome.SettingsDaemon.Power \
                --object-path /org/gnome/SettingsDaemon/Power \
                --method org.freedesktop.DBus.Properties.Set \
                org.gnome.SettingsDaemon.Power.Screen Brightness \
                "<int32 $(awk "BEGIN{printf \"%d\", ${2:-100} * 100}")>" 2>/dev/null \
                || echo "Could not set brightness via GNOME. Try: xdg-open gnome-control-center://power"
        else
            xrandr --output "$(xrandr | grep ' connected' | awk '{print $1}' | head -1)" --brightness "${2:-1.0}"
        fi
        ;;
    reset)
        if _is_wayland; then
            echo "Reset is not needed on Wayland — use GNOME settings."
        else
            xgamma -gamma 1.0
        fi
        ;;
    info)
        echo "Session type: ${XDG_SESSION_TYPE:-unknown}"
        echo "Displays:"
        if _is_wayland; then
            gnome-randr show-current 2>/dev/null || xrandr 2>/dev/null | grep ' connected' || echo "  Could not enumerate displays"
        else
            xrandr | grep ' connected'
        fi
        echo
        echo "GPU:"
        nvidia-smi -L 2>/dev/null || lspci | grep -i 'vga\|3d' 2>/dev/null || echo "N/A"
        ;;
    *)  echo "Usage: display-setup [gamma <val>] [brightness <0-1>] [reset] [info]" ;;
esac
DISP
chmod +x /usr/local/bin/display-setup

# ── System info script ───────────────────────────────────────────────────────
cat > /usr/local/bin/sysreport << 'SYSREPORT'
#!/usr/bin/env bash
BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; RESET='\033[0m'
echo -e "${BOLD}${CYAN}System Report${RESET}"
echo -e "${BOLD}─────────────────────────────────────────${RESET}"
echo -e "${GREEN}OS:${RESET}       $(lsb_release -ds 2>/dev/null || grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '\"')"
echo -e "${GREEN}Kernel:${RESET}   $(uname -r)"
echo -e "${GREEN}Shell:${RESET}    $SHELL"
echo -e "${GREEN}User:${RESET}     $(whoami)@$(hostname)"
echo -e "${GREEN}Uptime:${RESET}   $(uptime -p)"
echo -e "${GREEN}Memory:${RESET}   $(free -h | awk '/Mem:/{print $3 "/" $2}')"
echo -e "${GREEN}Disk:${RESET}     $(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 " used)"}')"
command -v nvidia-smi &>/dev/null && echo -e "${GREEN}GPU:${RESET}      $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'N/A')"
echo -e "${GREEN}Podman:${RESET}   $(podman --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Node:${RESET}     $(node --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Python:${RESET}   $(python3 --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Go:${RESET}       $(go version 2>/dev/null | awk '{print $3}' || echo 'not installed')"
echo -e "${GREEN}Rust:${RESET}     $(rustc --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Fonts:${RESET}    $(fc-list 2>/dev/null | wc -l) installed"
SYSREPORT
chmod +x /usr/local/bin/sysreport
tick "Helper scripts (display-setup, sysreport)"

# ── Cleanup ───────────────────────────────────────────────────────────────────
info "Running cleanup..."
if is_fedora; then
    dnf_quiet autoremove
    dnf_quiet clean all
else
    apt_quiet autoremove
    apt_quiet autoclean
    apt_quiet clean
    snap set system refresh.retain=2 >> "$LOG_FILE" 2>&1 || true
    # Remove orphan snaps
    snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read snapname revision; do
        snap remove "$snapname" --revision="$revision" >> "$LOG_FILE" 2>&1 || true
    done
fi
# Clean old journal logs (keep 7 days)
journalctl --vacuum-time=7d >> "$LOG_FILE" 2>&1 || true
tick "Package cleanup + journal vacuum"

ok "System tweaks & cleanup complete"
