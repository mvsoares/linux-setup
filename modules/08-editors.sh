# =============================================================================
# Module 08 — Editor Setup (VSCodium · Neovim · WezTerm)
# =============================================================================
init_sub 8

# ── VSCodium ──────────────────────────────────────────────────────────────
if command -v codium &>/dev/null; then
    skip "VSCodium"
else
    if is_fedora; then
        add_dnf_repo "VSCodium" \
"[gitlab.com_paulcarroty_vscodium_repo]
name=download.vscodium.com
baseurl=https://download.vscodium.com/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
metadata_expire=1h" \
            "/etc/yum.repos.d/vscodium.repo" "https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg"
        dnf_each codium
    else
        add_apt_repo "VSCodium" "https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg" \
            "/usr/share/keyrings/vscodium-archive-keyring.gpg" \
            "/etc/apt/sources.list.d/vscodium.list" \
            "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main"
        apt_quiet update
        apt_each codium
    fi
fi

# Copy VSCode settings to VSCodium if VSCode exists and VSCodium has no settings yet
VSCODE_SETTINGS="${USER_HOME}/.config/Code/User/settings.json"
CODIUM_USER_DIR="${USER_HOME}/.config/VSCodium/User"
if [[ -f "$VSCODE_SETTINGS" ]] && [[ ! -f "${CODIUM_USER_DIR}/settings.json" ]]; then
    install -d -o "$REAL_USER" -g "$REAL_USER" "$CODIUM_USER_DIR"
    for f in settings.json keybindings.json; do
        src="${USER_HOME}/.config/Code/User/${f}"
        [[ -f "$src" ]] && cp "$src" "${CODIUM_USER_DIR}/${f}" 2>/dev/null
    done
    [[ -d "${USER_HOME}/.config/Code/User/snippets" ]] && \
        cp -r "${USER_HOME}/.config/Code/User/snippets/." "${CODIUM_USER_DIR}/snippets/" 2>/dev/null
    chown -R "$REAL_USER:$REAL_USER" "$CODIUM_USER_DIR"
    ok "VSCode settings mirrored to VSCodium"
fi

# Install common VSCodium extensions
VSCODIUM_EXTS=(
    bradlc.vscode-tailwindcss
    catppuccin.catppuccin-vsc
    christian-kohler.path-intellisense
    dbaeumer.vscode-eslint
    dracula-theme.theme-dracula
    dsznajder.es7-react-js-snippets
    eamodio.gitlens
    esbenp.prettier-vscode
    formulahendry.auto-rename-tag
    golang.go
    gruntfuggly.todo-tree
    humao.rest-client
    mhutchie.git-graph
    pkief.material-icon-theme
    rangav.vscode-thunder-client
    redhat.vscode-yaml
    streetsidesoftware.code-spell-checker
    usernamehw.errorlens
    vscodevim.vim
    wayou.vscode-todo-highlight
    rust-lang.rust-analyzer
    tamasfe.even-better-toml
)

if command -v codium &>/dev/null; then
    info "Installing VSCodium extensions..."
    for ext in "${VSCODIUM_EXTS[@]}"; do
        as_user "codium --install-extension '${ext}' --force" >> "$LOG_FILE" 2>&1 \
            && ok "  ${ext}" || true
    done
fi
tick "VSCodium + extensions"

# ── Neovim ────────────────────────────────────────────────────────────────
if command -v nvim &>/dev/null; then
    skip "Neovim"
else
    info "Installing Neovim (latest stable)..."
    NVIM_URL=$(_gh_api_curl "https://api.github.com/repos/neovim/neovim/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "nvim-linux-$(uname -m).tar.gz" | head -1 | cut -d'"' -f4 || echo "")
    if [[ -n "$NVIM_URL" ]]; then
        local_tmp=$(mktemp -d)
        curl -fsSL "$NVIM_URL" | tar xz -C "$local_tmp" >> "$LOG_FILE" 2>&1
        NVIM_DIR=$(ls -d "$local_tmp"/nvim-linux* 2>/dev/null | head -1)
        if [[ -d "$NVIM_DIR" ]]; then
            rm -rf /opt/nvim
            mv "$NVIM_DIR" /opt/nvim
            ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
            ok "Neovim installed to /opt/nvim"
        else
            warn "Neovim — extracted dir not found"
        fi
        rm -rf "$local_tmp"
    else
        pkg_install neovim
    fi
fi

# Kickstart.nvim (sensible default config)
NVIM_CFG="${USER_HOME}/.config/nvim"
if [[ -d "$NVIM_CFG" ]]; then
    skip "Neovim config (already exists)"
else
    info "Installing kickstart.nvim config..."
    as_user "git clone --depth=1 https://github.com/nvim-lua/kickstart.nvim.git '${NVIM_CFG}'" \
        >> "$LOG_FILE" 2>&1 && ok "kickstart.nvim installed" || warn "kickstart.nvim clone failed"
fi
tick "Neovim + kickstart.nvim"

# ── WezTerm ──────────────────────────────────────────────────────────────
if command -v wezterm &>/dev/null || flatpak list 2>/dev/null | grep -q org.wezfurlong.wezterm; then
    skip "WezTerm"
else
    info "Installing WezTerm..."
    _wez_installed=false

    if is_fedora; then
        # Try COPR repo first (native), fall back to Flatpak
        if dnf copr enable -y wezfurlong/wezterm-nightly >> "$LOG_FILE" 2>&1 \
                && dnf install -y wezterm >> "$LOG_FILE" 2>&1; then
            _wez_installed=true && ok "WezTerm (COPR)"
        fi
    else
        # Try apt repo first (native), fall back to Flatpak
        if add_apt_repo "WezTerm" "https://apt.fury.io/wez/gpg.key" \
            "/usr/share/keyrings/wezterm-fury.gpg" \
            "/etc/apt/sources.list.d/wezterm.list" \
            "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *"; then
            apt_quiet update
            if apt-get install -y -qq wezterm >> "$LOG_FILE" 2>&1; then
                _wez_installed=true && ok "WezTerm (apt)"
            fi
        fi
    fi

    if ! $_wez_installed && command -v flatpak &>/dev/null; then
        info "Trying WezTerm via Flatpak..."
        if flatpak install -y flathub org.wezfurlong.wezterm >> "$LOG_FILE" 2>&1; then
            # Create wrapper so 'command -v wezterm' works
            cat > /usr/local/bin/wezterm << 'WEZWRAP'
#!/bin/sh
exec flatpak run org.wezfurlong.wezterm "$@"
WEZWRAP
            chmod +x /usr/local/bin/wezterm
            ok "WezTerm (Flatpak)"
            _wez_installed=true
        fi
    fi

    $_wez_installed || warn "WezTerm install failed"
fi

WEZTERM_CFG="${USER_HOME}/.config/wezterm/wezterm.lua"
if [[ -f "$WEZTERM_CFG" ]]; then
    if grep -q "'JetBrains Mono'" "$WEZTERM_CFG"; then
        sed -i "s/'JetBrains Mono'/'JetBrainsMono Nerd Font'/g" "$WEZTERM_CFG"
        ok "WezTerm font fixed: JetBrains Mono -> JetBrainsMono Nerd Font"
    else
        ok "WezTerm config already present"
    fi
else
    info "Deploying WezTerm config..."
    install -d -o "$REAL_USER" -g "$REAL_USER" "$(dirname "$WEZTERM_CFG")"
    cp "${SCRIPT_DIR}/lib/wezterm.lua" "$WEZTERM_CFG"
    chown "$REAL_USER:$REAL_USER" "$WEZTERM_CFG"
    ok "WezTerm config deployed (Monokai Remastered, JetBrainsMono Nerd Font)"
fi

# Append/upgrade bash hook for running command + cwd in WezTerm tab titles
BASHRC="${USER_HOME}/.bashrc"
touch "$BASHRC"
chown "$REAL_USER:$REAL_USER" "$BASHRC"

if grep -q '__wezterm_set_user_var' "$BASHRC" && grep -q '__wezterm_osc7' "$BASHRC"; then
    skip "WezTerm bash hook (already up to date)"
else
    # Remove previous managed hook block before appending updated one.
    sed -i "/^# ── WezTerm tab title: show running command /,/^PROMPT_COMMAND=.*__wezterm_preexec_fired=0'$/d" "$BASHRC"

    cat >> "$BASHRC" << 'WEZTERM_HOOK'

# ── WezTerm tab title: show running command ──────────────────────────────────
__wezterm_set_user_var() {
    printf "\033]1337;SetUserVar=%s=%s\007" "$1" "$(printf '%s' "$2" | base64)"
}

__wezterm_preexec_fired=1
__wezterm_debug() {
    [[ "$__wezterm_preexec_fired" == "1" ]] && return
    [[ -n "${COMP_LINE:-}" ]] && return
    local cmd="${BASH_COMMAND%% *}"
    [[ "$cmd" == __* ]] && return   # skip internal shell functions (e.g. __fzf_history)
    __wezterm_preexec_fired=1
    cmd="${cmd##*/}"
    __wezterm_set_user_var cmd "$cmd"
}
trap '__wezterm_debug' DEBUG

__wezterm_osc7() {
    printf "\033]7;file://%s%s\033\\" "${HOSTNAME}" "${PWD}"
}

PROMPT_COMMAND="${PROMPT_COMMAND:-}"'; __wezterm_osc7; __wezterm_set_user_var cmd ""; __wezterm_preexec_fired=0'
WEZTERM_HOOK
    ok "WezTerm bash hook added/updated (process name + cwd in tab titles)"
fi
tick "WezTerm + config"

# ── AI Code Assist CLIs ───────────────────────────────────────────────────
# Cursor CLI Agent (Anysphere)
if command -v agent &>/dev/null; then
    skip "Cursor CLI $(agent --version 2>/dev/null | head -1 || true)"
else
    info "Installing Cursor CLI Agent..."
    as_user "curl -fsSL https://cursor.com/install -o /tmp/cursor_install.sh && bash /tmp/cursor_install.sh && rm -f /tmp/cursor_install.sh" >> "$LOG_FILE" 2>&1 \
        && ok "Cursor CLI Agent installed" || warn "Cursor CLI install failed — run: curl https://cursor.com/install -fsS | bash"
fi
tick "Cursor CLI Agent"

# Source nvm so npm is available (installed by module 07 as the real user)
NVM_DIR="${USER_HOME}/.nvm"
if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    export NVM_DIR
    # shellcheck source=/dev/null
    source "${NVM_DIR}/nvm.sh"
fi

# Gemini CLI (Google)
if command -v gemini &>/dev/null; then
    skip "Gemini CLI $(gemini --version 2>/dev/null | head -1 || true)"
elif command -v npm &>/dev/null; then
    info "Installing Gemini CLI..."
    as_user "source '${NVM_DIR}/nvm.sh' && npm install -g @google/gemini-cli" >> "$LOG_FILE" 2>&1 \
        && ok "Gemini CLI installed" || warn "Gemini CLI install failed — run: npm install -g @google/gemini-cli"
else
    warn "Gemini CLI skipped — npm not available (install nvm/node first)"
fi
tick "Gemini CLI"

# Claude Code (Anthropic)
if command -v claude &>/dev/null; then
    skip "Claude Code $(claude --version 2>/dev/null | head -1 || true)"
elif command -v npm &>/dev/null; then
    info "Installing Claude Code CLI..."
    as_user "source '${NVM_DIR}/nvm.sh' && npm install -g @anthropic-ai/claude-code" >> "$LOG_FILE" 2>&1 \
        && ok "Claude Code installed" || warn "Claude Code install failed — run: npm install -g @anthropic-ai/claude-code"
else
    warn "Claude Code skipped — npm not available (install nvm/node first)"
fi
tick "Claude Code CLI"

# Codex CLI (OpenAI)
if command -v codex &>/dev/null; then
    skip "Codex CLI $(codex --version 2>/dev/null | head -1 || true)"
elif command -v npm &>/dev/null; then
    info "Installing OpenAI Codex CLI..."
    as_user "source '${NVM_DIR}/nvm.sh' && npm install -g @openai/codex" >> "$LOG_FILE" 2>&1 \
        && ok "Codex CLI installed" || warn "Codex CLI install failed — run: npm install -g @openai/codex"
else
    warn "Codex CLI skipped — npm not available (install nvm/node first)"
fi
tick "Codex CLI"

ok "Editor setup complete"
