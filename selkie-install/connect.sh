#!/usr/bin/env bash
# =============================================================================
# connect.sh — Open the IAP tunnels Selkies needs and launch the browser
#
# Run on your LOCAL machine. Opens both tunnels required by Selkies:
#   8080 — signaling/web UI
#   3478 — TURN relay (coturn), needed because ICE can't cross a TCP-only
#          tunnel without it
#
# Usage: ./connect.sh <instance> <zone> [project]
# =============================================================================
set -euo pipefail

INSTANCE="${1:?Usage: $0 <instance> <zone> [project]}"
ZONE="${2:?Usage: $0 <instance> <zone> [project]}"
PROJECT="${3:-}"
PROJECT_FLAG=()
[[ -n "$PROJECT" ]] && PROJECT_FLAG=(--project="$PROJECT")

PIDS=()
cleanup() {
    echo ""
    echo "Closing tunnels..."
    for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT INT TERM

echo "-> Opening signaling tunnel (8080)..."
gcloud compute start-iap-tunnel "$INSTANCE" 8080 \
    --local-host-port=localhost:8080 --zone="$ZONE" "${PROJECT_FLAG[@]}" &
PIDS+=("$!")

echo "-> Opening TURN relay tunnel (3478)..."
gcloud compute start-iap-tunnel "$INSTANCE" 3478 \
    --local-host-port=localhost:3478 --zone="$ZONE" "${PROJECT_FLAG[@]}" &
PIDS+=("$!")

sleep 6
echo ""
echo "Selkies: http://localhost:8080  (user / password from ~/.config/selkies/auth on the VM)"
xdg-open http://localhost:8080 &>/dev/null &

echo "Tunnels running — press Ctrl+C to close."
wait
