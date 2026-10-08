#!/usr/bin/env bash
# Fix the anomalies found in a workstation health check on 2026-10-08.
#
#   1. Wi-Fi stays connected while wired   -> turn Wi-Fi off while Ethernet is up
#   2. Root filesystem 88% full            -> clear caches, Trash, unused images
#   3. zram not running                    -> install and enable zram-tools
#   4. ufw logging ~5700 blocks per boot   -> drop LAN discovery chatter silently
#   5. mako / waybar fail on every login   -> skip them under GNOME
#   6. racc-attest failed at boot          -> retry instead of dying at boot
#
# jetski-hub was also failing, but not for a timing reason: its binary on
# /google/bin ships without an execute bit, so no unit setting can fix it.
#
# Idempotent. Run with sudo from a real terminal so the cleanup prompts can ask;
# without a terminal every destructive step is skipped. --yes answers all of
# them with yes.
#
#   sudo bash scripts/workstation-tune.sh [--yes]

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "error: run with sudo" >&2; exit 1; }
[[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] || { echo "error: run via sudo from your own account" >&2; exit 1; }

ASSUME_YES=false
[[ ${1:-} == --yes ]] && ASSUME_YES=true

USER_NAME=$SUDO_USER
USER_ID=$(id -u "$USER_NAME")
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# Run as the invoking user with their session bus, for systemctl --user,
# podman, and anything that writes into $HOME.
as_user() {
  runuser -u "$USER_NAME" -- env \
    HOME="$USER_HOME" \
    XDG_RUNTIME_DIR="/run/user/$USER_ID" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" \
    "$@"
}

confirm() {
  $ASSUME_YES && return 0
  local reply
  { read -r -p "$1 [y/N] " reply < /dev/tty; } 2>/dev/null || {
    warn "no terminal to ask on; skipped (rerun in a terminal, or with --yes)"
    return 1
  }
  [[ $reply == [yY]* ]]
}

size_of() { du -sh "$@" 2>/dev/null | awk '{print $1}' | paste -sd+ | sed 's/+/ + /g'; }

# ---------------------------------------------------------------------------
# 1. Turn Wi-Fi off while a wired link is up.
#    Both were connected to the same LAN (192.168.1.175 Wi-Fi, .184 wired), so
#    Wi-Fi added nothing but 59 missed-beacon warnings per boot, doubled
#    broadcast traffic, and extra contention on the AX201's shared
#    Wi-Fi/Bluetooth radio -- the same 2.4 GHz band as the headset dongles and
#    the MX Vertical.
# ---------------------------------------------------------------------------
cat > /etc/NetworkManager/dispatcher.d/70-wifi-off-when-wired << 'DISPATCH'
#!/bin/sh
# Wi-Fi off while any Ethernet link is connected, back on when the last drops.
# Installed by linux-setup/scripts/workstation-tune.sh.
#
# Only Ethernet events count (or a device that has already vanished, which is
# how an undock shows up). Wi-Fi's own up/down is ignored, so turning Wi-Fi off
# by hand with no cable plugged in is never overridden.
case "$2" in up|down) ;; *) exit 0 ;; esac

type=$(nmcli -g GENERAL.TYPE device show "$1" 2>/dev/null)
case "$type" in ethernet|"") ;; *) exit 0 ;; esac

if nmcli -t -f TYPE,STATE device | grep -q '^ethernet:connected'; then
  nmcli radio wifi off
else
  nmcli radio wifi on
fi
DISPATCH
chmod 755 /etc/NetworkManager/dispatcher.d/70-wifi-off-when-wired
say "wifi: installed NetworkManager dispatcher"

if nmcli -t -f TYPE,STATE device | grep '^ethernet:connected' >/dev/null; then
  nmcli radio wifi off
  say "wifi: wired link is up, Wi-Fi turned off now"
fi

# ---------------------------------------------------------------------------
# 2. Free disk space. Root was 88% full with 24G left on a 256G NVMe.
#    Package caches and the uv prune are always safe; everything that deletes
#    something you might still want asks first. The journal is left alone: it
#    is already capped at 1G by fix-iowait-cleanup.sh.
# ---------------------------------------------------------------------------
before=$(df --output=avail -h / | tail -1 | tr -d ' ')

apt-get clean
say "disk: apt cache cleaned"

if [[ -x $USER_HOME/.local/bin/uv ]]; then
  as_user "$USER_HOME/.local/bin/uv" cache prune >/dev/null 2>&1 &&
    say "disk: uv cache pruned (unused entries only)"
fi

trash=$USER_HOME/.local/share/Trash
if [[ -d $trash/files ]] && [[ -n $(ls -A "$trash/files" 2>/dev/null) ]]; then
  n=$(find "$trash/files" -mindepth 1 -maxdepth 1 | wc -l)
  if confirm "disk: empty Trash ($n items, $(size_of "$trash"))?"; then
    find "$trash/files" "$trash/info" -mindepth 1 -delete 2>/dev/null || true
    say "disk: Trash emptied"
  fi
fi

if [[ -d $USER_HOME/.npm/_cacache ]]; then
  if confirm "disk: clear npm download cache ($(size_of "$USER_HOME/.npm/_cacache"), re-downloads on demand)?"; then
    rm -rf "$USER_HOME/.npm/_cacache"
    say "disk: npm cache cleared"
  fi
fi

# Playwright keeps every browser revision it ever downloaded. Keep only the
# newest revision of each browser.
pw=$USER_HOME/.cache/ms-playwright
if [[ -d $pw ]]; then
  stale=()
  for name in $(ls "$pw" | sed -nE 's/^(.+)-[0-9]+$/\1/p' | sort -u); do
    mapfile -t revs < <(ls -d "$pw/$name"-[0-9]* 2>/dev/null | sort -V)
    (( ${#revs[@]} > 1 )) && stale+=("${revs[@]:0:${#revs[@]}-1}")
  done
  if (( ${#stale[@]} )); then
    printf '     %s\n' "${stale[@]##*/}"
    if confirm "disk: remove these old Playwright browsers ($(size_of "${stale[@]}"))?"; then
      rm -rf "${stale[@]}"
      say "disk: old Playwright browsers removed"
    fi
  fi
fi

if command -v podman >/dev/null; then
  reclaim=$(as_user podman system df --format '{{.Type}} {{.Reclaimable}}' 2>/dev/null |
    awk '$1 == "Images" { $1 = ""; print substr($0, 2) }')
  if [[ -n $reclaim && $reclaim != 0B* ]]; then
    if confirm "disk: remove podman images not used by any container ($reclaim)?"; then
      as_user podman image prune --all --force >/dev/null
      say "disk: unused podman images removed"
    fi
  fi
fi

say "disk: free space on / went from $before to $(df --output=avail -h / | tail -1 | tr -d ' ')"

# ---------------------------------------------------------------------------
# 3. zram. modules/10-tweaks.sh sets this up, but zram-tools was never
#    installed on this machine, so swapping went straight to the disk partition
#    (5.7G in use). Same settings as the module: zstd, half of RAM, priority
#    100 so it fills before the disk swap (priority -1), which stays as overflow.
# ---------------------------------------------------------------------------
if ! dpkg -s zram-tools >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools >/dev/null
  say "zram: installed zram-tools"
fi

set_kv() {
  local file=$1 key=$2 value=$3
  if grep -qE "^#?\s*$key=" "$file"; then
    sed -i -E "s|^#?\s*$key=.*|$key=$value|" "$file"
  else
    echo "$key=$value" >> "$file"
  fi
}
touch /etc/default/zramswap
set_kv /etc/default/zramswap ALGO zstd
set_kv /etc/default/zramswap PERCENT 50
set_kv /etc/default/zramswap PRIORITY 100

# Installing the package starts zramswap with its default lz4 before the config
# above exists, and the kernel refuses to change the algorithm of an initialized
# device ("write error: Device or resource busy"). Tear the device down first.
algo=$(sed -nE 's/.*\[([a-z0-9-]+)\].*/\1/p' /sys/block/zram0/comp_algorithm 2>/dev/null || true)
if [[ -n $algo && $algo != zstd ]]; then
  systemctl stop zramswap.service 2>/dev/null || true
  swapoff /dev/zram0 2>/dev/null || true
  echo 1 > /sys/block/zram0/reset
  say "zram: reset zram0 (was $algo)"
fi

systemctl enable zramswap.service >/dev/null 2>&1 || true
if systemctl restart zramswap.service; then
  say "zram: $(zramctl --noheadings --output NAME,DISKSIZE,ALGORITHM 2>/dev/null | head -1 | xargs)"
else
  warn "zram: zramswap failed to start; see journalctl -u zramswap"
fi

# ---------------------------------------------------------------------------
# 4. Stop ufw logging LAN discovery chatter. Blocks this boot, by port:
#       20002/udp  ~1230   IoT device discovery broadcast
#       67/udp     ~590    other hosts' DHCP requests (this machine is a client
#                          and receives on 68, so 67 inbound is never wanted)
#       15600/udp  ~380    IoT device discovery broadcast
#    /etc/ufw/before.rules is a Puppet-managed corp template, so it is not
#    touched. These are ordinary ufw deny rules instead: stricter than the
#    default rather than looser, kept in ufw's own rule store, and dropped
#    before the logging chain so they stop appearing in dmesg.
# ---------------------------------------------------------------------------
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep '^Status: active' >/dev/null; then
  for port in 20002 15600 67; do
    ufw deny in proto udp to any port "$port" comment 'linux-setup: quiet LAN chatter' >/dev/null
  done
  say "ufw: silently dropping udp 20002, 15600, 67"
else
  warn "ufw: not active, skipping"
fi

# ---------------------------------------------------------------------------
# 5. mako and waybar are Sway components, enabled by package preset for every
#    graphical session. Under GNOME, mako can't take the notification bus
#    (gnome-shell owns it) and waybar needs wlr-layer-shell, which GNOME
#    doesn't provide, so both fail on every login. Skip them under GNOME only,
#    so they still work if a Sway session is ever used.
# ---------------------------------------------------------------------------
for unit in mako waybar; do
  dir=$USER_HOME/.config/systemd/user/$unit.service.d
  as_user mkdir -p "$dir"
  as_user tee "$dir/50-not-under-gnome.conf" >/dev/null << 'DROPIN'
# Installed by linux-setup/scripts/workstation-tune.sh. A failing ExecCondition
# makes systemd skip the unit cleanly instead of marking it failed.
[Service]
ExecCondition=
ExecCondition=/bin/sh -c '[ -n "$WAYLAND_DISPLAY" ] && case ":$XDG_CURRENT_DESKTOP:" in *:GNOME:*) exit 1 ;; esac'
DROPIN
done

# ---------------------------------------------------------------------------
# 6. racc-attest (corp platform attestation) starts about a second before the
#     local resolver on 127.0.0.1 answers, fails with "name resolver error:
#     produced zero addresses", and has Restart=no, so it stays failed until
#     the daily timer. It succeeded on 10-06 when it lost that race. Retry it
#     instead. The unit itself is left as shipped; this is a drop-in.
# ---------------------------------------------------------------------------
mkdir -p /etc/systemd/system/racc-attest.service.d
cat > /etc/systemd/system/racc-attest.service.d/50-retry.conf << 'DROPIN'
# Installed by linux-setup/scripts/workstation-tune.sh: retry while DNS comes up
# at boot instead of failing once and waiting a day for the timer.
[Unit]
StartLimitIntervalSec=30min
StartLimitBurst=10

[Service]
Restart=on-failure
RestartSec=60s
DROPIN
systemctl daemon-reload
systemctl reset-failed racc-attest.service 2>/dev/null || true
systemctl start --no-block racc-attest.service
say "racc-attest: retries on failure; attestation started now"

as_user systemctl --user daemon-reload
as_user systemctl --user reset-failed mako.service waybar.service 2>/dev/null || true
say "user units: mako/waybar skip under GNOME, failed state cleared"

echo
say "done. Failed units now:"
systemctl --failed --no-legend | sed 's/^/     /'
as_user systemctl --user --failed --no-legend | sed 's/^/     /' || true
