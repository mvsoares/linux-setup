# =============================================================================
# Module 09 — Workspace Config (Git · Tmux · Direnv · EditorConfig)
# =============================================================================
init_sub 6

# ── Git config ────────────────────────────────────────────────────────────────
info "Applying git config improvements..."

_git_cred_helper=""
for _cand in \
    /usr/libexec/git-core/git-credential-libsecret \
    /usr/lib/git-core/git-credential-libsecret \
    /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret; do
    if [[ -x "$_cand" ]]; then
        _git_cred_helper="$_cand"
        break
    fi
done

if [[ -n "$_git_cred_helper" ]]; then
    as_user "git config --global credential.helper '${_git_cred_helper}'"
    ok "Git credential helper → libsecret (${_git_cred_helper})"
else
    info "git-credential-libsecret not available — keeping current helper (tip: run 'gh auth setup-git')"
fi

as_user "git config --global init.defaultBranch main"
if ! is_server_profile && command -v codium &>/dev/null; then
    as_user "git config --global core.editor 'codium --wait'"
elif command -v nvim &>/dev/null; then
    as_user "git config --global core.editor 'nvim'"
elif command -v vim &>/dev/null; then
    as_user "git config --global core.editor 'vim'"
fi
if command -v delta &>/dev/null; then
    as_user "git config --global core.pager delta"
    as_user "git config --global interactive.diffFilter 'delta --color-only'"
    as_user "git config --global delta.navigate true"
    as_user "git config --global delta.side-by-side true"
    as_user "git config --global delta.line-numbers true"
    as_user "git config --global delta.syntax-theme Dracula"
fi
as_user "git config --global core.autocrlf input"
as_user "git config --global merge.conflictstyle zdiff3"
as_user "git config --global diff.algorithm histogram"
as_user "git config --global diff.colorMoved default"
as_user "git config --global rerere.enabled true"
as_user "git config --global fetch.prune true"
as_user "git config --global push.autoSetupRemote true"
as_user "git config --global pull.rebase true"
as_user "git config --global rebase.autoStash true"
as_user "git config --global branch.sort -committerdate"
as_user "git config --global tag.sort -version:refname"
as_user "git config --global column.ui auto"
tick "Git config (delta, libsecret, histogram, zdiff3)"

# ── Global gitignore ─────────────────────────────────────────────────────────
# Kept focused on OS, editor, and local env files (never ignore dist/build/target globally)
GLOBAL_GITIGNORE="${USER_HOME}/.gitignore_global"
if [[ ! -f "$GLOBAL_GITIGNORE" ]]; then
    cat > "$GLOBAL_GITIGNORE" << 'GITIGNORE'
# OS
.DS_Store
Thumbs.db
Desktop.ini
*~

# Editors & IDEs
.vscode/
.idea/
*.swp
*.swo
.project
.settings/

# Local Environment
.env.local
.env.*.local
.direnv/

# Local Tool Caches
__pycache__/
*.pyc
.mypy_cache/
.ruff_cache/
.pytest_cache/
GITIGNORE
    chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "$GLOBAL_GITIGNORE"
    ok "Global gitignore deployed"
else
    ok "Global gitignore already present"
fi
as_user "git config --global core.excludesFile '${GLOBAL_GITIGNORE}'"
tick "Global gitignore"

# ── Tmux config + TPM ────────────────────────────────────────────────────────
TMUX_CONF="${USER_HOME}/.tmux.conf"
if [[ -f "$TMUX_CONF" ]]; then
    skip "tmux config (already exists)"
else
    info "Creating tmux config..."
    cat > "$TMUX_CONF" << 'TMUX'
# Prefix: Ctrl-a (more ergonomic than Ctrl-b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Modern terminal settings (truecolor + WezTerm OSC passthrough)
set -g default-terminal "tmux-256color"
set -as terminal-features ",*:RGB"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g allow-passthrough on
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 0
set -g focus-events on

# Split panes with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Navigate panes with Alt+arrow (no prefix)
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Resize panes
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Status bar — clean and minimal (Dracula)
set -g status-style 'bg=#282a36 fg=#f8f8f2'
set -g status-left '#[fg=#50fa7b,bold] #S '
set -g status-right '#[fg=#8be9fd] %H:%M  #[fg=#bd93f9]%d-%b '
set -g status-left-length 30
set -g status-right-length 50
setw -g window-status-format '#[fg=#6272a4] #I:#W '
setw -g window-status-current-format '#[fg=#ff79c6,bold] #I:#W '

# Pane borders
set -g pane-border-style 'fg=#6272a4'
set -g pane-active-border-style 'fg=#ff79c6'

# New window in current path
bind c new-window -c "#{pane_current_path}"

# ── TPM Plugins (press prefix + I to install) ────────────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'

if "test ! -d ~/.tmux/plugins/tpm" \
   "run 'git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm'"
run '~/.tmux/plugins/tpm/tpm'
TMUX
    chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "$TMUX_CONF"
    ok "tmux config (Dracula-themed, Ctrl-a, RGB/WezTerm passthrough, TPM)"
fi

# TPM (tmux plugin manager)
TPM_DIR="${USER_HOME}/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR" ]]; then
    skip "TPM (tmux plugin manager)"
else
    as_user "git clone --depth=1 https://github.com/tmux-plugins/tpm '${TPM_DIR}'" \
        >> "$LOG_FILE" 2>&1 && ok "TPM installed" || warn "TPM clone failed"
fi
tick "tmux config + TPM"

# ── Direnv ────────────────────────────────────────────────────────────────────
if command -v direnv &>/dev/null; then
    ok "direnv already installed"
else
    pkg_install direnv
fi

# direnv helpers (idiomatic direnv without shadowing built-in layout_python)
DIRENV_DIR="${USER_HOME}/.config/direnv"
mkdir -p "$DIRENV_DIR"
if [[ ! -f "${DIRENV_DIR}/direnvrc" ]]; then
    cat > "${DIRENV_DIR}/direnvrc" << 'DIRENVRC'
# Idiomatic uv / .venv layout for direnv (use `layout uv` in .envrc)
layout_uv() {
    if [[ -d ".venv" ]]; then
        VIRTUAL_ENV="$(pwd)/.venv"
    else
        uv venv .venv
        VIRTUAL_ENV="$(pwd)/.venv"
    fi
    PATH_add "$VIRTUAL_ENV/bin"
    export UV_ACTIVE=1
    export VIRTUAL_ENV
}

# Auto-detect and use Node version from .nvmrc (use `use nvm` in .envrc)
use_nvm() {
    local NVM_DIR="$HOME/.nvm"
    if [[ -f .nvmrc ]] && [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
        nvm use
    fi
}
DIRENVRC
    chown -R "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "$DIRENV_DIR"
    ok "direnv config with uv/nvm helpers"
fi
tick "direnv + helpers"

# ── Global .editorconfig ─────────────────────────────────────────────────────
EDITORCONFIG="${USER_HOME}/.editorconfig"
if [[ ! -f "$EDITORCONFIG" ]]; then
    cat > "$EDITORCONFIG" << 'EDITORCONFIG'
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 2
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false

[*.{py,rs}]
indent_size = 4

[*.go]
indent_style = tab
indent_size = 4

[Makefile]
indent_style = tab

[*.{yml,yaml}]
indent_size = 2
EDITORCONFIG
    chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "$EDITORCONFIG"
    ok "Global .editorconfig created"
else
    skip "Global .editorconfig (already exists)"
fi
tick "Global .editorconfig"

# ── SSH key helper ────────────────────────────────────────────────────────────
SSH_DIR="${USER_HOME}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "$SSH_DIR"

if [[ ! -f "${SSH_DIR}/id_ed25519" ]]; then
    info "No SSH key found. Generate one with:"
    info "  ssh-keygen -t ed25519 -C 'your-email@example.com'"
else
    ok "SSH key exists (${SSH_DIR}/id_ed25519)"
fi

# SSH config with sensible defaults
if [[ ! -f "${SSH_DIR}/config" ]]; then
    cat > "${SSH_DIR}/config" << 'SSHCONFIG'
Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
SSHCONFIG
    chmod 600 "${SSH_DIR}/config"
    chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "${SSH_DIR}/config"
    ok "SSH config created with sensible defaults"
else
    skip "SSH config (already exists)"
fi
tick "SSH config"

ok "Workspace config complete"
