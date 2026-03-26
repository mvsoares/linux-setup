#!/usr/bin/env bash
# =============================================================================
#  Ansible Workstation Setup Wrapper
#  - Installs Ansible if missing
#  - Executes the Workstation Setup playbook
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
RESET='\033[0m'

info()  { echo -e "${CYAN}${BOLD}INFO${RESET}  $1"; }
ok()    { echo -e "${GREEN}${BOLD}OK${RESET}    $1"; }
warn()  { echo -e "${YELLOW}${BOLD}WARN${RESET}  $1"; }
error() { echo -e "${RED}${BOLD}ERROR${RESET} $1"; exit 1; }

# ── Ensure Root ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (or with sudo)"
fi

# ── Detect OS & Install Ansible ───────────────────────────────────────────────
if ! command -v ansible-playbook &>/dev/null; then
    info "Ansible not found. Installing..."
    if [[ -f /etc/fedora-release ]]; then
        dnf install -y ansible
    elif [[ -f /etc/debian_version ]]; then
        apt-get update
        apt-get install -y ansible
    else
        error "Unsupported OS. Only Fedora and Ubuntu/Debian are supported."
    fi
    ok "Ansible installed successfully."
fi

# ── Execution ─────────────────────────────────────────────────────────────────
info "Starting Workstation Setup via Ansible..."

# Use local inventory if none provided
# To run against the new VM: sudo ./ansible-run.sh -i <vm_ip>,
ANSIBLE_CONFIG="ansible/ansible.cfg" ansible-playbook \
    -i ansible/inventory/hosts.yml \
    ansible/main.yml \
    "$@"

ok "Ansible run finished."
