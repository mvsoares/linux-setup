#!/usr/bin/env bash
# =============================================================================
# Copy linux-setup to one or more Ubuntu VMs over SSH and run setup.sh in
# parallel. Requires: SSH key login for the remote user, and sudo (password
# piped once per host via sudo -S — set MARCUS_SUDO_PASSWORD or use --password-file).
#
# Usage:
#   export MARCUS_SUDO_PASSWORD='your-sudo-password'
#   bash scripts/parallel-vm-setup.sh 192.168.122.105 192.168.122.228
#
# Or:
#   bash scripts/parallel-vm-setup.sh --password-file ~/.config/vm-sudo -- 192.168.122.105 192.168.122.228
#
# Options:
#   --user NAME     SSH user (default: marcus)
#   --dest NAME     Directory under ~ on the VM (default: linux-setup)
#   --reset         Pass --reset to setup.sh (full reinstall, clears checkpoints)
#   --rsync-only    Copy repo only; do not run setup.sh (no sudo password needed)
# =============================================================================
set -euo pipefail

REMOTE_USER="${REMOTE_USER:-marcus}"
# rsync remote path relative to home (default: linux-setup → ~/linux-setup)
REMOTE_PATH="${REMOTE_PATH:-linux-setup}"
DO_RESET=false
RSYNC_ONLY=false
PASSFILE=""
HOSTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) REMOTE_USER="${2:?}"; shift 2 ;;
    --dest) REMOTE_PATH="${2:?}"; shift 2 ;;
    --reset) DO_RESET=true; shift ;;
    --rsync-only) RSYNC_ONLY=true; shift ;;
    --password-file) PASSFILE="${2:?}"; shift 2 ;;
    --) shift; HOSTS+=("$@"); break ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) HOSTS+=("$1"); shift ;;
  esac
done

[[ ${#HOSTS[@]} -ge 1 ]] || { echo "Usage: $0 [--user U] [--dest REL_PATH] [--reset] [--password-file F] HOST [HOST...]" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "→ Rsync $REPO_ROOT → ${REMOTE_USER}@HOST:~/${REMOTE_PATH} (parallel)"
for h in "${HOSTS[@]}"; do
  rsync -az --delete \
    "$REPO_ROOT/" "${REMOTE_USER}@${h}:${REMOTE_PATH}/" &
done
wait
echo "→ Rsync done."

if $RSYNC_ONLY; then
  echo "→ --rsync-only: skipping setup.sh"
  exit 0
fi

get_pw() {
  if [[ -n "${MARCUS_SUDO_PASSWORD:-}" ]]; then
    printf '%s' "$MARCUS_SUDO_PASSWORD"
    return
  fi
  if [[ -n "$PASSFILE" && -f "$PASSFILE" ]]; then
    cat "$PASSFILE"
    return
  fi
  echo "Set MARCUS_SUDO_PASSWORD or use --password-file /path/to/file (chmod 600)." >&2
  exit 1
}

PW="$(get_pw)"
export PW

SETUP_EXTRA=()
if $DO_RESET; then
  SETUP_EXTRA+=(--reset)
fi

PIDS=()
LOGDIR="$(mktemp -d "${TMPDIR:-/tmp}/vm-setup-logs.XXXXXX")"
echo "→ Logs: $LOGDIR"

for h in "${HOSTS[@]}"; do
  LOG="$LOGDIR/${h//./_}.log"
  (
    set +e
    printf '%s\n' "$PW" | ssh -o BatchMode=yes -o ConnectTimeout=30 "${REMOTE_USER}@${h}" \
      "cd ~/${REMOTE_PATH} && sudo -S bash setup.sh ${SETUP_EXTRA[*]}" >"$LOG" 2>&1
    ec=$?
    echo "EXIT_CODE=$ec" >>"$LOG"
    exit "$ec"
  ) &
  PIDS+=($!)
done

FAILED=0
for i in "${!PIDS[@]}"; do
  wait "${PIDS[$i]}" || FAILED=$((FAILED + 1))
done

echo ""
echo "=== Summary ==="
for h in "${HOSTS[@]}"; do
  LOG="$LOGDIR/${h//./_}.log"
  ec="$(grep -E '^EXIT_CODE=' "$LOG" | tail -1 || echo EXIT_CODE=unknown)"
  echo "  $h  $ec  (log: $LOG)"
  grep -E '⚠|✖|failed|Failed|E: |ERR!|fatal:|non-fatal|Errors\s+:' "$LOG" | tail -20 || true
  echo ""
done

if [[ "$FAILED" -gt 0 ]]; then
  echo "Some installs failed (wait exit). Check logs in $LOGDIR" >&2
  exit 1
fi
echo "All installs finished (check logs for warnings)."
