# =============================================================================
# Module 07 — Language Runtimes & Version Managers
# =============================================================================
init_sub 8

# ── nvm (Node Version Manager) + Node LTS + pnpm ─────────────────────────────
NVM_DIR="${USER_HOME}/.nvm"
if [[ -d "$NVM_DIR" ]]; then
    skip "nvm"
else
    info "Installing nvm..."
    NVM_VER=$(_github_latest_tag "nvm-sh/nvm")
    [[ -z "$NVM_VER" ]] && NVM_VER="v0.40.3"
    as_user "curl -fsSL --connect-timeout 15 --max-time 120 https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VER}/install.sh -o /tmp/nvm_install.sh && bash /tmp/nvm_install.sh && rm -f /tmp/nvm_install.sh" \
        >> "$LOG_FILE" 2>&1 && ok "nvm ${NVM_VER}" || warn "nvm install failed"
    # Install latest LTS node via nvm
    if [[ -d "$NVM_DIR" ]]; then
        as_user "export NVM_DIR='${NVM_DIR}' && source '${NVM_DIR}/nvm.sh' && nvm install --lts && nvm alias default 'lts/*'" \
            >> "$LOG_FILE" 2>&1 && ok "Node LTS installed via nvm" || warn "Node LTS install failed"
    fi
fi

# Enable pnpm via corepack if available
if [[ -s "${NVM_DIR}/nvm.sh" ]] && ! as_user "export NVM_DIR='${NVM_DIR}' && source '${NVM_DIR}/nvm.sh' && command -v pnpm" &>/dev/null; then
    as_user "export NVM_DIR='${NVM_DIR}' && source '${NVM_DIR}/nvm.sh' && npm install -g pnpm" \
        >> "$LOG_FILE" 2>&1 && ok "pnpm installed" || warn "pnpm install skipped"
fi
tick "nvm + Node LTS + pnpm"

# ── uv (Astral — ultra-fast Python, venv & tool manager) ─────────────────────
if [[ -x "${USER_HOME}/.local/bin/uv" ]] || command -v uv &>/dev/null; then
    skip "uv"
else
    info "Installing uv (Astral Python manager)..."
    as_user "curl -LsSf --connect-timeout 15 --max-time 120 https://astral.sh/uv/install.sh | sh" \
        >> "$LOG_FILE" 2>&1 && ok "uv installed" || warn "uv install failed"
fi
tick "uv (Astral Python manager)"

# ── pyenv + pipx ──────────────────────────────────────────────────────────────
PYENV_ROOT="${USER_HOME}/.pyenv"
if [[ -d "$PYENV_ROOT" ]]; then
    skip "pyenv"
else
    info "Installing pyenv build dependencies..."
    if is_fedora; then
        dnf_quiet install \
            make gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel \
            openssl-devel tk-devel libffi-devel xz-devel libuuid-devel gdbm-devel libnsl2-devel
    else
        # Ubuntu 24+/26+ replaced libncursesw5-dev with libncurses-dev
        apt_quiet install \
            make build-essential libssl-dev zlib1g-dev \
            libbz2-dev libreadline-dev libsqlite3-dev wget llvm \
            libncurses-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
            libffi-dev liblzma-dev
    fi

    info "Installing pyenv..."
    as_user "curl -fsSL --connect-timeout 15 --max-time 120 https://pyenv.run -o /tmp/pyenv_install.sh && bash /tmp/pyenv_install.sh && rm -f /tmp/pyenv_install.sh" >> "$LOG_FILE" 2>&1 \
        && ok "pyenv installed" || warn "pyenv install failed"

    # Add to .bashrc if not present
    PYENV_INIT="${USER_HOME}/.bashrc"
    if [[ -f "$PYENV_INIT" ]] && ! grep -q 'PYENV_ROOT' "$PYENV_INIT"; then
        cat >> "$PYENV_INIT" << 'PYENV_BLOCK'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv &>/dev/null && eval "$(pyenv init - 2>/dev/null)" 2>/dev/null
PYENV_BLOCK
        chown "$REAL_USER:$REAL_USER" "$PYENV_INIT"
    fi
    # Migrate: ensure both 2>/dev/null are present (suppresses uutils readlink errors on Ubuntu 26+)
    if [[ -f "$PYENV_INIT" ]] && grep -q 'pyenv init' "$PYENV_INIT" \
            && ! grep -q 'pyenv init - 2>/dev/null)" 2>/dev/null' "$PYENV_INIT"; then
        sed -i '/pyenv init/s|.*pyenv init.*|command -v pyenv \&>/dev/null \&\& eval "$(pyenv init - 2>/dev/null)" 2>/dev/null|' "$PYENV_INIT"
    fi
fi

# pipx — install Python CLI tools in isolated envs
if command -v pipx &>/dev/null; then
    skip "pipx"
else
    pkg_install pipx
    as_user "pipx ensurepath" >> "$LOG_FILE" 2>&1 || true
fi
tick "pyenv + pipx"

# ── Rust (rustup) ────────────────────────────────────────────────────────────
if [[ -d "${USER_HOME}/.rustup" ]] || as_user "command -v rustup" &>/dev/null; then
    skip "rustup"
else
    info "Installing Rust via rustup..."
    as_user "curl --proto '=https' --tlsv1.2 -sSf --connect-timeout 15 --max-time 300 https://sh.rustup.rs -o /tmp/rustup_install.sh && sh /tmp/rustup_install.sh -y && rm -f /tmp/rustup_install.sh" \
        >> "$LOG_FILE" 2>&1 && ok "Rust installed via rustup" || warn "Rust install failed"
fi
tick "Rust (rustup)"

# ── Go ────────────────────────────────────────────────────────────────────────
if command -v go &>/dev/null; then
    skip "Go ($(go version 2>/dev/null | awk '{print $3}'))"
else
    info "Installing latest Go..."
    GO_VER=$(curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://go.dev/VERSION?m=text" 2>/dev/null | head -1 || echo "")
    if [[ -n "$GO_VER" ]]; then
        GO_ARCH=$(get_arch)
        rm -rf /usr/local/go
        curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://go.dev/dl/${GO_VER}.linux-${GO_ARCH}.tar.gz" \
            | tar xz -C /usr/local >> "$LOG_FILE" 2>&1 \
            && ok "Go ${GO_VER} installed to /usr/local/go" || warn "Go install failed"
    else
        warn "Go — could not determine latest version"
    fi
fi
# Ensure Go PATH is loaded in both login (/etc/profile.d) and non-login (~/.bashrc.d) shells
read -r -d '' GOLANG_PATH << 'GOPATH' || true
case ":$PATH:" in *":/usr/local/go/bin:"*) ;; *) export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH" ;; esac
GOPATH
install_shell_snippet "98-golang.sh" "$GOLANG_PATH"
tick "Go (latest)"

# ── SDKMAN (Java, Gradle, Maven, Kotlin) ─────────────────────────────────────
SDKMAN_DIR="${USER_HOME}/.sdkman"
if [[ -d "$SDKMAN_DIR" ]]; then
    skip "SDKMAN"
else
    info "Installing SDKMAN..."
    as_user "curl -fsSL --connect-timeout 15 --max-time 120 'https://get.sdkman.io?rcupdate=false' -o /tmp/sdkman_install.sh && bash /tmp/sdkman_install.sh && rm -f /tmp/sdkman_install.sh" \
        >> "$LOG_FILE" 2>&1 && ok "SDKMAN installed" || warn "SDKMAN install failed"
fi
tick "SDKMAN (Java/Gradle/Maven/Kotlin)"

# ── JDK 25 + Maven via SDKMAN ────────────────────────────────────────────────
if [[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
    # JDK 25 (Temurin)
    if as_user "source '${SDKMAN_DIR}/bin/sdkman-init.sh' && sdk list java 2>/dev/null | grep -q '25\..*tem.*installed'" 2>/dev/null; then
        skip "JDK 25 (Temurin)"
    else
        info "Installing JDK 25 (Temurin)..."
        JDK25_ID=$(as_user "source '${SDKMAN_DIR}/bin/sdkman-init.sh' && sdk list java 2>/dev/null" \
            | grep -oE '[0-9]+\.[0-9.]+(\+[0-9]+)?-tem' | grep '^25\.' | head -1 | tr -d '[:space:]')
        if [[ -n "$JDK25_ID" ]]; then
            as_user "source '${SDKMAN_DIR}/bin/sdkman-init.sh' && sdk install java '${JDK25_ID}'" \
                >> "$LOG_FILE" 2>&1 && ok "JDK 25 (${JDK25_ID})" || warn "JDK 25 install failed"
        else
            warn "JDK 25 — could not find Temurin 25 in SDKMAN list"
        fi
    fi

    # Maven
    if as_user "source '${SDKMAN_DIR}/bin/sdkman-init.sh' && sdk list maven 2>/dev/null | grep -q 'installed'" 2>/dev/null; then
        skip "Maven"
    else
        info "Installing Maven..."
        as_user "source '${SDKMAN_DIR}/bin/sdkman-init.sh' && sdk install maven" \
            >> "$LOG_FILE" 2>&1 && ok "Maven installed" || warn "Maven install failed"
    fi

    # ── Java + Maven + SDKMAN init in .bashrc ────────────────────────────────
    BASHRC="${USER_HOME}/.bashrc"
    if ! grep -q 'JAVA_HOME' "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'JAVABLOCK'

# ── Java / Maven (SDKMAN managed) ─────────────────────────────────────────────
export SDKMAN_DIR="${HOME}/.sdkman"
[[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"
export JAVA_HOME="${HOME}/.sdkman/candidates/java/current"
export MAVEN_HOME="${HOME}/.sdkman/candidates/maven/current"
export M2_HOME="${MAVEN_HOME}"
export PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"
JAVABLOCK
        chown "$REAL_USER:$REAL_USER" "$BASHRC"
        ok "SDKMAN init + JAVA_HOME + MAVEN_HOME added to .bashrc"
    elif ! grep -q 'sdkman-init.sh' "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'SDKINIT'

# SDKMAN shell init
export SDKMAN_DIR="${HOME}/.sdkman"
[[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"
SDKINIT
        chown "$REAL_USER:$REAL_USER" "$BASHRC"
        ok "SDKMAN init added to .bashrc"
    else
        skip "Java/Maven/SDKMAN env vars (already in .bashrc)"
    fi
else
    warn "SDKMAN not available — skipping JDK 25 and Maven (install manually with: sdk install java 25-tem && sdk install maven)"
fi
tick "JDK 25 (Temurin) + Maven + SDKMAN init"

# ── Common pipx tools (skip already installed; ruff replaces black, tealdeer replaces tldr)
if command -v pipx &>/dev/null; then
    info "Installing common Python CLI tools via pipx..."
    _installed_pipx=$(as_user "pipx list --short 2>/dev/null" | awk '{print $1}' || echo "")
    for tool in ruff mypy poetry httpie cookiecutter; do
        if echo "$_installed_pipx" | grep -qx "$tool"; then
            skip "pipx: ${tool}"
        else
            as_user "pipx install ${tool}" >> "$LOG_FILE" 2>&1 && ok "pipx: ${tool}" || warn "pipx: ${tool} failed"
        fi
    done
fi
tick "Python CLI tools via pipx (ruff · mypy · poetry · httpie · cookiecutter)"

ok "Language runtimes & version managers complete"
