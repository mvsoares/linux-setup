# =============================================================================
# Module 08 — Editor Setup (Cursor · VSCodium · Neovim)
# =============================================================================
init_sub 4

# ── VSCodium ──────────────────────────────────────────────────────────────────
if command -v codium &>/dev/null; then
    skip "VSCodium"
else
    info "Adding VSCodium repo..."
    curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --batch --yes --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg >> "$LOG_FILE" 2>&1 || warn "VSCodium key failed"
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] \
https://download.vscodium.com/debs vscodium main" \
        > /etc/apt/sources.list.d/vscodium.list
    apt_quiet update
    apt_each codium
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

# ── Cursor IDE settings ──────────────────────────────────────────────────────
CURSOR_SETTINGS="${USER_HOME}/.config/Cursor/User/settings.json"
if [[ -f "$CURSOR_SETTINGS" ]]; then
    skip "Cursor IDE settings (already exists)"
else
    info "Configuring Cursor IDE..."
    install -d -o "$REAL_USER" -g "$REAL_USER" "$(dirname "$CURSOR_SETTINGS")"

    cat > "$CURSOR_SETTINGS" << 'CURSOR_JSON'
{
    "window.commandCenter": true,

    "editor.fontFamily": "'JetBrainsMono Nerd Font', 'Monaspace Neon', 'Fira Code', 'Geist Mono', monospace",
    "editor.fontLigatures": "'calt', 'liga', 'ss01', 'ss02', 'ss03', 'ss04', 'ss05'",
    "editor.fontSize": 14,
    "editor.lineHeight": 1.6,
    "editor.cursorBlinking": "smooth",
    "editor.cursorSmoothCaretAnimation": "on",
    "editor.smoothScrolling": true,
    "editor.minimap.enabled": false,
    "editor.renderWhitespace": "boundary",
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": "active",
    "editor.stickyScroll.enabled": true,
    "editor.linkedEditing": true,
    "editor.formatOnSave": true,
    "editor.formatOnPaste": true,
    "editor.tabSize": 2,
    "editor.detectIndentation": true,
    "editor.wordWrap": "off",
    "editor.suggestSelection": "first",
    "editor.inlineSuggest.enabled": true,
    "editor.unicodeHighlight.allowedLocales": { "pt-br": true },

    "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font'",
    "terminal.integrated.fontSize": 13,
    "terminal.integrated.lineHeight": 1.2,
    "terminal.integrated.cursorBlinking": true,
    "terminal.integrated.scrollback": 10000,
    "terminal.integrated.defaultProfile.linux": "bash",

    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "files.exclude": {
        "**/.git": true,
        "**/.DS_Store": true,
        "**/node_modules": true,
        "**/__pycache__": true,
        "**/.venv": true,
        "**/.mypy_cache": true
    },

    "workbench.startupEditor": "none",
    "workbench.tree.indent": 16,
    "workbench.editor.enablePreview": false,
    "workbench.list.smoothScrolling": true,
    "workbench.colorTheme": "Dracula",
    "workbench.iconTheme": "material-icon-theme",
    "workbench.productIconTheme": "material-product-icons",

    "explorer.confirmDelete": false,
    "explorer.confirmDragAndDrop": false,
    "explorer.compactFolders": false,

    "git.autofetch": true,
    "git.confirmSync": false,
    "git.enableSmartCommit": true,

    "search.exclude": {
        "**/node_modules": true,
        "**/dist": true,
        "**/build": true,
        "**/.next": true,
        "**/target": true,
        "**/.venv": true
    }
}
CURSOR_JSON
    chown "$REAL_USER:$REAL_USER" "$CURSOR_SETTINGS"
    ok "Cursor IDE settings configured"
fi
tick "Cursor IDE settings"

# ── Neovim ────────────────────────────────────────────────────────────────────
if command -v nvim &>/dev/null; then
    skip "Neovim"
else
    info "Installing Neovim (latest stable)..."
    NVIM_URL=$(curl -sSf "https://api.github.com/repos/neovim/neovim/releases/latest" 2>/dev/null \
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
        apt_each neovim
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

# ── WezTerm config ────────────────────────────────────────────────────────────
WEZTERM_CFG="${USER_HOME}/.config/wezterm/wezterm.lua"
if [[ -f "$WEZTERM_CFG" ]]; then
    if grep -q "'JetBrains Mono'" "$WEZTERM_CFG"; then
        sed -i "s/'JetBrains Mono'/'JetBrainsMono Nerd Font'/g" "$WEZTERM_CFG"
        ok "WezTerm font fixed: JetBrains Mono → JetBrainsMono Nerd Font"
    else
        ok "WezTerm font already correct"
    fi
else
    info "WezTerm config not found — skipping font fix"
fi
tick "WezTerm config"

ok "Editor setup complete"
