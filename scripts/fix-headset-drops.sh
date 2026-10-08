#!/usr/bin/env bash
# Instrumentation and cleanup around USB headset dongles dropping audio for ~1s.
#
# HISTORY: the Poly BT700 (047f) that caused this was retired on 2026-09-16 and
# replaced by a Jabra Link 380 (0b0e:24c7) on a laptop USB-A port. The BT700
# published two different descriptor sets:
#
#     047f:02e9   headset NOT linked   HID only, on interface 0
#     047f:02e6   headset linked       HID on interface 3 + 3 audio interfaces
#
# The audio interfaces only existed in the linked set, so every change in the
# 2.4 GHz link state forced a USB re-enumeration. PipeWire tore down and rebuilt
# the ALSA card and audio cut for about a second.
#
# The Link 380 shares the same layout -- a CSR internal hub (0a12:4010) with the
# audio/HID function fixed behind it at 12 Mbps -- but exposes bNumConfigurations=1
# and a single permanent interface set (3 audio + 1 HID). The card therefore
# cannot vanish because the headset linked or unlinked, which removes the cause
# of the dropouts rather than just moving it. It also sits directly on the root
# hub now, off the Wavlink/DisplayLink USB 3.0 stream that was the RF aggravator.
#
# This script does not fix drops. It reduces one plausible RF aggravator and
# installs the counter that measures whether any re-enumeration still happens.
# Quieting ufw's dmesg logging moved to workstation-tune.sh, which uses ufw deny
# rules instead of patching the Puppet-managed /etc/ufw/before.rules.
#
# Idempotent. Run with sudo.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "error: run with sudo" >&2; exit 1; }

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. Stop NetworkManager hunting for a better AP every 5 minutes.
#    Every saved Wi-Fi profile is autoconnect=yes and several outrank the one
#    in use, so NM keeps rescanning (capped at 300s, matching the observed
#    cadence). Each scan sweeps 2.4 GHz, and the AX201 combo radio arbitrates
#    Wi-Fi against Bluetooth. Secondary to the DisplayLink USB 3.0 noise, but
#    harmless to remove.
# ---------------------------------------------------------------------------
profile=${1:-$(nmcli -t -f NAME,TYPE con show --active 2>/dev/null |
  awk -F: '$2 == "802-11-wireless" { print $1; exit }')}

if [[ -n ${profile:-} ]]; then
  highest=$(nmcli -t -f AUTOCONNECT-PRIORITY con show 2>/dev/null | sort -n | tail -1)
  target=$(( ${highest:-0} + 10 ))
  nmcli con mod "$profile" connection.autoconnect-priority "$target"
  say "wifi: '$profile' autoconnect-priority -> $target"
else
  warn "wifi: no active Wi-Fi profile; pass one as \$1 to set its priority"
fi

# ---------------------------------------------------------------------------
# 2. Count re-enumerations so any remaining dropout is measurable.
#    With the Link 380 there should be none: it never swaps descriptor sets, so
#    an add/remove pair here means a real USB event, not a link state change.
#    Records the Wi-Fi link quality at that instant too, read straight from
#    /proc/net/wireless so it stays fast enough for a udev RUN.
# ---------------------------------------------------------------------------
cat > /usr/local/bin/headset-watch << 'WATCH'
#!/usr/bin/env bash
action=${1:-?}
kernel=${2:-?}
model=${3:-?}

read -r _ _ link level _ < <(awk 'NR==3 {print}' /proc/net/wireless 2>/dev/null)

printf '%s headset %-6s dev=%-12s id=%-9s wifi_link=%-6s wifi_level=%s\n' \
  "$(date -Is)" "$action" "$kernel" "$model" "${link:-n/a}" "${level:-n/a}" \
  >> /var/log/headset-drops.log

logger -t headset-watch "$action $kernel id=$model wifi_link=${link:-n/a} wifi_level=${level:-n/a}"
WATCH
chmod 755 /usr/local/bin/headset-watch
touch /var/log/headset-drops.log
say "watchdog: installed /usr/local/bin/headset-watch"

cat > /etc/udev/rules.d/99-headset-watch.rules << 'UDEV'
# Log headset dongle re-enumerations into /var/log/headset-drops.log.
# 0b0e:24c7 is the Jabra Link 380 currently in use; 047f:02e6/02e9 are the
# retired Poly BT700's two descriptor sets, kept so the log stays comparable if
# that dongle is ever plugged back in.
SUBSYSTEM=="usb", ATTR{idVendor}=="0b0e", ATTR{idProduct}=="24c7", ACTION=="add", RUN+="/usr/local/bin/headset-watch add %k 24c7"
SUBSYSTEM=="usb", ENV{PRODUCT}=="b0e/24c7/*", ACTION=="remove", RUN+="/usr/local/bin/headset-watch remove %k 24c7"
SUBSYSTEM=="usb", ATTR{idVendor}=="047f", ATTR{idProduct}=="02e6", ACTION=="add", RUN+="/usr/local/bin/headset-watch add %k 02e6"
SUBSYSTEM=="usb", ATTR{idVendor}=="047f", ATTR{idProduct}=="02e9", ACTION=="add", RUN+="/usr/local/bin/headset-watch add %k 02e9"
SUBSYSTEM=="usb", ENV{PRODUCT}=="47f/2e6/*", ACTION=="remove", RUN+="/usr/local/bin/headset-watch remove %k 02e6"
SUBSYSTEM=="usb", ENV{PRODUCT}=="47f/2e9/*", ACTION=="remove", RUN+="/usr/local/bin/headset-watch remove %k 02e9"
UDEV
udevadm control --reload-rules
say "watchdog: installed udev rule"

cat << 'DONE'

Done. Watch for re-enumerations; with the Link 380 this should stay empty:

    tail -f /var/log/headset-drops.log
    grep -c ' add ' /var/log/headset-drops.log

Any line that shows up is a real USB event, so note the wifi_link value next to
it -- that is the one remaining lead if drops ever come back.
DONE
