# =============================================================================
# Module 08 — Editor Setup (VSCodium · Neovim · WezTerm · AI CLIs)
# =============================================================================
init_sub 6

# ── VSCodium (desktop profiles only) ─────────────────────────────────────────
if is_server_profile; then
    tick "VSCodium — skipped (server profile)"
else
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
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main"
            apt_quiet update
            apt_each codium
        fi
    fi

    # Ensure Codium launchers use --ozone-platform=x11 to prevent Wayland fractional scaling trembling
    for d in /usr/share/applications/codium*.desktop; do
        if [[ -f "$d" ]]; then
            bn="$(basename "$d")"
            mkdir -p "${USER_HOME}/.local/share/applications"
            sed 's|Exec=\(/usr/share/codium[^ ]*\)|Exec=\1 --ozone-platform=x11|g' "$d" > "${USER_HOME}/.local/share/applications/${bn}"
            chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "${USER_HOME}/.local/share/applications/${bn}"
        fi
    done

    # Copy VSCode settings to VSCodium if VSCode exists and VSCodium has no settings yet
    VSCODE_SETTINGS="${USER_HOME}/.config/Code/User/settings.json"
    CODIUM_USER_DIR="${USER_HOME}/.config/VSCodium/User"
    if [[ -f "$VSCODE_SETTINGS" ]] && [[ ! -f "${CODIUM_USER_DIR}/settings.json" ]]; then
        install -d -o "$REAL_USER" -g "${USER_GROUP:-$REAL_USER}" "$CODIUM_USER_DIR"
        for f in settings.json keybindings.json; do
            src="${USER_HOME}/.config/Code/User/${f}"
            [[ -f "$src" ]] && cp "$src" "${CODIUM_USER_DIR}/${f}" 2>/dev/null
        done
        [[ -d "${USER_HOME}/.config/Code/User/snippets" ]] && \
            cp -r "${USER_HOME}/.config/Code/User/snippets/." "${CODIUM_USER_DIR}/snippets/" 2>/dev/null
        chown -R "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "$CODIUM_USER_DIR"
        ok "VSCode settings mirrored to VSCodium"
    fi

    # Install common VSCodium extensions (Open VSX compatible; skip already installed)
    VSCODIUM_EXTS=(
        bradlc.vscode-tailwindcss
        catppuccin.catppuccin-vsc
        charliermarsh.ruff
        christian-kohler.path-intellisense
        dbaeumer.vscode-eslint
        donjayamanne.githistory
        dracula-theme.theme-dracula
        dsznajder.es7-react-js-snippets
        eamodio.gitlens
        editorconfig.editorconfig
        esbenp.prettier-vscode
        formulahendry.auto-rename-tag
        golang.go
        gruntfuggly.todo-tree
        humao.rest-client
        ms-python.python
        pkief.material-icon-theme
        redhat.java
        redhat.vscode-yaml
        rust-lang.rust-analyzer
        streetsidesoftware.code-spell-checker
        tamasfe.even-better-toml
        timonwong.shellcheck
        usernamehw.errorlens
        vscodevim.vim
        wayou.vscode-todo-highlight
    )

    if command -v codium &>/dev/null; then
        info "Checking VSCodium extensions..."
        _installed_exts=$(as_user "codium --list-extensions 2>/dev/null" | tr '[:upper:]' '[:lower:]' || echo "")
        for ext in "${VSCODIUM_EXTS[@]}"; do
            if echo "$_installed_exts" | grep -qx "${ext,,}"; then
                continue
            fi
            as_user "codium --install-extension '${ext}'" >> "$LOG_FILE" 2>&1 \
                && ok "  ${ext}" || warn "  ${ext} — skipped"
        done
        ok "VSCodium extensions up to date"
    fi
    tick "VSCodium + extensions"
fi

# ── Neovim ────────────────────────────────────────────────────────────────
if command -v nvim &>/dev/null; then
    skip "Neovim"
else
    info "Installing Neovim (latest stable)..."
    NVIM_ARCH=$(get_arch_x86_arm64) # x86_64 | arm64
    NVIM_TAG=$(_github_latest_tag "neovim/neovim")
    NVIM_URL=""
    [[ -n "$NVIM_TAG" ]] && NVIM_URL=$(_github_asset_url "neovim/neovim" "$NVIM_TAG" "nvim-linux-${NVIM_ARCH}.tar.gz")
    [[ -z "$NVIM_URL" ]] && NVIM_URL=$(_github_api_asset_url "neovim/neovim" "nvim-linux-${NVIM_ARCH}.tar.gz")
    if [[ -n "$NVIM_URL" ]]; then
        local_tmp=$(mktemp -d)
        if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "$NVIM_URL" | tar xz -C "$local_tmp" >> "$LOG_FILE" 2>&1; then
            NVIM_DIR=$(find "$local_tmp" -maxdepth 1 -type d -name 'nvim-linux*' | head -1)
            if [[ -d "$NVIM_DIR" ]]; then
                rm -rf /opt/nvim
                mv "$NVIM_DIR" /opt/nvim
                ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
                ok "Neovim installed to /opt/nvim"
            else
                warn "Neovim — extracted dir not found"
            fi
        else
            warn "Neovim download failed — falling back to distro package"
            pkg_install neovim
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

# ── WezTerm (desktop profiles only) ──────────────────────────────────────────
if is_server_profile; then
    tick "WezTerm — skipped (server profile)"
else
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
                if DEBIAN_FRONTEND=noninteractive apt-get "${APT_LOCK_OPT[@]}" -y -qq install wezterm >> "$LOG_FILE" 2>&1; then
                    _wez_installed=true && ok "WezTerm (apt)"
                fi
            fi
        fi

        if ! $_wez_installed && command -v flatpak &>/dev/null; then
            info "Trying WezTerm via Flatpak..."
            if flatpak install -y --noninteractive flathub org.wezfurlong.wezterm >> "$LOG_FILE" 2>&1; then
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

    # Loader + defaults are repo-owned; settings.json/user.lua stay untouched.
    if bash "${SCRIPT_DIR}/lib/wezterm-deploy.sh" "$USER_HOME" "$REAL_USER:${USER_GROUP:-$REAL_USER}" >> "$LOG_FILE" 2>&1; then
        ok "WezTerm config deployed (preferences in ~/.config/wezterm/settings.json)"
    else
        warn "WezTerm config deploy failed"
    fi

    # Append/upgrade bash hook for running command + cwd in WezTerm tab titles
    BASHRC="${USER_HOME}/.bashrc"
    touch "$BASHRC"
    chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "$BASHRC"

    if grep -q '# END linux-setup: wezterm-hook v2' "$BASHRC" 2>/dev/null; then
        skip "WezTerm bash hook (v2 already up to date)"
    else
        # Remove previous managed hook blocks (v1 or v2) before appending updated one.
        sed -i "/^# ── WezTerm tab title: show running command /,/^PROMPT_COMMAND=.*__wezterm_preexec_fired=0'$/d" "$BASHRC"
        sed -i "/^# BEGIN linux-setup: wezterm-hook/,/^# END linux-setup: wezterm-hook/d" "$BASHRC"

        cat >> "$BASHRC" << 'WEZTERM_HOOK'

# BEGIN linux-setup: wezterm-hook
if [[ "${TERM_PROGRAM:-}" == "WezTerm" ]]; then
    __wezterm_set_user_var() {
        printf "\033]1337;SetUserVar=%s=%s\007" "$1" "$(printf '%s' "$2" | base64 -w0)"
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
        local encoded_pwd="${PWD// /%20}"
        printf "\033]7;file://%s%s\033\\" "${HOSTNAME}" "${encoded_pwd}"
    }

    __wezterm_prompt_cmd() {
        __wezterm_osc7
        __wezterm_set_user_var cmd ""
        __wezterm_preexec_fired=0
    }

    if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        [[ " ${PROMPT_COMMAND[*]} " != *" __wezterm_prompt_cmd "* ]] && PROMPT_COMMAND+=(__wezterm_prompt_cmd)
    elif [[ "${PROMPT_COMMAND:-}" != *"__wezterm_prompt_cmd"* ]]; then
        PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND}; }__wezterm_prompt_cmd"
    fi
fi
# END linux-setup: wezterm-hook v2
WEZTERM_HOOK
        chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "$BASHRC"
        ok "WezTerm bash hook added/upgraded to v2 (guarded, base64 -w0, array-safe)"
    fi

    # Install standalone `wezterm-theme` (wezterm-studio) via pipx (PyPI with GitHub fallback)
    WEZTERM_STUDIO_GIT="git+https://github.com/mvsoares/wezterm-studio.git"
    if [[ -n "$REAL_USER" ]]; then
        if ! command -v pipx &>/dev/null; then
            pkg_install pipx
            as_user "pipx ensurepath" >> "$LOG_FILE" 2>&1 || true
        fi
        if command -v pipx &>/dev/null; then
            if as_user "pipx install --force wezterm-theme" >> "$LOG_FILE" 2>&1; then
                ok "wezterm-theme (wezterm-studio) installed/updated via pipx (PyPI)"
            elif as_user "pipx install --force '${WEZTERM_STUDIO_GIT}'" >> "$LOG_FILE" 2>&1; then
                ok "wezterm-theme (wezterm-studio) installed/updated via pipx (GitHub)"
            else
                warn "wezterm-theme pipx install failed — check ${LOG_FILE}"
            fi
        fi
    fi
    tick "WezTerm + config + wezterm-theme"
fi

# ── AI Code Assist CLIs ───────────────────────────────────────────────────
# Helper: check/run npm cleanly inside as_user (nvm.sh is not `set -u` safe in root's shell)
NVM_DIR="${USER_HOME}/.nvm"
_npm_prefix=""
[[ -s "${NVM_DIR}/nvm.sh" ]] && _npm_prefix="export NVM_DIR='${NVM_DIR}' && source '${NVM_DIR}/nvm.sh' && "
_has_npm() { as_user "${_npm_prefix}command -v npm" &>/dev/null; }

# Gemini CLI (Google)
if as_user "${_npm_prefix}command -v gemini" &>/dev/null; then
    skip "Gemini CLI"
elif _has_npm; then
    info "Installing Gemini CLI..."
    as_user "${_npm_prefix}npm install -g @google/gemini-cli" >> "$LOG_FILE" 2>&1 \
        && ok "Gemini CLI installed" || warn "Gemini CLI install failed — run: npm install -g @google/gemini-cli"
else
    warn "Gemini CLI skipped — npm not available (install nvm/node first)"
fi
tick "Gemini CLI"

# Claude Code (Anthropic — prefer official native installer, fallback to npm)
if as_user "${_npm_prefix}command -v claude" &>/dev/null; then
    skip "Claude Code"
else
    info "Installing Claude Code CLI..."
    if as_user "curl -fsSL --connect-timeout 15 --max-time 180 https://claude.ai/install.sh | bash" >> "$LOG_FILE" 2>&1; then
        ok "Claude Code installed (native)"
    elif _has_npm; then
        as_user "${_npm_prefix}npm install -g @anthropic-ai/claude-code" >> "$LOG_FILE" 2>&1 \
            && ok "Claude Code installed (npm)" || warn "Claude Code install failed"
    else
        warn "Claude Code install failed — see ${LOG_FILE}"
    fi
fi
tick "Claude Code CLI"

# Codex CLI (OpenAI)
if as_user "${_npm_prefix}command -v codex" &>/dev/null; then
    skip "Codex CLI"
elif _has_npm; then
    info "Installing OpenAI Codex CLI..."
    as_user "${_npm_prefix}npm install -g @openai/codex" >> "$LOG_FILE" 2>&1 \
        && ok "Codex CLI installed" || warn "Codex CLI install failed — run: npm install -g @openai/codex"
else
    warn "Codex CLI skipped — npm not available (install nvm/node first)"
fi
tick "Codex CLI"

ok "Editor setup complete"
