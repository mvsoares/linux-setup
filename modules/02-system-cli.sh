# =============================================================================
# Module 02 — System Utilities & Modern CLI Tools
# =============================================================================
init_sub 7

ARCH_GO=$(get_arch)           # amd64 | arm64
ARCH_RUST=$(get_arch_rust)    # x86_64 | aarch64
ARCH_ALT=$(get_arch_x86_arm64) # x86_64 | arm64

info "Installing system essentials..."
if is_fedora; then
    dnf_quiet install \
        @development-tools cmake ninja-build pkgconf-pkg-config \
        git git-lfs git-credential-libsecret curl wget aria2 \
        gnupg2 ca-certificates \
        zip unzip p7zip p7zip-plugins bc
    dnf_each libsecret libsecret-devel
    if ! is_server_profile; then
        dnf_each xclip wl-clipboard flameshot xdotool dconf-editor gparted
    fi
else
    apt_quiet install \
        build-essential cmake ninja-build pkg-config \
        git git-lfs git-extras curl wget aria2 \
        gnupg2 ca-certificates apt-transport-https \
        zip unzip p7zip-full unrar-free bc
    is_ubuntu && [[ "$DISTRO_MAJOR" -lt 26 ]] && apt_each software-properties-common
    apt-cache show p7zip-rar &>/dev/null && apt_each p7zip-rar
    apt_each libsecret-1-0 libsecret-1-dev
    if ! is_server_profile; then
        apt_each xclip wl-clipboard flameshot xdotool dconf-editor gparted
    fi
fi
tick "System essentials"

info "Installing monitors & diagnostics..."
if is_fedora; then
    dnf_quiet install btop htop iotop iftop ncdu
    dnf_each nvtop nethogs lm_sensors smartmontools inxi sysstat upower powertop fastfetch
else
    apt_quiet install btop htop iotop iftop ncdu
    apt_each nvtop nethogs lm-sensors fancontrol smartmontools inxi sysstat upower powertop
    if ! command -v fastfetch &>/dev/null; then
        if apt-cache show fastfetch &>/dev/null; then
            apt_quiet install fastfetch && ok "fastfetch"
        elif is_ubuntu && command -v add-apt-repository &>/dev/null; then
            add-apt-repository -y ppa:zhangsongcui3371/fastfetch >> "$LOG_FILE" 2>&1 \
                && apt-get update -q >> "$LOG_FILE" 2>&1 \
                && apt_quiet install fastfetch \
                && ok "fastfetch (via PPA)" \
                || warn "fastfetch — not available (install manually from GitHub)"
        else
            install_github_deb "fastfetch-cli/fastfetch" "linux-${ARCH_GO}.deb" "fastfetch"
        fi
    fi
fi
tick "System monitors & diagnostics"

info "Installing developer & code quality tools..."
# Note: Node.js is installed cleanly via nvm in Module 07 (avoiding apt/dnf conflicts)
if is_fedora; then
    dnf_quiet install gh python3 python3-pip python3-devel jq ShellCheck
    dnf_each podman podman-compose buildah skopeo \
             direnv mkcert pipx yamllint
    dnf -q info shfmt &>/dev/null && dnf_each shfmt || true
else
    apt_quiet install gh python3 python3-pip python3-venv python3-dev jq shellcheck
    apt_each podman podman-compose buildah skopeo \
             direnv mkcert pipx redis-tools yamllint shfmt
fi

# mikefarah/yq v4 (Go) — avoids Ubuntu's incompatible Python kislyuk/yq package
if ! command -v yq &>/dev/null || ! yq --version 2>&1 | grep -qi 'mikefarah'; then
    install_github_bin "mikefarah/yq" "yq_linux_${ARCH_GO}" "yq" "yq (Go v4)"
else
    skip "yq ($(yq --version 2>/dev/null | head -1))"
fi
tick "Developer & code quality tools (podman, gh, python, yq, shellcheck)"

info "Installing network & file tools..."
if is_fedora; then
    dnf_quiet install nmap nmap-ncat bind-utils rsync tree fzf ripgrep fd-find bat tmux mosh \
        strace tcpdump
    dnf_each whois rclone mc eza screen openssh-askpass chafa
    ! is_server_profile && dnf_each remmina
else
    apt_quiet install nmap netcat-openbsd dnsutils rsync tree fzf ripgrep fd-find bat tmux mosh \
        strace tcpdump
    apt_each whois rclone mc eza screen ssh-askpass chafa
    ! is_server_profile && apt_each remmina
fi
tick "Network & file tools"

# ── Desktop apps, browser & codecs (skipped in server profile) ───────────────
if is_server_profile; then
    tick "Desktop apps & codecs — skipped (server profile)"
else
    info "Installing browser, codecs & desktop utilities..."
    if [[ "$ARCH_GO" == "amd64" ]]; then
        if is_fedora; then
            dnf_each google-chrome-stable
        else
            apt_each google-chrome-stable
        fi
    fi

    if is_fedora; then
        wait_for_rpm_lock
        # --allowerasing lets RPM Fusion ffmpeg cleanly replace Fedora's preinstalled ffmpeg-free/libswresample-free
        dnf -y -q install --allowerasing ffmpeg mpv celluloid colord yt-dlp >> "$LOG_FILE" 2>&1 \
            && ok "ffmpeg · mpv · celluloid · colord · yt-dlp" \
            || warn "dnf install ffmpeg mpv celluloid colord yt-dlp → exit $? (see log)"
        dnf_each vlc \
            gstreamer1-plugins-base gstreamer1-plugins-good \
            gstreamer1-plugins-bad-free gstreamer1-plugins-ugly-free \
            gstreamer1-plugin-libav gstreamer1-vaapi
    else
        apt_quiet install ffmpeg mpv celluloid colord yt-dlp
        apt_each vlc \
            gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
            gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
            gstreamer1.0-libav gstreamer1.0-vaapi libavcodec-extra
    fi

    # Modern Flatpak GUI utilities (replace deprecated Stacer + add Flatseal & LocalSend)
    if command -v flatpak &>/dev/null; then
        for fp_app in io.missioncenter.MissionCenter com.github.tchx84.Flatseal org.localsend.localsend_app; do
            if flatpak list --app 2>/dev/null | grep -q "$fp_app"; then
                skip "Flatpak: ${fp_app}"
            else
                flatpak install -y --noninteractive flathub "$fp_app" >> "$LOG_FILE" 2>&1 \
                    && ok "Flatpak: ${fp_app}" || warn "Flatpak: ${fp_app} skipped"
            fi
        done
    fi
    tick "Desktop apps (Chrome, VLC, codecs, Mission Center, Flatseal, LocalSend)"
fi

# ── Modern CLI tools (native repos first, GitHub releases fallback) ──────────
info "Installing modern CLI tools..."

# bat & fd symlinks (Ubuntu names them batcat/fdfind; Fedora uses bat/fd directly)
if ! is_fedora; then
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        install -d -o "$REAL_USER" -g "${USER_GROUP:-$REAL_USER}" "${USER_HOME}/.local/bin"
        ln -sf "$(command -v batcat)" "${USER_HOME}/.local/bin/bat"
        chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "${USER_HOME}/.local/bin/bat"
        ok "bat → batcat symlink"
    fi
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        install -d -o "$REAL_USER" -g "${USER_GROUP:-$REAL_USER}" "${USER_HOME}/.local/bin"
        ln -sf "$(command -v fdfind)" "${USER_HOME}/.local/bin/fd"
        chown "${REAL_USER}:${USER_GROUP:-$REAL_USER}" "${USER_HOME}/.local/bin/fd"
        ok "fd → fdfind symlink"
    fi
fi

# Prefer native Fedora packages where upstream does not ship RPMs
if is_fedora; then
    for _fpkg in git-delta hyperfine duf zoxide tealdeer fd-find; do
        dnf -q info "$_fpkg" &>/dev/null && dnf_each "$_fpkg" || true
    done
fi

# zoxide
if ! command -v zoxide &>/dev/null; then
    as_user "curl -sSfL --connect-timeout 15 --max-time 120 https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o /tmp/zoxide_install.sh && sh /tmp/zoxide_install.sh && rm -f /tmp/zoxide_install.sh" \
        >> "$LOG_FILE" 2>&1 && ok "zoxide installed" || warn "zoxide install failed"
else
    skip "zoxide $(zoxide --version 2>/dev/null)"
fi

# git-delta
if ! command -v delta &>/dev/null; then
    if is_fedora; then
        install_github_tar "dandavison/delta" "${ARCH_RUST}-unknown-linux-gnu.tar.gz" "delta" "git-delta"
    else
        install_github_deb "dandavison/delta" "${ARCH_GO}.deb" "git-delta"
    fi
else
    skip "delta $(delta --version 2>/dev/null | head -1)"
fi

# lazygit
if ! command -v lazygit &>/dev/null; then
    install_github_tar "jesseduffield/lazygit" "Linux_${ARCH_ALT}.tar.gz" "lazygit" "lazygit"
else
    skip "lazygit"
fi

# lazydocker
if ! command -v lazydocker &>/dev/null; then
    install_github_tar "jesseduffield/lazydocker" "Linux_${ARCH_ALT}.tar.gz" "lazydocker" "lazydocker"
else
    skip "lazydocker"
fi

# dust (better du)
if ! command -v dust &>/dev/null; then
    install_github_tar "bootandy/dust" "${ARCH_RUST}-unknown-linux-musl.tar.gz" "dust" "dust"
else
    skip "dust $(dust --version 2>/dev/null)"
fi

# procs (better ps)
if ! command -v procs &>/dev/null; then
    install_github_zip "dalance/procs" "${ARCH_RUST}-linux.zip" "procs" "procs"
else
    skip "procs $(procs --version 2>/dev/null)"
fi

# duf (better df)
if ! command -v duf &>/dev/null; then
    if is_fedora; then
        install_github_rpm "muesli/duf" "linux_${ARCH_GO}.rpm" "duf"
    else
        install_github_deb "muesli/duf" "linux_${ARCH_GO}.deb" "duf"
    fi
else
    skip "duf"
fi

# glow (terminal markdown renderer)
if ! command -v glow &>/dev/null; then
    install_github_tar "charmbracelet/glow" "Linux_${ARCH_ALT}.tar.gz" "glow" "glow"
else
    skip "glow"
fi

# bottom (btm — better top)
if ! command -v btm &>/dev/null; then
    install_github_tar "ClementTsang/bottom" "${ARCH_RUST}-unknown-linux-musl.tar.gz" "btm" "bottom (btm)"
else
    skip "bottom (btm)"
fi

# just (command runner)
if ! command -v just &>/dev/null; then
    install_github_tar "casey/just" "${ARCH_RUST}-unknown-linux-musl.tar.gz" "just" "just"
else
    skip "just"
fi

# hyperfine (benchmarking)
if ! command -v hyperfine &>/dev/null; then
    if is_fedora; then
        install_github_tar "sharkdp/hyperfine" "${ARCH_RUST}-unknown-linux-gnu.tar.gz" "hyperfine" "hyperfine"
    else
        install_github_deb "sharkdp/hyperfine" "${ARCH_GO}.deb" "hyperfine"
    fi
else
    skip "hyperfine"
fi

# onefetch (git repository summary — works on both Ubuntu & Fedora)
if ! command -v onefetch &>/dev/null; then
    install_github_tar "o2sh/onefetch" "onefetch-linux.tar.gz" "onefetch" "onefetch"
else
    skip "onefetch"
fi

# eza (modern ls replacement — fallback for Debian 12 where apt has no eza)
if ! command -v eza &>/dev/null; then
    install_github_tar "eza-community/eza" "eza_${ARCH_RUST}-unknown-linux-musl.tar.gz" "eza" "eza"
fi

# tealdeer (fast Rust tldr client)
if ! command -v tldr &>/dev/null; then
    install_github_bin "tealdeer-rs/tealdeer" "tealdeer-linux-${ARCH_RUST}-musl" "tldr" "tealdeer (tldr)"
    command -v tldr &>/dev/null && as_user "tldr --update" >> "$LOG_FILE" 2>&1 || true
else
    skip "tldr ($(tldr --version 2>/dev/null | head -1))"
fi

# xh (fast Rust HTTP client — friendly drop-in for httpie/curl)
if ! command -v xh &>/dev/null; then
    install_github_tar "ducaale/xh" "${ARCH_RUST}-unknown-linux-musl.tar.gz" "xh" "xh"
else
    skip "xh"
fi

# sd (modern intuitive sed)
if ! command -v sd &>/dev/null; then
    install_github_tar "chmln/sd" "${ARCH_RUST}-unknown-linux-musl.tar.gz" "sd" "sd"
else
    skip "sd"
fi

# yazi (modern terminal file manager with WezTerm image preview)
if ! command -v yazi &>/dev/null; then
    install_github_zip "sxyazi/yazi" "yazi-${ARCH_RUST}-unknown-linux-musl.zip" "yazi" "yazi"
else
    skip "yazi"
fi

# atuin (searchable SQLite shell history)
if ! command -v atuin &>/dev/null && [[ ! -x "${USER_HOME}/.atuin/bin/atuin" ]]; then
    install_github_tar "atuinsh/atuin" "atuin-${ARCH_RUST}-unknown-linux-musl.tar.gz" "atuin" "atuin"
else
    skip "atuin"
fi

tick "Modern CLI tools (zoxide · delta · lazygit · yazi · atuin · xh · sd · tealdeer)"

# ── Security / Lint CLIs & pre-commit ────────────────────────────────────────
# gitleaks (secret scanner)
if ! command -v gitleaks &>/dev/null; then
    install_github_tar "gitleaks/gitleaks" "linux_${ARCH_ALT/x86_64/x64}.tar.gz" "gitleaks" "gitleaks"
else
    skip "gitleaks"
fi

# hadolint (Dockerfile / Containerfile linter)
if ! command -v hadolint &>/dev/null; then
    install_github_bin "hadolint/hadolint" "hadolint-linux-${ARCH_ALT}" "hadolint" "hadolint"
else
    skip "hadolint"
fi

# shfmt fallback if not in distro repo
if ! command -v shfmt &>/dev/null; then
    install_github_bin "mvdan/sh" "linux_${ARCH_GO}" "shfmt" "shfmt"
else
    skip "shfmt"
fi

# pre-commit
if ! command -v pre-commit &>/dev/null; then
    if command -v pipx &>/dev/null; then
        as_user "pipx install pre-commit" >> "$LOG_FILE" 2>&1 && ok "pre-commit via pipx" || warn "pre-commit failed"
    else
        as_user "pip3 install --user --break-system-packages pre-commit 2>/dev/null || pip3 install --user pre-commit" \
            >> "$LOG_FILE" 2>&1 || warn "Install pre-commit manually: pipx install pre-commit"
    fi
else
    skip "pre-commit $(pre-commit --version 2>/dev/null)"
fi

# Build git-credential-libsecret if not already built (Ubuntu only)
if ! is_fedora; then
    GIT_CRED_DIR="/usr/share/doc/git/contrib/credential/libsecret"
    if [[ -d "$GIT_CRED_DIR" ]] && [[ ! -f "$GIT_CRED_DIR/git-credential-libsecret" ]]; then
        make -C "$GIT_CRED_DIR" >> "$LOG_FILE" 2>&1 || warn "Could not build git-credential-libsecret"
    fi
fi
tick "Security & lint CLIs (gitleaks · hadolint · shfmt · pre-commit)"

ok "System utilities & modern CLI tools complete"
