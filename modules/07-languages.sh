# =============================================================================
# Module 07 — Language Runtimes & Version Managers
# =============================================================================
init_sub 7

# ── nvm (Node Version Manager) ───────────────────────────────────────────────
NVM_DIR="${USER_HOME}/.nvm"
if [[ -d "$NVM_DIR" ]]; then
    skip "nvm"
else
    info "Installing nvm..."
    NVM_VER=$(curl -fsSL "https://api.github.com/repos/nvm-sh/nvm/releases/latest" 2>/dev/null \
        | grep tag_name | cut -d'"' -f4)
    [[ -z "$NVM_VER" ]] && NVM_VER="v0.40.1"
    as_user "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VER}/install.sh | bash" \
        >> "$LOG_FILE" 2>&1 && ok "nvm ${NVM_VER}" || warn "nvm install failed"
    # Install latest LTS node via nvm
    if [[ -d "$NVM_DIR" ]]; then
        as_user "export NVM_DIR='${NVM_DIR}' && source '${NVM_DIR}/nvm.sh' && nvm install --lts" \
            >> "$LOG_FILE" 2>&1 && ok "Node LTS installed via nvm" || warn "Node LTS install failed"
    fi
fi
tick "nvm + Node LTS"

# ── pyenv ─────────────────────────────────────────────────────────────────────
PYENV_ROOT="${USER_HOME}/.pyenv"
if [[ -d "$PYENV_ROOT" ]]; then
    skip "pyenv"
else
    info "Installing pyenv build dependencies..."
    apt_quiet install \
        make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget llvm \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
        libffi-dev liblzma-dev

    info "Installing pyenv..."
    as_user "curl -fsSL https://pyenv.run | bash" >> "$LOG_FILE" 2>&1 \
        && ok "pyenv installed" || warn "pyenv install failed"

    # Add to profile if not present
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
    apt_each pipx
    as_user "pipx ensurepath" >> "$LOG_FILE" 2>&1 || true
fi
tick "pyenv + pipx"

# ── Rust (rustup) ────────────────────────────────────────────────────────────
if [[ -d "${USER_HOME}/.rustup" ]] || as_user "command -v rustup" &>/dev/null; then
    skip "rustup"
else
    info "Installing Rust via rustup..."
    as_user "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" \
        >> "$LOG_FILE" 2>&1 && ok "Rust installed via rustup" || warn "Rust install failed"
fi
tick "Rust (rustup)"

# ── Go ────────────────────────────────────────────────────────────────────────
if command -v go &>/dev/null; then
    skip "Go ($(go version 2>/dev/null | awk '{print $3}'))"
else
    info "Installing latest Go..."
    GO_VER=$(curl -fsSL "https://go.dev/VERSION?m=text" 2>/dev/null | head -1)
    if [[ -n "$GO_VER" ]]; then
        GO_ARCH=$(dpkg --print-architecture)
        rm -rf /usr/local/go
        curl -fsSL "https://go.dev/dl/${GO_VER}.linux-${GO_ARCH}.tar.gz" \
            | tar xz -C /usr/local >> "$LOG_FILE" 2>&1 \
            && ok "Go ${GO_VER} installed to /usr/local/go" || warn "Go install failed"

        # Add to path globally
        if [[ ! -f /etc/profile.d/98-golang.sh ]]; then
            cat > /etc/profile.d/98-golang.sh << 'GOPATH'
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
GOPATH
            chmod +x /etc/profile.d/98-golang.sh
        fi
    else
        warn "Go — could not determine latest version"
    fi
fi
tick "Go (latest)"

# ── SDKMAN (Java, Gradle, Maven, Kotlin) ─────────────────────────────────────
SDKMAN_DIR="${USER_HOME}/.sdkman"
if [[ -d "$SDKMAN_DIR" ]]; then
    skip "SDKMAN"
else
    info "Installing SDKMAN..."
    as_user "curl -fsSL 'https://get.sdkman.io?rcupdate=false' | bash" \
        >> "$LOG_FILE" 2>&1 && ok "SDKMAN installed" || warn "SDKMAN install failed"
fi
tick "SDKMAN (Java/Gradle/Maven/Kotlin)"

# ── JDK 21 + Maven via SDKMAN ────────────────────────────────────────────────
if [[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
    # JDK 21 (Temurin)
    if as_user "source '${SDKMAN_DIR}/bin/sdkman-init.sh' && sdk list java 2>/dev/null | grep -q '21\..*tem.*installed'" 2>/dev/null; then
        skip "JDK 21 (Temurin)"
    else
        info "Installing JDK 21 (Temurin)..."
        JDK21_ID=$(as_user "source '${SDKMAN_DIR}/bin/sdkman-init.sh' && sdk list java 2>/dev/null" \
            | grep -oE '[0-9]+\.[0-9.]+-tem' | grep '^21\.' | head -1 | tr -d '[:space:]')
        if [[ -n "$JDK21_ID" ]]; then
            as_user "source '${SDKMAN_DIR}/bin/sdkman-init.sh' && sdk install java '${JDK21_ID}'" \
                >> "$LOG_FILE" 2>&1 && ok "JDK 21 (${JDK21_ID})" || warn "JDK 21 install failed"
        else
            warn "JDK 21 — could not find Temurin 21 in SDKMAN list"
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
    # ── Java + Maven env vars in .bashrc ─────────────────────────────────────
    BASHRC="${USER_HOME}/.bashrc"
    if ! grep -q 'JAVA_HOME' "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'JAVABLOCK'

# ── Java / Maven (SDKMAN managed) ─────────────────────────────────────────────
export JAVA_HOME="${HOME}/.sdkman/candidates/java/current"
export MAVEN_HOME="${HOME}/.sdkman/candidates/maven/current"
export M2_HOME="${MAVEN_HOME}"
export PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"
JAVABLOCK
        chown "$REAL_USER:$REAL_USER" "$BASHRC"
        ok "JAVA_HOME + MAVEN_HOME + M2_HOME added to .bashrc"
    else
        skip "Java/Maven env vars (already in .bashrc)"
    fi
else
    warn "SDKMAN not available — skipping JDK 21 and Maven (install manually with: sdk install java 21-tem && sdk install maven)"
fi
tick "JDK 21 (Temurin) + Maven"

# ── Common pipx tools ────────────────────────────────────────────────────────
if command -v pipx &>/dev/null; then
    info "Installing common Python CLI tools via pipx..."
    for tool in black ruff mypy poetry httpie tldr cookiecutter; do
        as_user "pipx install --force ${tool}" >> "$LOG_FILE" 2>&1 && ok "pipx: ${tool}" || warn "pipx: ${tool} failed"
    done
fi
tick "Python CLI tools via pipx"

ok "Language runtimes & version managers complete"
