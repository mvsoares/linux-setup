#!/usr/bin/env bash
set -euo pipefail

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (e.g. sudo bash $0)" >&2
    exit 1
fi

echo "==> Configuring SDDM to prioritize external displays (Dell) at login..."

# 1. Create /etc/sddm directory if it doesn't exist
mkdir -p /etc/sddm /etc/sddm.conf.d

# 2. Write /etc/sddm/Xsetup
cat << 'EOF' > /etc/sddm/Xsetup
#!/bin/sh
# /etc/sddm/Xsetup - Run before SDDM greeter appears

# NVIDIA Prime offload if available
if [ -e /sbin/prime-offload ]; then
    /sbin/prime-offload
fi

# Connect secondary DRM providers (e.g. DisplayLink/EVDI) to primary provider
for p in $(xrandr --listproviders 2>/dev/null | grep -E "Provider [1-9]" | awk '{print $2}' | tr -d ':'); do
    xrandr --setprovideroutputsource "$p" 0 2>/dev/null || true
done

# Detect external connected monitor (e.g. Dell on DVI-I-1, DP, or HDMI)
EXT_OUTPUT=""
for status_file in /sys/class/drm/card*-*/status; do
    port=$(basename "$(dirname "$status_file")" | sed -E "s/^card[0-9]+-//")
    if [ "$port" != "eDP-1" ] && [ "$(cat "$status_file" 2>/dev/null)" = "connected" ]; then
        EXT_OUTPUT="$port"
        break
    fi
done

# Configure displays
if [ -n "$EXT_OUTPUT" ]; then
    # External display connected: make it primary and disable internal laptop panel
    xrandr --output "$EXT_OUTPUT" --primary --auto 2>/dev/null || true
    xrandr --output eDP-1 --off 2>/dev/null || true
else
    # Standalone laptop: enable internal display as primary
    xrandr --output eDP-1 --primary --auto 2>/dev/null || true
fi
EOF

chmod +x /etc/sddm/Xsetup

# 3. Write /etc/sddm.conf.d/10-display.conf
cat << 'EOF' > /etc/sddm.conf.d/10-display.conf
[X11]
DisplayCommand=/etc/sddm/Xsetup
EOF

echo "✔ Successfully configured SDDM DisplayCommand in /etc/sddm/Xsetup and /etc/sddm.conf.d/10-display.conf"
echo "  - When external display (Dell) is connected: Login appears on Dell; internal display is turned off."
echo "  - When unplugged: Login appears automatically on internal laptop display."
