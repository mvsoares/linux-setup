# =============================================================================
# Module 03 — Shell Enhancements & Terminal Config
# =============================================================================
init_sub 5

# ── Starship prompt ───────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
    skip "Starship"
else
    info "Installing Starship prompt..."
    curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" https://starship.rs/install.sh -o /tmp/starship_install.sh \
        && sh /tmp/starship_install.sh --yes >> "$LOG_FILE" 2>&1 \
        && rm -f /tmp/starship_install.sh \
        && ok "Starship installed" || warn "Starship install failed"
fi
tick "Starship prompt"

# ── Global & User shell profile (/etc/profile.d + ~/.bashrc.d) ───────────────
# Deployed to both /etc/profile.d (login shells) and ~/.bashrc.d (interactive
# non-login terminals like WezTerm & GNOME Terminal on Ubuntu).
read -r -d '' WORKSTATION_PROFILE << 'PROFILE' || true
#!/usr/bin/env bash
# Only apply to interactive shells for real users (not root/service accounts)
[[ $- != *i* ]] && return
[[ $EUID -eq 0 ]] && return
# Avoid double-sourcing when both /etc/profile.d and ~/.bashrc.d load
[[ -n "${__LINUX_SETUP_WORKSTATION_LOADED:-}" ]] && return
__LINUX_SETUP_WORKSTATION_LOADED=1

# ── Workstation Shell Enhancements ────────────────────────────────────────────
export HISTSIZE=50000; export HISTFILESIZE=100000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT="%F %T  "
shopt -s histappend cmdhist autocd cdspell dirspell globstar 2>/dev/null || true

if command -v nvim &>/dev/null; then
    export EDITOR=nvim; export VISUAL=nvim
elif command -v vim &>/dev/null; then
    export EDITOR=vim; export VISUAL=vim
else
    export EDITOR=nano; export VISUAL=nano
fi

[[ -d "$HOME/.local/bin" ]] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# NVIDIA on-demand GPU wrapper
if command -v nvidia-smi &>/dev/null; then
    nvrun() { __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia "$@"; }
    export -f nvrun 2>/dev/null || true
    alias gpu-status='nvidia-smi'
    alias gpu-mode='prime-select query'
    alias gpu-watch='watch -n 1 nvidia-smi'
fi

# Modern tool overrides (only activate if present)
command -v bat &>/dev/null && alias cat='bat --paging=never --style=plain' && alias catp='bat'
command -v eza &>/dev/null && alias ls='eza --icons' && alias ll='eza -lah --icons --git' && alias lt='eza --tree --icons -L 3'
# Preserve theme-synced FZF_DEFAULT_OPTS if synth-shell-theme already set it
if command -v fzf &>/dev/null; then
    : "${FZF_DEFAULT_OPTS:=--height=40% --layout=reverse --border --info=inline --color=header:italic:underline,prompt:bold}"
    export FZF_DEFAULT_OPTS
fi
command -v direnv &>/dev/null && eval "$(direnv hook bash)" 2>/dev/null || true
command -v dust &>/dev/null && alias du='dust'
command -v procs &>/dev/null && alias pss='procs'
if command -v duf &>/dev/null; then
    df() { if [[ $# -eq 0 ]]; then duf; else command df "$@"; fi; }
fi
command -v btm &>/dev/null && alias top='btm'
command -v xh &>/dev/null && alias http='xh'

# Yazi wrapper that changes cwd on exit
if command -v yazi &>/dev/null; then
    yy() {
        local tmp cwd
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
            builtin cd -- "$cwd" || return
        fi
        rm -f -- "$tmp"
    }
fi

# fzf keybindings (paths differ between distros)
[[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
[[ -f /usr/share/fzf/shell/key-bindings.bash ]] && source /usr/share/fzf/shell/key-bindings.bash
[[ -f /usr/share/bash-completion/completions/fzf ]] && source /usr/share/bash-completion/completions/fzf

# Atuin searchable shell history (Ctrl+R only, keeps Up-arrow normal)
if command -v atuin &>/dev/null; then
    eval "$(atuin init bash --disable-up-arrow)" 2>/dev/null || true
fi

# Navigation
alias ..='cd ..'; alias ...='cd ../..'; alias ....='cd ../../..'

# Git aliases
alias g='git'; alias gs='git status'; alias ga='git add'
alias gc='git commit'; alias gp='git push'; alias gpl='git pull'
alias gco='git checkout'; alias gsw='git switch'; alias gb='git branch'
alias gst='git stash'; alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias lg='lazygit'; alias lzd='lazydocker'

# Podman & system
alias dk='podman'; alias dkc='podman compose'; alias py='python3'
alias please='sudo'; alias ports='ss -tulpn'
alias myip='curl -s --max-time 5 ifconfig.me'
alias sysinfo='fastfetch 2>/dev/null || inxi -Fxz 2>/dev/null'
alias weather='curl -s --max-time 5 wttr.in/?format=3'
# Distro-specific update alias (includes pipx & flatpak)
if [[ -f /etc/fedora-release ]]; then
    alias update='sudo dnf upgrade -y && (command -v flatpak &>/dev/null && flatpak update -y || true) && (command -v pipx &>/dev/null && pipx upgrade-all || true)'
else
    alias update='sudo apt update && sudo apt upgrade -y && (command -v snap &>/dev/null && sudo snap refresh || true) && (command -v flatpak &>/dev/null && flatpak update -y || true) && (command -v pipx &>/dev/null && pipx upgrade-all || true)'
fi
alias fonts-list='fc-list | sort'; alias fonts-mono='fc-list :spacing=mono | sort'
if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy &>/dev/null; then
    alias pbcopy='wl-copy'
    alias pbpaste='wl-paste'
elif command -v xclip &>/dev/null; then
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'
fi

# Quick extract — handles all common archive formats
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1"     ;; *.tar.gz)  tar xzf "$1"     ;;
            *.tar.xz)  tar xJf "$1"     ;; *.bz2)     bunzip2 "$1"     ;;
            *.rar)     unrar x "$1"      ;; *.gz)      gunzip "$1"      ;;
            *.tar)     tar xf "$1"       ;; *.tbz2)    tar xjf "$1"     ;;
            *.tgz)     tar xzf "$1"      ;; *.zip)     unzip "$1"       ;;
            *.Z)       uncompress "$1"   ;; *.7z)      7z x "$1"        ;;
            *)         echo "'$1' cannot be extracted" ;;
        esac
    else echo "'$1' is not a valid file"; fi
}

# Quick directory size
dirsize() { command du -sh "${1:-.}" 2>/dev/null | cut -f1; }

# mkcd: create dir and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Prompt: synth-shell-prompt takes precedence; fall back to Starship
if [[ -f "$HOME/.config/synth-shell/synth-shell-prompt.sh" ]]; then
    source "$HOME/.config/synth-shell/synth-shell-prompt.sh"
elif command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi
PROFILE

install_shell_snippet "99-workstation.sh" "$WORKSTATION_PROFILE"
tick "Shell profile (/etc/profile.d + ~/.bashrc.d/99-workstation.sh)"

# ── Starship config ──────────────────────────────────────────────────────────
if [[ -n "$REAL_USER" ]]; then
    STARSHIP_CFG="${USER_HOME}/.config/starship.toml"
    mkdir -p "${USER_HOME}/.config"
    if [[ ! -f "$STARSHIP_CFG" ]]; then
        cat > "$STARSHIP_CFG" << 'TOML'
"$schema" = 'https://starship.rs/config-schema.json'
format = """
[╭─](bold blue)$os$username$hostname$directory$git_branch$git_status$python$nodejs$rust$golang$java$docker_context$kubernetes$aws$gcloud
[╰─](bold blue)$character"""

[os]
disabled = false
style = "bold cyan"

[username]
show_always = false
format = "[$user]($style)@"
style_user = "bold green"

[hostname]
ssh_only = true
format = "[$hostname]($style) "
style = "bold blue"

[directory]
style = "bold cyan"
truncation_length = 4
truncate_to_repo = false

[git_branch]
format = " [$symbol$branch]($style)"
style = "bold purple"

[git_status]
format = '([$all_status$ahead_behind]($style) )'
style = "bold red"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[cmd_duration]
min_time = 2_000
format = " [$duration]($style)"
style = "bold yellow"

[python]
format = ' [${symbol}${pyenv_prefix}(${version})(\($virtualenv\))]($style)'
symbol = " "

[nodejs]
format = ' [$symbol($version)]($style)'
symbol = " "

[rust]
format = ' [$symbol($version)]($style)'
symbol = " "

[golang]
format = ' [$symbol($version)]($style)'
symbol = " "

[java]
format = ' [$symbol($version)]($style)'
symbol = " "

[docker_context]
format = ' [$symbol$context]($style)'
symbol = " "

[kubernetes]
disabled = false
format = ' [$symbol$context(\($namespace\))]($style)'
symbol = "☸ "
detect_folders = ["k8s", "kube", "kubernetes"]

[aws]
format = ' [$symbol($profile)(\($region\))]($style)'
symbol = "󰸏 "

[gcloud]
format = ' [$symbol($project)]($style)'
symbol = "󱇶 "
TOML
        chown "$REAL_USER:$REAL_USER" "$STARSHIP_CFG"
        ok "Starship config created"
    else
        skip "Starship config (already exists)"
    fi
fi
tick "Starship configuration"

# ── synth-shell ───────────────────────────────────────────────────────────────
SYNTH_DIR="${USER_HOME}/.config/synth-shell"
SYNTH_PROMPT="${SYNTH_DIR}/synth-shell-prompt.sh"
SYNTH_FRESH_INSTALL=0

if [[ -n "$REAL_USER" ]] && [[ -f "$SYNTH_PROMPT" ]]; then
    skip "synth-shell (already installed)"
else
    info "Installing synth-shell..."
    rm -rf /tmp/synth-shell-install
    if git clone --recursive --depth=1 \
            https://github.com/andresgongora/synth-shell.git \
            /tmp/synth-shell-install >> "$LOG_FILE" 2>&1; then
        chmod +x /tmp/synth-shell-install/setup.sh
        # synth-shell prompts: read -s -n 1 (single char, no echo)
        # Answers: i=install, u=user, n=skip greeter, y=prompt, y=better-ls, y=alias, y=better-history
        if printf 'iunyyyy' | \
            sudo -u "$REAL_USER" HOME="$USER_HOME" \
            bash /tmp/synth-shell-install/setup.sh >> "$LOG_FILE" 2>&1; then
            ok "synth-shell installed"
            SYNTH_FRESH_INSTALL=1
        else
            warn "synth-shell setup had errors — check ${LOG_FILE}"
        fi
        rm -rf /tmp/synth-shell-install
    else
        warn "synth-shell clone failed"
    fi
fi

# Install & run standalone `synth-shell-theme` via pipx (PyPI with GitHub fallback)
SYNTH_THEME_BIN="${USER_HOME}/.local/bin/synth-shell-theme"
SYNTH_THEME_GIT="git+https://github.com/mvsoares/synth-shell-theme.git"

if [[ -n "$REAL_USER" ]]; then
    if ! command -v pipx &>/dev/null; then
        pkg_install pipx
        as_user "pipx ensurepath" >> "$LOG_FILE" 2>&1 || true
    fi
    if command -v pipx &>/dev/null; then
        if as_user "pipx install --force synth-shell-theme" >> "$LOG_FILE" 2>&1; then
            ok "synth-shell-theme installed/updated via pipx (PyPI)"
        elif as_user "pipx install --force '${SYNTH_THEME_GIT}'" >> "$LOG_FILE" 2>&1; then
            ok "synth-shell-theme installed/updated via pipx (GitHub)"
        else
            warn "synth-shell-theme pipx install failed — check ${LOG_FILE}"
        fi
    fi
fi

if [[ -f "$SYNTH_PROMPT" ]] && [[ -n "$REAL_USER" ]]; then
    SYNTH_INIT_ARGS=("init")
    if [[ "$SYNTH_FRESH_INSTALL" -eq 1 ]]; then
        SYNTH_INIT_ARGS+=("--apply" "${SYNTH_SHELL_THEME:-2}")
    else
        SYNTH_INIT_ARGS+=("--no-tune")
        [[ -n "${SYNTH_SHELL_THEME:-}" ]] && SYNTH_INIT_ARGS+=("--apply" "${SYNTH_SHELL_THEME}")
    fi

    if [[ -x "$SYNTH_THEME_BIN" ]]; then
        sudo -u "$REAL_USER" HOME="$USER_HOME" \
            "$SYNTH_THEME_BIN" "${SYNTH_INIT_ARGS[@]}" >> "$LOG_FILE" 2>&1 \
            && ok "synth-shell runtime patches & theme verified (synth-shell-theme)" \
            || warn "synth-shell-theme init reported an issue — check ${LOG_FILE}"
    else
        warn "synth-shell-theme binary not found at ${SYNTH_THEME_BIN} — run: pipx install synth-shell-theme"
    fi
fi
tick "synth-shell + synth-shell-theme"

# ── Bashrc tune-ups ──────────────────────────────────────────────────────────
BASHRC="${USER_HOME}/.bashrc"
if [[ -f "$BASHRC" ]]; then
    BACKUP="${USER_HOME}/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
    cp "$BASHRC" "$BACKUP"
    chown "$REAL_USER:$REAL_USER" "$BACKUP"
    sed -i 's/^HISTSIZE=1000$/HISTSIZE=50000/' "$BASHRC"
    sed -i 's/^HISTFILESIZE=2000$/HISTFILESIZE=100000/' "$BASHRC"
    sed -i 's/^#shopt -s globstar$/shopt -s globstar/' "$BASHRC"

    # Remove legacy getKube() override from older linux-setup versions so it does not
    # shadow synth-shell-theme's enhanced getKube() (namespace + production alert).
    if [[ -x "$SYNTH_THEME_BIN" ]] && grep -q '# Shorten GKE context in Synth-Shell prompt' "$BASHRC" 2>/dev/null; then
        sed -i '/^# Shorten GKE context in Synth-Shell prompt/,/^}$/d' "$BASHRC"
        ok "Removed legacy getKube() from .bashrc (now managed by synth-shell-theme)"
    fi

    # Shpool Session Prompt Indicator (dynamic theme matching; Bash 5.1+ array-safe)
    if ! grep -q '__shpool_ps1_prefix' "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'SHPOOLBLOCK'

# ── Shpool Session Prompt Indicator ───────────────────────────────────────────
__shpool_ps1_prefix() {
    local ret=$?
    if [ -n "${SHPOOL_SESSION_NAME:-}" ]; then
        local first_elem="${SSP_ELEMENTS[0]:-HOST}"
        local -n _colors="SSP_COLORS_${first_elem}" 2>/dev/null || true
        local fg="${_colors[0]:-white}" bg="${_colors[1]:-141}" eff="${_colors[2]:-bold}"

        local eff_c="0" fg_c="97" bg_c="48;5;141"
        [ "$eff" = "bold" ] && eff_c="1"

        if [[ "$fg" =~ ^[0-9]+$ ]]; then
            fg_c="38;5;$fg"
        else
            case "$fg" in
                black)          fg_c="30" ;;
                red)            fg_c="31" ;;
                green)          fg_c="32" ;;
                yellow)         fg_c="33" ;;
                blue)           fg_c="34" ;;
                magenta|purple) fg_c="35" ;;
                cyan)           fg_c="36" ;;
                white)          fg_c="97" ;;
            esac
        fi

        if [[ "$bg" =~ ^[0-9]+$ ]]; then
            bg_c="48;5;$bg"
        else
            case "$bg" in
                black)          bg_c="40" ;;
                red)            bg_c="41" ;;
                green)          bg_c="42" ;;
                yellow)         bg_c="43" ;;
                blue)           bg_c="44" ;;
                magenta|purple) bg_c="45" ;;
                cyan)           bg_c="46" ;;
                white)          bg_c="107" ;;
            esac
        fi

        local badge="\[\033[${eff_c};${fg_c};${bg_c}m\] ⬢ ${SHPOOL_SESSION_NAME} \[\033[0m\]"
        if [[ "$PS1" == *"╭"* ]]; then
            PS1="${PS1/╭/╭$badge }"
        else
            PS1="${badge} ${PS1}"
        fi
    fi
    return $ret
}

if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
    [[ " ${PROMPT_COMMAND[*]} " != *" __shpool_ps1_prefix "* ]] && PROMPT_COMMAND+=(__shpool_ps1_prefix)
elif [[ "${PROMPT_COMMAND:-}" != *"__shpool_ps1_prefix"* ]]; then
    PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND}; }__shpool_ps1_prefix"
fi
SHPOOLBLOCK
        ok "Shpool session prompt indicator added to .bashrc"
    fi

    # Ensure zoxide is initialized cleanly at the end of .bashrc (--cmd cd preserves cd -)
    if grep -q "zoxide init bash)\" && alias cd='z'" "$BASHRC" 2>/dev/null; then
        sed -i "s|eval \"\$(zoxide init bash)\" && alias cd='z'|eval \"\$(zoxide init bash --cmd cd)\"|" "$BASHRC"
        ok "Upgraded zoxide init to --cmd cd"
    elif ! grep -q 'zoxide init bash' "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'ZOXIDEBLOCK'

# Initialize zoxide (must be at the end)
command -v zoxide &>/dev/null && eval "$(zoxide init bash --cmd cd)"
ZOXIDEBLOCK
    fi

    chown "$REAL_USER:$REAL_USER" "$BASHRC"
    ok "Bashrc tuned (backup: ${BACKUP})"
fi
tick "Bashrc improvements"

ok "Shell enhancements complete"
