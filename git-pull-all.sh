#!/usr/bin/env bash
# Quick wrapper for update_projects.py
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${DIR}/update_projects.py" "$@"
