#!/usr/bin/env bash
# =============================================================================
# git-pull-all.sh — Pull latest changes across all Git repositories in a directory
# =============================================================================
# Usage:
#   ./git-pull-all.sh [target_dir]
#
# Defaults to current directory, or ~/projetos if run from home or repo dir.
# =============================================================================
set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'

# ── Target Directory Resolution ──────────────────────────────────────────────
TARGET_DIR="${1:-}"
if [[ -z "$TARGET_DIR" ]]; then
    if [[ -d "${HOME}/projetos" && "$PWD" == "$HOME" ]]; then
        TARGET_DIR="${HOME}/projetos"
    else
        TARGET_DIR="$PWD"
    fi
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${RED}Error:${RESET} Directory '$TARGET_DIR' does not exist." >&2
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo ""
echo -e "${BOLD}${CYAN}  Git Pull All${RESET} — Updating repositories in: ${YELLOW}${TARGET_DIR}${RESET}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${RESET}"

# ── Find Repositories ────────────────────────────────────────────────────────
# Check immediate subdirectories first; if target itself is a repo, include it
repos=()
if [[ -d "${TARGET_DIR}/.git" ]]; then
    repos+=("${TARGET_DIR}")
fi

while IFS= read -r gitdir; do
    repo_path="$(dirname "$gitdir")"
    [[ "$repo_path" == "$TARGET_DIR" ]] && continue
    repos+=("$repo_path")
done < <(find "$TARGET_DIR" -maxdepth 2 -mindepth 2 -name ".git" -type d 2>/dev/null | sort)

TOTAL=${#repos[@]}
if [[ $TOTAL -eq 0 ]]; then
    echo -e "  ${YELLOW}No Git repositories found in ${TARGET_DIR}.${RESET}"
    echo ""
    exit 0
fi

echo -e "  Found ${BOLD}${TOTAL}${RESET} repositories."
echo ""

# ── Process Repositories ─────────────────────────────────────────────────────
UP_TO_DATE=0
UPDATED=0
DIRTY=0
DIVERGED=0
SKIPPED=0
FAILED=0

for repo in "${repos[@]}"; do
    name="$(basename "$repo")"
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"

    # Skip detached HEAD
    if [[ "$branch" == "HEAD" ]]; then
        printf "  ${YELLOW}⏭${RESET}  ${BOLD}%-28s${RESET} [${DIM}detached HEAD${RESET}] — ${YELLOW}skipped${RESET}\n" "$name"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Check for uncommitted changes
    status_out="$(git -C "$repo" status --porcelain 2>/dev/null || true)"
    if [[ -n "$status_out" ]]; then
        printf "  ${YELLOW}⚠${RESET}  ${BOLD}%-28s${RESET} [${CYAN}%s${RESET}] — ${YELLOW}skipped (uncommitted changes)${RESET}\n" "$name" "$branch"
        DIRTY=$((DIRTY + 1))
        continue
    fi

    # Auto-detect upstream tracking if missing but origin branch exists
    if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
        git -C "$repo" fetch --quiet 2>/dev/null || true
        if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
            git -C "$repo" branch --set-upstream-to="origin/${branch}" "$branch" &>/dev/null || true
        else
            printf "  ${DIM}⏭${RESET}  ${BOLD}%-28s${RESET} [${CYAN}%s${RESET}] — ${DIM}skipped (no upstream branch)${RESET}\n" "$name" "$branch"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
    fi

    # Attempt git pull (prefer --ff-only to never create unexpected merge commits)
    pull_out="$(git -C "$repo" pull --ff-only 2>&1)"
    pull_exit=$?

    # If pull failed due to submodule issues (e.g. missing upstream submodule refs),
    # fallback to pulling parent branch without recursive submodules
    if [[ $pull_exit -ne 0 && "$pull_out" =~ (submodule|Submodule) ]]; then
        retry_out="$(git -C "$repo" pull --ff-only --no-recurse-submodules 2>&1)"
        if [[ $? -eq 0 ]]; then
            pull_out="$retry_out"
            pull_exit=0
        fi
    fi

    if [[ $pull_exit -ne 0 ]]; then
        if [[ "$pull_out" =~ "Not possible to fast-forward"|"divergent branches" ]]; then
            printf "  ${YELLOW}≠${RESET}  ${BOLD}%-28s${RESET} [${CYAN}%s${RESET}] — ${YELLOW}diverged (manual merge/rebase needed)${RESET}\n" "$name" "$branch"
            DIVERGED=$((DIVERGED + 1))
        else
            printf "  ${RED}✖${RESET}  ${BOLD}%-28s${RESET} [${CYAN}%s${RESET}] — ${RED}failed${RESET}\n" "$name" "$branch"
            echo -e "     ${DIM}${pull_out}${RESET}"
            FAILED=$((FAILED + 1))
        fi
    elif [[ "$pull_out" =~ "Already up to date."|"Already up-to-date." ]]; then
        printf "  ${GREEN}✔${RESET}  ${BOLD}%-28s${RESET} [${CYAN}%s${RESET}] — ${DIM}up to date${RESET}\n" "$name" "$branch"
        UP_TO_DATE=$((UP_TO_DATE + 1))
    else
        printf "  ${GREEN}↑${RESET}  ${BOLD}%-28s${RESET} [${CYAN}%s${RESET}] — ${GREEN}updated${RESET}\n" "$name" "$branch"
        UPDATED=$((UPDATED + 1))
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}Summary:${RESET} ${GREEN}${UPDATED} updated${RESET} · ${GREEN}${UP_TO_DATE} up to date${RESET} · ${YELLOW}${DIRTY} uncommitted${RESET} · ${YELLOW}${DIVERGED} diverged${RESET} · ${DIM}${SKIPPED} skipped${RESET} · ${RED}${FAILED} failed${RESET}"
echo ""
