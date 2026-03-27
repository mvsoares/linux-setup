# =============================================================================
# Module 03 — Shell Enhancements & Terminal Config
# =============================================================================
init_sub 5

# ── Starship prompt ───────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
    skip "Starship"
else
    info "Installing Starship prompt..."
    curl -fsSL https://starship.rs/install.sh -o /tmp/starship_install.sh && sh /tmp/starship_install.sh --yes >> "$LOG_FILE" 2>&1 && rm -f /tmp/starship_install.sh \
        && ok "Starship installed" || warn "Starship install failed"
fi
tick "Starship prompt"

# ── Global shell profile ─────────────────────────────────────────────────────
cat > /etc/profile.d/99-workstation.sh << 'PROFILE'
#!/usr/bin/env bash
# Only apply to interactive shells for real users (not root/service accounts)
[[ $- != *i* ]] && return
[[ $EUID -eq 0 ]] && return

# ── Workstation Shell Enhancements ────────────────────────────────────────────
export HISTSIZE=50000; export HISTFILESIZE=100000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT="%F %T  "
shopt -s histappend cmdhist autocd cdspell dirspell globstar 2>/dev/null || true
export EDITOR=vim; export VISUAL=vim
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# NVIDIA on-demand GPU wrapper
if command -v nvidia-smi &>/dev/null; then
    nvrun() { __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia "$@"; }
    export -f nvrun 2>/dev/null || true
    alias gpu-status='nvidia-smi'
    alias gpu-mode='prime-select query'
    alias gpu-watch='watch -n 1 nvidia-smi'
fi

# Modern tool overrides (only activate if present)
command -v wezterm &>/dev/null && alias wezterm='wezterm 2>/dev/null'
command -v bat &>/dev/null && alias cat='bat --paging=never --style=plain' && alias catp='bat'
command -v eza &>/dev/null && alias ls='eza --icons' && alias ll='eza -lah --icons --git' && alias lt='eza --tree --icons -L 3'
command -v fzf &>/dev/null && export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline --color=header:italic:underline,prompt:bold'
command -v direnv &>/dev/null && eval "$(direnv hook bash)" 2>/dev/null || true
command -v dust &>/dev/null && alias du='dust'
command -v procs &>/dev/null && alias pss='procs'
if command -v duf &>/dev/null; then
    df() { if [[ $# -eq 0 ]]; then duf; else command df "$@"; fi; }
fi
command -v btm &>/dev/null && alias top='btm'

# fzf keybindings (paths differ between distros)
[[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
[[ -f /usr/share/fzf/shell/key-bindings.bash ]] && source /usr/share/fzf/shell/key-bindings.bash
[[ -f /usr/share/bash-completion/completions/fzf ]] && source /usr/share/bash-completion/completions/fzf

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
alias myip='curl -s ifconfig.me'
alias sysinfo='fastfetch 2>/dev/null || neofetch 2>/dev/null || inxi -Fxz 2>/dev/null'
alias weather='curl -s wttr.in/?format=3'
# Distro-specific update alias
if [[ -f /etc/fedora-release ]]; then
    alias update='sudo dnf upgrade -y && flatpak update -y 2>/dev/null'
else
    alias update='sudo apt update && sudo apt upgrade -y && sudo snap refresh && flatpak update -y 2>/dev/null'
fi
alias fonts-list='fc-list | sort'; alias fonts-mono='fc-list :spacing=mono | sort'
alias pbcopy='xclip -selection clipboard'; alias pbpaste='xclip -selection clipboard -o'

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
chmod +x /etc/profile.d/99-workstation.sh
tick "Global shell profile (/etc/profile.d/99-workstation.sh)"

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
symbol = " "

[nodejs]
format = ' [$symbol($version)]($style)'
symbol = " "

[rust]
format = ' [$symbol($version)]($style)'
symbol = " "

[golang]
format = ' [$symbol($version)]($style)'
symbol = " "

[java]
format = ' [$symbol($version)]($style)'
symbol = " "

[docker_context]
format = ' [$symbol$context]($style)'
symbol = " "

[kubernetes]
disabled = false
format = ' [$symbol$context(\($namespace\))]($style)'
symbol = "☸ "
detect_folders = ["k8s", "kube", "kubernetes"]

[aws]
format = ' [$symbol($profile)(\($region\))]($style)'
symbol = "  "

[gcloud]
format = ' [$symbol($project)]($style)'
symbol = " "
TOML
        chown "$REAL_USER:$REAL_USER" "$STARSHIP_CFG"
        ok "Starship config created"
    else
        skip "Starship config (already exists)"
    fi
fi
tick "Starship configuration"

# ── synth-shell ───────────────────────────────────────────────────────────────
# shellcheck source=../lib/synth-shell-theme-picker.sh
source "${SCRIPT_DIR}/lib/synth-shell-theme-picker.sh"

if [[ -n "$REAL_USER" ]] && [[ -f "${USER_HOME}/.config/synth-shell/synth-shell-prompt.sh" ]]; then
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
        printf 'iunyyyy' | \
            sudo -u "$REAL_USER" HOME="$USER_HOME" \
            bash /tmp/synth-shell-install/setup.sh >> "$LOG_FILE" 2>&1 \
            && ok "synth-shell installed" \
            || warn "synth-shell setup had errors — check ${LOG_FILE}"
        rm -rf /tmp/synth-shell-install
        # Fix synth-shell kube segment: upstream uses broken yq query that errors with Go yq/jq
        SYNTH_PROMPT="${USER_HOME}/.config/synth-shell/synth-shell-prompt.sh"
        if [[ -f "$SYNTH_PROMPT" ]] && grep -q "yq '\.contexts" "$SYNTH_PROMPT"; then
            sed -i "/type yq/d" "$SYNTH_PROMPT"
            sed -i "s|echo -n \"\$(kubectl config view.*yq.*head -n 1)\"|echo -n \"\$(kubectl config current-context 2>/dev/null)\"|" \
                "$SYNTH_PROMPT"
            ok "synth-shell kube segment patched"
        fi
        # Prompt colors: gallery themes 1–20 (see synth-shell-color-preview.html). Override with SYNTH_SHELL_THEME=N
        if [[ -z "${SYNTH_SHELL_THEME:-}" ]] && [[ -z "${CI:-}" ]] && { [[ -t 0 ]] || [[ -r /dev/tty ]]; }; then
            synth_shell_print_theme_gallery
        fi
        theme_n=$(synth_shell_resolve_theme_choice 2)
        synth_shell_apply_prompt_theme "$theme_n" || true
    else
        warn "synth-shell clone failed"
    fi
fi
tick "synth-shell (prompt · better-ls · better-alias · better-history)"

# ── Bashrc tune-ups ──────────────────────────────────────────────────────────
BASHRC="${USER_HOME}/.bashrc"
if [[ -f "$BASHRC" ]]; then
    BACKUP="${USER_HOME}/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
    cp "$BASHRC" "$BACKUP"
    chown "$REAL_USER:$REAL_USER" "$BACKUP"
    sed -i 's/^HISTSIZE=1000$/HISTSIZE=50000/' "$BASHRC"
    sed -i 's/^HISTFILESIZE=2000$/HISTFILESIZE=100000/' "$BASHRC"
    sed -i 's/^#shopt -s globstar$/shopt -s globstar/' "$BASHRC"
    
    # Ensure zoxide is initialized at the very end of .bashrc
    if ! grep -q 'zoxide init bash' "$BASHRC"; then
        echo -e '\n# Initialize zoxide (must be at the end)' >> "$BASHRC"
        echo 'command -v zoxide &>/dev/null && eval "$(zoxide init bash)" && alias cd='\''z'\''' >> "$BASHRC"
    fi

    ok "Bashrc tuned (backup: ${BACKUP})"
fi
tick "Bashrc improvements"

ok "Shell enhancements complete"
