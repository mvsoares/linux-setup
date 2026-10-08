#!/usr/bin/env bash
# =============================================================================
# 02-gcp-firewall.sh — VPC firewall rules so IAP tunnels can reach Selkies
#
# Run on your LOCAL machine (needs gcloud authenticated against the project).
# The GCP-level firewall is a separate layer from the VM's own ufw rules
# (handled by 01-install-selkies.sh) — both must allow the ports, or IAP's
# tunnel fails with "failed to connect to backend".
#
# Usage: ./02-gcp-firewall.sh <project> <network> [iap-range]
# =============================================================================
set -euo pipefail

PROJECT="${1:?Usage: $0 <project> <network> [iap-range]}"
NETWORK="${2:?Usage: $0 <project> <network> [iap-range]}"
IAP_RANGE="${3:-35.235.240.0/20}"

ok()   { echo -e "  \033[0;32m✔\033[0m  $*"; }
info() { echo -e "  \033[0;36m→\033[0m  $*"; }

ensure_rule() {
    local name="$1" port="$2"
    if gcloud compute firewall-rules describe "$name" --project="$PROJECT" &>/dev/null; then
        ok "${name} already exists"
        return
    fi
    info "Creating ${name} (tcp:${port} from ${IAP_RANGE})..."
    gcloud compute firewall-rules create "$name" \
        --project="$PROJECT" \
        --network="$NETWORK" \
        --direction=INGRESS \
        --action=ALLOW \
        --rules="tcp:${port}" \
        --source-ranges="$IAP_RANGE" \
        --description="Allow IAP range to reach Selkies (port ${port})"
    ok "${name} created"
}

ensure_rule allow-iap-selkies 8080
ensure_rule allow-iap-turn 3478
