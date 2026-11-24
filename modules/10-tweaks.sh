# =============================================================================
# Module 10 — System Tweaks · Performance Tuning · Cleanup
# =============================================================================
init_sub 9

# ── Kernel parameters (ZRAM-optimized) ───────────────────────────────────────
info "Applying kernel parameters (ZRAM-optimized)..."
rm -f /etc/sysctl.d/99-desktop-tweaks.conf 2>/dev/null || true
cat > /etc/sysctl.d/99-workstation.conf << 'SYSCTL'
# Memory & ZRAM tuning (compressed RAM swap benefits from higher swappiness & zero readahead)
vm.swappiness = 100
vm.page-cluster = 0
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
tick "Kernel parameters (ZRAM swappiness=100, inotify, network)"

# ── Services ──────────────────────────────────────────────────────────────────
systemctl enable fstrim.timer >> "$LOG_FILE" 2>&1 && ok "fstrim.timer enabled" || true
tick "Services: fstrim.timer"

# ── Boot speed: Disable slow & unnecessary services ──────────────────────────
info "Optimizing boot services..."
systemctl disable --now apport.service apport-autoreport.service >> "$LOG_FILE" 2>&1 || true
if [[ -f /etc/default/apport ]]; then
    sed -i 's/enabled=1/enabled=0/' /etc/default/apport 2>/dev/null || true
fi
systemctl disable NetworkManager-wait-online.service >> "$LOG_FILE" 2>&1 || true
tick "Boot optimization (disabled apport & NM-wait-online)"

# ── Storage & Memory: ZRAM + fstab ────────────────────────────────────────────
if grep -qE '[[:space:]]/[[:space:]]+ext4[[:space:]]' /etc/fstab && ! grep -qE '[[:space:]]/[[:space:]]+ext4[[:space:]][^[:space:]]*noatime' /etc/fstab; then
    cp /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    sed -i -E 's|([[:space:]]/[[:space:]]+ext4[[:space:]]+[^[:space:]]+)|\1,noatime|' /etc/fstab 2>/dev/null || true
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
tick "Storage & RAM: ZRAM (zstd, prio 100)"

# ── Hardware-specific & peripheral tuning ────────────────────────────────────
# Battery Health: ASUS/laptop charge threshold (80%)
if [[ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]]; then
    info "Configuring battery charge threshold (80%)..."
    echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || true
    cat > /etc/systemd/system/battery-charge-threshold.service << 'BAT_EOF'
[Unit]
Description=Set battery charge threshold to 80%
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
    ok "Battery charge threshold set to 80%"
fi

# Wi-Fi power saving disable (lower latency)
if [[ -f /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf ]]; then
    sed -i 's/wifi.powersave = 3/wifi.powersave = 2/' /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf 2>/dev/null || true
    systemctl reload NetworkManager >> "$LOG_FILE" 2>&1 || true
    ok "Wi-Fi powersave disabled (wifi.powersave = 2)"
fi

# USB-C dock: keep Tiger Lake TB4 xHCI always on (no runtime PM)
if lspci -s 00:0d.0 2>/dev/null | grep -qi 'Thunderbolt.*USB Controller'; then
    if [[ -d /etc/tlp.d ]]; then
        cat > /etc/tlp.d/02-usbc-dock.conf << 'TLPDOCK_EOF'
# Never runtime-suspend the Thunderbolt USB controller the dock sits on.
RUNTIME_PM_DENYLIST="00:0d.0"
TLPDOCK_EOF
        tlp start >> "$LOG_FILE" 2>&1 || true
    else
        cat > /etc/udev/rules.d/60-usbc-dock-pm.rules << 'UDEVDOCK_EOF'
ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:0d.0", ATTR{power/control}="on"
UDEVDOCK_EOF
    fi
    echo on > /sys/bus/pci/devices/0000:00:0d.0/power/control 2>/dev/null || true
    ok "USB-C TB4 dock controller: runtime PM disabled"
fi

# NuPhy & QMK/VIA Keyboards: WebHID udev rules (0660 + uaccess for active desktop seat)
cat > /etc/udev/rules.d/50-nuphy.rules << 'NUPHY_EOF'
# NuPhy keyboards & dongles (QMK/VIA / WebHID)
KERNEL=="hidraw*", ATTRS{idVendor}=="19f5", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="19f5", MODE="0660", TAG+="uaccess"
NUPHY_EOF
udevadm control --reload-rules >> "$LOG_FILE" 2>&1 || true
udevadm trigger >> "$LOG_FILE" 2>&1 || true

# Hardware sensors
command -v sensors-detect &>/dev/null && sensors-detect --auto >> "$LOG_FILE" 2>&1 || true
tick "Hardware tuning (battery · Wi-Fi · dock · NuPhy udev · sensors)"

# ── Network: TCP BBR + fq, no slow-start after idle ──────────────────────────
if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null \
    || modprobe tcp_bbr >> "$LOG_FILE" 2>&1; then
    echo tcp_bbr > /etc/modules-load.d/tcp_bbr.conf
    cat > /etc/sysctl.d/99-network-tuning.conf << 'NET_EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
NET_EOF
    sysctl -p /etc/sysctl.d/99-network-tuning.conf >> "$LOG_FILE" 2>&1 || true
    ok "TCP BBR + fq enabled"
fi
tick "Network: TCP BBR + fq"

# ── Firewall ──────────────────────────────────────────────────────────────────
if is_fedora; then
    if systemctl is-active --quiet firewalld; then
        ok "firewalld already active"
    else
        systemctl enable --now firewalld >> "$LOG_FILE" 2>&1 || true
    fi
    firewall-cmd --permanent --add-service=ssh >> "$LOG_FILE" 2>&1 || true
    firewall-cmd --reload >> "$LOG_FILE" 2>&1 || true
    tick "firewalld (SSH allowed)"
else
    if ! command -v ufw &>/dev/null; then
        apt_each ufw
    fi
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
    fi

    # Quiet LAN broadcast chatter in dmesg (reduces ~2900 log lines per boot)
    if [[ -f /etc/ufw/before.rules ]] && ! grep -qF "quiet LAN broadcast chatter" /etc/ufw/before.rules; then
        sed -i '/:ufw-before-input - \[0:0\]/a # BEGIN linux-setup: quiet LAN broadcast chatter\n-A ufw-before-input -p udp --sport 67 --dport 68 -j ACCEPT\n-A ufw-before-input -m addrtype --dst-type BROADCAST -j DROP\n-A ufw-before-input -p udp --dport 3702 -j DROP\n# END linux-setup: quiet LAN broadcast chatter' /etc/ufw/before.rules 2>/dev/null || true
        command -v ufw &>/dev/null && ufw reload >> "$LOG_FILE" 2>&1 || true
        ok "UFW: suppressed noisy LAN broadcast chatter"
    fi
    if [[ -f /etc/ufw/before6.rules ]] && ! grep -qF "quiet LAN broadcast chatter" /etc/ufw/before6.rules; then
        sed -i '/:ufw6-before-input - \[0:0\]/a # BEGIN linux-setup: quiet LAN broadcast chatter\n-A ufw6-before-input -p udp --dport 3702 -j DROP\n# END linux-setup: quiet LAN broadcast chatter' /etc/ufw/before6.rules 2>/dev/null || true
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
                "<int32 $(awk "BEGIN{v=${2:-1.0}*100; if(v>100)v=100; if(v<0)v=0; printf \"%d\", v}")>" 2>/dev/null \
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
    *)  echo "Usage: display-setup [gamma <val>] [brightness <0.0-1.0>] [reset] [info]" ;;
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
echo -e "${GREEN}Kernel:${RESET}   $(uname -r) ($(uname -m))"
echo -e "${GREEN}Shell:${RESET}    $SHELL"
echo -e "${GREEN}User:${RESET}     $(whoami)@$(hostname)"
echo -e "${GREEN}Uptime:${RESET}   $(uptime -p)"
echo -e "${GREEN}Memory:${RESET}   $(free -h | awk '/Mem:/{print $3 "/" $2}')"
echo -e "${GREEN}Disk:${RESET}     $(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 " used)"}')"
command -v nvidia-smi &>/dev/null && echo -e "${GREEN}GPU:${RESET}      $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'N/A')"
echo -e "${GREEN}Podman:${RESET}   $(podman --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Node:${RESET}     $(node --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Python:${RESET}   $(python3 --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}uv:${RESET}       $(uv --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Go:${RESET}       $(go version 2>/dev/null | awk '{print $3}' || echo 'not installed')"
echo -e "${GREEN}Rust:${RESET}     $(rustc --version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Java:${RESET}     $(java -version 2>&1 | head -1 || echo 'not installed')"
echo -e "${GREEN}kubectl:${RESET}  $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1 || echo 'not installed')"
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
    if command -v snap &>/dev/null; then
        snap set system refresh.retain=2 >> "$LOG_FILE" 2>&1 || true
        snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r snapname revision; do
            snap remove "$snapname" --revision="$revision" >> "$LOG_FILE" 2>&1 || true
        done
    fi
fi
# Clean old journal logs (keep 7 days)
journalctl --vacuum-time=7d >> "$LOG_FILE" 2>&1 || true
tick "Package cleanup + journal vacuum"

ok "System tweaks & cleanup complete"
