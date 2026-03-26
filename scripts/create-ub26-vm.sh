#!/usr/bin/env bash
set -euo pipefail

# Create a fresh libvirt VM named ub26 with:
# - 4 vCPU
# - 8 GiB RAM
# - 35 GiB qcow2 disk
#
# Defaults:
#   VM_NAME=ub26
#   RAM_MB=8192
#   VCPUS=4
#   DISK_GB=35
#   DISK_PATH=/var/lib/libvirt/images/ub26.qcow2
#   ISO search path=~/Downloads
#
# Usage:
#   bash scripts/create-ub26-vm.sh
#   bash scripts/create-ub26-vm.sh --iso ~/Downloads/ubuntu-26.04-desktop-amd64.iso
#   bash scripts/create-ub26-vm.sh --name ub26 --memory 8192 --vcpus 4 --disk-gb 35
#   bash scripts/create-ub26-vm.sh --dry-run

VM_NAME="ub26"
RAM_MB="8192"
VCPUS="4"
DISK_GB="35"
DISK_PATH=""
ISO_PATH=""
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: create-ub26-vm.sh [options]

Options:
  --name NAME         VM name (default: ub26)
  --memory MB         Memory in MiB (default: 8192)
  --vcpus N           Number of virtual CPUs (default: 4)
  --disk-gb N         Disk size in GiB (default: 35)
  --disk-path PATH    Disk path (default: /var/lib/libvirt/images/<name>.qcow2)
  --iso PATH          ISO file path (default: auto-detect in ~/Downloads)
  --dry-run           Print commands without executing
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) VM_NAME="${2:?}"; shift 2 ;;
    --memory) RAM_MB="${2:?}"; shift 2 ;;
    --vcpus) VCPUS="${2:?}"; shift 2 ;;
    --disk-gb) DISK_GB="${2:?}"; shift 2 ;;
    --disk-path) DISK_PATH="${2:?}"; shift 2 ;;
    --iso) ISO_PATH="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$DISK_PATH" ]]; then
  DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
fi

run() {
  if $DRY_RUN; then
    printf '[dry-run] %q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd virsh
need_cmd virt-install
need_cmd qemu-img

find_iso() {
  local downloads="$HOME/Downloads"
  [[ -d "$downloads" ]] || return 1

  local candidates=()
  shopt -s nullglob
  for f in "$downloads"/*.iso "$downloads"/*.ISO; do
    local bn
    bn="$(basename "$f" | tr '[:upper:]' '[:lower:]')"
    if [[ "$bn" == *ubuntu* && "$bn" == *26* ]]; then
      candidates+=("$f")
    fi
  done
  shopt -u nullglob

  [[ ${#candidates[@]} -gt 0 ]] || return 1

  local newest
  newest="$(ls -1t "${candidates[@]}" | head -n1)"
  printf '%s\n' "$newest"
}

if [[ -z "$ISO_PATH" ]]; then
  if ! ISO_PATH="$(find_iso)"; then
    echo "Could not auto-detect Ubuntu 26 ISO in ~/Downloads." >&2
    echo "Pass --iso /path/to/ubuntu-26*.iso" >&2
    exit 1
  fi
fi

if [[ ! -f "$ISO_PATH" ]]; then
  echo "ISO not found: $ISO_PATH" >&2
  exit 1
fi

echo "VM name    : $VM_NAME"
echo "vCPUs      : $VCPUS"
echo "RAM (MiB)  : $RAM_MB"
echo "Disk (GiB) : $DISK_GB"
echo "Disk path  : $DISK_PATH"
echo "ISO        : $ISO_PATH"
echo ""

echo "Checking libvirt system connection..."
run virsh -c qemu:///system list --all >/dev/null

if virsh -c qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "Existing VM '$VM_NAME' found. Removing it for a clean start..."
  run virsh -c qemu:///system destroy "$VM_NAME" >/dev/null 2>&1 || true
  run virsh -c qemu:///system undefine "$VM_NAME" --nvram || run virsh -c qemu:///system undefine "$VM_NAME"
fi

if [[ -e "$DISK_PATH" ]]; then
  echo "Removing existing disk: $DISK_PATH"
  run sudo rm -f "$DISK_PATH"
fi

echo "Creating disk..."
run sudo qemu-img create -f qcow2 "$DISK_PATH" "${DISK_GB}G"

echo "Detecting OS variant..."
OS_VARIANT="ubuntu24.04"
if command -v osinfo-query >/dev/null 2>&1; then
  if osinfo-query os --fields=short-id | rg -q '^ubuntu26\.04$'; then
    OS_VARIANT="ubuntu26.04"
  fi
fi
echo "OS variant : $OS_VARIANT"

echo "Creating VM with virt-install..."
run sudo virt-install \
  --connect qemu:///system \
  --name "$VM_NAME" \
  --memory "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu host \
  --disk "path=${DISK_PATH},format=qcow2,bus=virtio" \
  --cdrom "$ISO_PATH" \
  --os-variant "$OS_VARIANT" \
  --network network=default,model=virtio \
  --graphics spice \
  --video virtio \
  --boot uefi \
  --noautoconsole

echo ""
echo "VM '$VM_NAME' created."
echo "Next:"
echo "  1) Open virt-manager and complete Ubuntu install."
echo "  2) After first boot inside guest:"
echo "     sudo apt update && sudo apt -y upgrade"
echo "     sudo apt install -y qemu-guest-agent spice-vdagent"
echo "     sudo systemctl enable --now qemu-guest-agent"
echo "  3) Create clean snapshot:"
echo "     virsh -c qemu:///system snapshot-create-as $VM_NAME clean-base"
