# =============================================================================
# Module 09 — Workspace Config (Git · Tmux · Direnv · EditorConfig)
# =============================================================================
init_sub 6

# ── Git config ────────────────────────────────────────────────────────────────
info "Applying git config improvements..."

GIT_CRED_DIR="/usr/share/doc/git/contrib/credential/libsecret"
if [[ -f "$GIT_CRED_DIR/git-credential-libsecret" ]]; then
    as_user "git config --global credential.helper '${GIT_CRED_DIR}/git-credential-libsecret'"
    ok "Git credential helper → libsecret (GNOME keyring)"
else
    info "git-credential-libsecret not available — keeping current helper"
fi

as_user "git config --global init.defaultBranch main"
if command -v cursor &>/dev/null; then
    as_user "git config --global core.editor 'cursor --wait'"
elif command -v codium &>/dev/null; then
    as_user "git config --global core.editor 'codium --wait'"
elif command -v code &>/dev/null; then
    as_user "git config --global core.editor 'code --wait'"
fi
if command -v delta &>/dev/null; then
    as_user "git config --global core.pager delta"
fi
as_user "git config --global core.autocrlf input"
if command -v delta &>/dev/null; then
    as_user "git config --global interactive.diffFilter 'delta --color-only'"
    as_user "git config --global delta.navigate true"
    as_user "git config --global delta.side-by-side true"
    as_user "git config --global delta.line-numbers true"
    as_user "git config --global delta.syntax-theme Dracula"
fi
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
GLOBAL_GITIGNORE="${USER_HOME}/.gitignore_global"
if [[ ! -f "$GLOBAL_GITIGNORE" ]]; then
    cat > "$GLOBAL_GITIGNORE" << 'GITIGNORE'
# OS
.DS_Store
Thumbs.db
Desktop.ini
*~

# Editors
.vscode/
.idea/
*.swp
*.swo
*~
.project
.settings/

# Environment
.env
.env.local
.env.*.local
.direnv/

# Runtime
__pycache__/
*.pyc
.mypy_cache/
.ruff_cache/
node_modules/
.npm/
.yarn/
.pnpm-store/
dist/
build/
target/

# Logs
*.log
npm-debug.log*
yarn-debug.log*
GITIGNORE
    chown "$REAL_USER:$REAL_USER" "$GLOBAL_GITIGNORE"
    as_user "git config --global core.excludesFile '${GLOBAL_GITIGNORE}'"
    ok "Global .gitignore_global created"
else
    skip "Global gitignore (already exists)"
fi
tick "Global gitignore"

# ── Tmux config ──────────────────────────────────────────────────────────────
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

# Modern terminal settings
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
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

# Status bar — clean and minimal
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
TMUX
    chown "$REAL_USER:$REAL_USER" "$TMUX_CONF"
    ok "tmux config (Dracula-themed, Ctrl-a prefix)"
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
    apt_each direnv
fi

# direnv default .envrc template
DIRENV_DIR="${USER_HOME}/.config/direnv"
mkdir -p "$DIRENV_DIR"
if [[ ! -f "${DIRENV_DIR}/direnvrc" ]]; then
    cat > "${DIRENV_DIR}/direnvrc" << 'DIRENVRC'
# Auto-detect and use Python venv
layout_python() {
    local python=${1:-python3}
    if [[ ! -d .venv ]]; then
        $python -m venv .venv
    fi
    source .venv/bin/activate
}

# Auto-detect and use Node version from .nvmrc
use_nvm() {
    local NVM_DIR="$HOME/.nvm"
    if [[ -f .nvmrc ]] && [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
        nvm use
    fi
}
DIRENVRC
    chown -R "$REAL_USER:$REAL_USER" "$DIRENV_DIR"
    ok "direnv config with Python/Node helpers"
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
    chown "$REAL_USER:$REAL_USER" "$EDITORCONFIG"
    ok "Global .editorconfig created"
else
    skip "Global .editorconfig (already exists)"
fi
tick "Global .editorconfig"

# ── SSH key helper ────────────────────────────────────────────────────────────
SSH_DIR="${USER_HOME}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "$REAL_USER:$REAL_USER" "$SSH_DIR"

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
    chown "$REAL_USER:$REAL_USER" "${SSH_DIR}/config"
    ok "SSH config created with sensible defaults"
else
    skip "SSH config (already exists)"
fi
tick "SSH config"

ok "Workspace config complete"
