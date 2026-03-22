#!/usr/bin/env bash
# synth-shell-theme-picker.sh — numbered gallery themes for workstation setup
# Theme snippets live in lib/synth-shell-themes/ (paired with synth-shell-color-preview.html).
# Override: SYNTH_SHELL_THEME=1..20 to skip the menu. Default when non-interactive: 2.

_synth_themes_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/synth-shell-themes"

synth_shell_get_theme_file() {
    local n=$1
    local dir="${_synth_themes_dir}"
    local padded=""
    printf -v padded '%02d' "$n"
    local matches=()
    shopt -s nullglob
    matches=("${dir}/${padded}"-*.conf)
    shopt -u nullglob
    [[ ${#matches[@]} -eq 1 ]] || return 1
    [[ -f "${matches[0]}" ]] || return 1
    printf '%s\n' "${matches[0]}"
}

synth_shell_theme_title() {
    local f=$1
    grep -m1 '^# Theme ' "$f" | sed 's/^# Theme [0-9]*: //'
}

synth_shell_theme_swatch_ansi() {
    local f=$1
    local -a rgb=()
    read -r -a rgb < <(grep -m1 '^# swatch256:' "$f" | awk '{print $3,$4,$5}')
    [[ ${#rgb[@]} -eq 3 ]] || return 1
    printf '\033[48;5;%sm  \033[48;5;%sm  \033[48;5;%sm  \033[0m' \
        "${rgb[0]}" "${rgb[1]}" "${rgb[2]}"
}

synth_shell_print_theme_gallery() {
    local dir="${_synth_themes_dir}"
    local f n title sw
    echo ""
    echo -e "  ${BOLD}synth-shell prompt — pick a theme (1–20)${RESET}"
    echo -e "  ${DIM}Swatches: host · pwd · Git (256-color). Gallery: repo/synth-shell-color-preview.html${RESET}"
    echo ""
    for f in $(printf '%s\n' "${dir}"/[0-9][0-9]-*.conf | sort); do
        [[ -f "$f" ]] || continue
        n=$(basename "$f" | cut -d- -f1)
        n=$((10#$n))
        title=$(synth_shell_theme_title "$f")
        sw=$(synth_shell_theme_swatch_ansi "$f" 2>/dev/null || printf '   ')
        printf '  %2d) %b  %s\n' "$n" "$sw" "$title"
    done
    echo ""
}

synth_shell_resolve_theme_choice() {
    local default=${1:-2}
    if [[ "${SYNTH_SHELL_THEME:-}" =~ ^([1-9]|1[0-9]|20)$ ]]; then
        printf '%s\n' "${SYNTH_SHELL_THEME}"
        return 0
    fi
    if [[ -n "${CI:-}" ]]; then
        printf '%s\n' "$default"
        return 0
    fi
    local choice=""
    if [[ -t 0 ]]; then
        read -r -p "  Theme number [1–20, default ${default}]: " choice
    elif [[ -r /dev/tty ]]; then
        read -r -p "  Theme number [1–20, default ${default}]: " choice < /dev/tty > /dev/tty 2>/dev/tty || true
    else
        printf '%s\n' "$default"
        return 0
    fi
    choice=$(echo "$choice" | tr -d '[:space:]')
    if [[ -z "$choice" ]]; then
        printf '%s\n' "$default"
        return 0
    fi
    if [[ "$choice" =~ ^([1-9]|1[0-9]|20)$ ]]; then
        printf '%s\n' "$choice"
        return 0
    fi
    warn "Invalid theme '${choice}' — using default ${default}"
    printf '%s\n' "$default"
}

synth_shell_apply_prompt_theme() {
    local theme_n=$1
    local dest="${USER_HOME}/.config/synth-shell/synth-shell-prompt.config"
    local src
    src=$(synth_shell_get_theme_file "$theme_n") || {
        warn "Theme file for #${theme_n} not found"
        return 1
    }
    mkdir -p "${USER_HOME}/.config/synth-shell"
    cp "$src" "$dest"
    chown "${REAL_USER}:${REAL_USER}" "$dest"
    ok "synth-shell prompt colors → theme ${theme_n} ($(synth_shell_theme_title "$src"))"
}
