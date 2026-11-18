#!/usr/bin/env bash
# WezTerm Tab Bar Theme Picker Wrapper
# Permite selecionar e aplicar temas visuais de abas no WezTerm interativamente ou via flags.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PYTHON_BIN="$(command -v python3 || echo "python")"

if ! command -v "$PYTHON_BIN" &>/dev/null; then
    echo "Erro: Python 3 não encontrado no PATH." >&2
    exit 1
fi

exec "$PYTHON_BIN" "${SCRIPT_DIR}/wezterm-tab-theme-picker.py" "$@"
