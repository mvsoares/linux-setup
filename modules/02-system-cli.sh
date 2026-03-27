# =============================================================================
# Module 02 — System Utilities & Modern CLI Tools
# =============================================================================
init_sub 8

info "Installing system essentials..."
if is_fedora; then
    dnf_quiet install \
        @development-tools cmake ninja-build pkgconf-pkg-config \
        git git-lfs curl wget aria2 \
        gnupg2 ca-certificates \
        unzip p7zip p7zip-plugins xclip xdotool dconf-editor bc
    dnf_each gparted libsecret libsecret-devel
else
    apt_quiet install \
        build-essential cmake ninja-build pkg-config \
        git git-lfs git-extras curl wget aria2 \
        gnupg2 ca-certificates software-properties-common apt-transport-https \
        unzip p7zip-full unrar-free xclip xdotool dconf-editor preload bc
    apt_each gparted stacer libsecret-1-0 libsecret-1-dev
    [[ "$DISTRO_MAJOR" -lt 26 ]] && apt_each p7zip-rar
fi
tick "System essentials"

info "Installing monitors & diagnostics..."
if is_fedora; then
    dnf_quiet install btop htop iotop iftop ncdu
    dnf_each nvtop nethogs lm_sensors smartmontools inxi sysstat upower powertop fastfetch
else
    apt_quiet install btop htop iotop iftop ncdu
    apt_each nvtop nethogs lm-sensors fancontrol smartmontools inxi sysstat upower powertop
    [[ "$DISTRO_MAJOR" -lt 26 ]] && apt_each neofetch
    if ! command -v fastfetch &>/dev/null; then
        if apt-cache show fastfetch &>/dev/null; then
            apt_quiet install fastfetch && ok "fastfetch"
        else
            add-apt-repository -y ppa:zhangsongcui3371/fastfetch >> "$LOG_FILE" 2>&1 \
                && apt-get update -q >> "$LOG_FILE" 2>&1 \
                && apt_quiet install fastfetch \
                && ok "fastfetch (via PPA)" \
                || warn "fastfetch — not available (install manually from GitHub)"
        fi
    fi
fi
tick "System monitors & diagnostics"

info "Installing developer tools..."
if is_fedora; then
    dnf_quiet install gh python3 python3-pip python3-devel nodejs jq
    dnf_each podman podman-compose buildah skopeo \
             yq direnv mkcert pipx
else
    apt_quiet install gh python3 python3-pip python3-venv python3-dev nodejs jq
    apt_each podman podman-compose buildah skopeo \
             yq direnv mkcert pipx redis-tools
fi
tick "Developer tools (podman, gh, python, node)"

info "Installing network & file tools..."
if is_fedora; then
    dnf_quiet install nmap nmap-ncat bind-utils rsync tree ranger fzf ripgrep fd-find bat tmux mosh \
        strace tcpdump
    dnf_each whois rclone mc eza screen openssh-askpass chafa remmina
else
    apt_quiet install nmap netcat-openbsd dnsutils rsync tree ranger fzf ripgrep fd-find bat tmux mosh \
        strace tcpdump
    apt_each whois rclone mc eza screen ssh-askpass chafa remmina
fi
tick "Network & file tools"

info "Installing browsers..."
if is_fedora; then
    dnf_each google-chrome-stable
else
    apt_each google-chrome-stable google-chrome-beta
fi
tick "Browsers (Google Chrome)"

info "Installing video & codecs..."
if is_fedora; then
    dnf_quiet install ffmpeg mpv celluloid colord yt-dlp
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
tick "Video players & codecs"

if ! is_fedora; then
    info "Installing snap apps..."
    snap_install "code" --classic
    snap_install "onefetch"
    tick "Snap apps"
else
    info "Installing Fedora packages (VSCode, onefetch)..."
    dnf_each code onefetch
    tick "Fedora packages"
fi

# ── Modern CLI tools from GitHub ──────────────────────────────────────────────
info "Installing modern CLI tools from GitHub releases..."

# bat symlink (Ubuntu names it batcat, Fedora uses bat directly)
if ! is_fedora; then
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        install -d -o "$REAL_USER" -g "$REAL_USER" "${USER_HOME}/.local/bin"
        ln -sf "$(command -v batcat)" "${USER_HOME}/.local/bin/bat"
        chown "$REAL_USER:$REAL_USER" "${USER_HOME}/.local/bin/bat"
        ok "bat → batcat symlink"
    fi

    # fd symlink (Ubuntu names it fdfind, Fedora uses fd directly)
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        install -d -o "$REAL_USER" -g "$REAL_USER" "${USER_HOME}/.local/bin"
        ln -sf "$(command -v fdfind)" "${USER_HOME}/.local/bin/fd"
        chown "$REAL_USER:$REAL_USER" "${USER_HOME}/.local/bin/fd"
        ok "fd → fdfind symlink"
    fi
fi

# zoxide (install as user so it goes to ~/.local/bin)
if ! command -v zoxide &>/dev/null; then
    as_user "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o /tmp/zoxide_install.sh && sh /tmp/zoxide_install.sh && rm -f /tmp/zoxide_install.sh" \
        >> "$LOG_FILE" 2>&1 && ok "zoxide installed" || warn "zoxide install failed"
else
    skip "zoxide $(zoxide --version 2>/dev/null)"
fi

# git-delta
if ! command -v delta &>/dev/null; then
    if is_fedora; then
        install_github_rpm "dandavison/delta" "x86_64.rpm" "git-delta"
    else
        install_github_deb "dandavison/delta" "$(dpkg --print-architecture).deb" "git-delta"
    fi
else
    skip "delta $(delta --version 2>/dev/null | head -1)"
fi

# lazygit
if ! command -v lazygit &>/dev/null; then
    install_github_tar "jesseduffield/lazygit" "Linux_x86_64.tar.gz" "lazygit" "lazygit"
else
    skip "lazygit"
fi

# lazydocker
if ! command -v lazydocker &>/dev/null; then
    install_github_tar "jesseduffield/lazydocker" "Linux_x86_64.tar.gz" "lazydocker" "lazydocker"
else
    skip "lazydocker"
fi

# dust (better du)
if ! command -v dust &>/dev/null; then
    install_github_tar "bootandy/dust" "x86_64-unknown-linux-musl.tar.gz" "dust" "dust"
else
    skip "dust $(dust --version 2>/dev/null)"
fi

# procs (better ps)
if ! command -v procs &>/dev/null; then
    _procs_tag=$(_github_latest_tag "dalance/procs")
    _procs_url=""
    [[ -n "$_procs_tag" ]] && _procs_url=$(_github_asset_url "dalance/procs" "$_procs_tag" "x86_64-linux.zip")
    [[ -z "$_procs_url" ]] && _procs_url=$(_gh_api_curl "https://api.github.com/repos/dalance/procs/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "x86_64-linux.zip" | head -1 | cut -d'"' -f4)
    if [[ -n "$_procs_url" ]]; then
        _procs_tmp=$(mktemp -d)
        if curl -sSfL "$_procs_url" -o "$_procs_tmp/procs.zip" >> "$LOG_FILE" 2>&1; then
            unzip -q "$_procs_tmp/procs.zip" -d "$_procs_tmp" >> "$LOG_FILE" 2>&1
            install "$_procs_tmp/procs" /usr/local/bin/procs && ok "procs installed" || warn "procs install failed"
        else
            warn "procs — download failed"
        fi
        rm -rf "$_procs_tmp"
    else
        warn "procs — could not find release"
    fi
else
    skip "procs $(procs --version 2>/dev/null)"
fi


# duf (better df)
if ! command -v duf &>/dev/null; then
    if is_fedora; then
        install_github_rpm "muesli/duf" "x86_64.rpm" "duf"
    else
        install_github_deb "muesli/duf" "$(dpkg --print-architecture).deb" "duf"
    fi
else
    skip "duf"
fi

# glow (terminal markdown renderer)
if ! command -v glow &>/dev/null; then
    if is_fedora; then
        install_github_rpm "charmbracelet/glow" "x86_64.rpm" "glow"
    else
        install_github_deb "charmbracelet/glow" "$(dpkg --print-architecture).deb" "glow"
    fi
else
    skip "glow"
fi

# bottom (btm — better top)
if ! command -v btm &>/dev/null; then
    if is_fedora; then
        install_github_rpm "ClementTsang/bottom" "x86_64.rpm" "bottom"
    else
        install_github_deb "ClementTsang/bottom" "$(dpkg --print-architecture).deb" "bottom"
    fi
else
    skip "bottom (btm)"
fi

# just (command runner)
if ! command -v just &>/dev/null; then
    install_github_tar "casey/just" "x86_64-unknown-linux-musl.tar.gz" "just" "just"
else
    skip "just"
fi

# hyperfine (benchmarking)
if ! command -v hyperfine &>/dev/null; then
    if is_fedora; then
        install_github_rpm "sharkdp/hyperfine" "x86_64.rpm" "hyperfine"
    else
        install_github_deb "sharkdp/hyperfine" "$(dpkg --print-architecture).deb" "hyperfine"
    fi
else
    skip "hyperfine"
fi

tick "Modern CLI tools from GitHub"

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
tick "pre-commit"

# Build git-credential-libsecret if not already built (Ubuntu only)
if ! is_fedora; then
    GIT_CRED_DIR="/usr/share/doc/git/contrib/credential/libsecret"
    if [[ -d "$GIT_CRED_DIR" ]] && [[ ! -f "$GIT_CRED_DIR/git-credential-libsecret" ]]; then
        make -C "$GIT_CRED_DIR" 2>/dev/null >> "$LOG_FILE" 2>&1 || warn "Could not build git-credential-libsecret"
    fi
fi

ok "System utilities & modern CLI tools complete"
