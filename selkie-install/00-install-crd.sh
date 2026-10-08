#!/usr/bin/env bash
# =============================================================================
# 00-install-crd.sh — Ubuntu Desktop + Chrome Remote Desktop (headless host)
#
# Run ON the target VM as a regular user with sudo rights:
#   sudo bash 00-install-crd.sh
#
# Chrome Remote Desktop provides the virtual X display (:20) that Selkies
# (01-install-selkies.sh) attaches to and streams over WebRTC. Both remote
# desktop paths end up showing the same session.
# =============================================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash $0"; exit 1; }

ok()   { echo -e "  \033[0;32m✔\033[0m  $*"; }
info() { echo -e "  \033[0;36m→\033[0m  $*"; }

export DEBIAN_FRONTEND=noninteractive

if dpkg -s ubuntu-desktop &>/dev/null; then
    ok "ubuntu-desktop already installed"
else
    info "Installing Ubuntu Desktop (this takes a few minutes)..."
    apt-get update -y -q
    apt-get install -y -q ubuntu-desktop
    ok "ubuntu-desktop installed"
fi

if dpkg -s chrome-remote-desktop &>/dev/null; then
    ok "chrome-remote-desktop already installed"
else
    info "Downloading Chrome Remote Desktop..."
    _tmp=$(mktemp -d)
    trap 'rm -rf "${_tmp}"' EXIT
    wget -q https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb -O "${_tmp}/crd.deb"
    info "Installing Chrome Remote Desktop..."
    apt-get install -y -q "${_tmp}/crd.deb"
    apt-get install -f -y -q
    ok "chrome-remote-desktop installed"
fi

echo ""
echo "┌─ Next: link this host to your Google account ─────────────────────────┐"
echo "│  1. On your LOCAL browser: https://remotedesktop.google.com/headless  │"
echo "│  2. Begin -> Next -> Authorize, then copy the 'Debian Linux' command   │"
echo "│  3. Paste and run that command in THIS terminal                       │"
echo "│  4. Set a 6-digit PIN when prompted, then: sudo reboot                │"
echo "│  5. After reboot, run: sudo bash 01-install-selkies.sh                │"
echo "└─────────────────────────────────────────────────────────────────────┘"
