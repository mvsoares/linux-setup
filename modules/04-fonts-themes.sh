# =============================================================================
# Module 04 — Developer Fonts · GTK Themes · Icon Packs · Cursors
# =============================================================================
init_sub 8

FONT_DIR="/usr/local/share/fonts/custom"
mkdir -p "${FONT_DIR}/mono" "${FONT_DIR}/general"

# ── Nerd Font installer ──────────────────────────────────────────────────────
NERD_FONT_VER=$(curl -sSf "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" 2>/dev/null \
    | grep tag_name | cut -d'"' -f4)
[[ -z "$NERD_FONT_VER" ]] && NERD_FONT_VER="v3.3.0"

install_nerd_font() {
    local name="$1" slug="$2"
    local dest="${FONT_DIR}/mono/${name}"
    if [[ -d "$dest" ]] && ls "$dest"/*.ttf &>/dev/null 2>&1; then
        ok "${name} Nerd Font — already installed"
        return
    fi
    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VER}/${slug}.zip"
    if curl -fsSL "$url" -o "/tmp/${slug}.zip" >> "$LOG_FILE" 2>&1; then
        mkdir -p "$dest"
        unzip -qo "/tmp/${slug}.zip" -d "$dest" >> "$LOG_FILE" 2>&1 || true
        rm -f "/tmp/${slug}.zip"
        find "$dest" -name "*Windows*" -delete 2>/dev/null || true
        ok "${name} Nerd Font"
    else
        warn "${name} download failed"
    fi
}

# ── Google Font installer ────────────────────────────────────────────────────
install_google_font() {
    local name="$1"
    local dest="${FONT_DIR}/general/${name}"
    if [[ -d "$dest" ]] && ls "$dest"/*.ttf &>/dev/null 2>&1; then
        ok "${name} — already installed"
        return
    fi
    local encoded="${name// /+}"
    local zipfile="/tmp/gf-${name}.zip"
    rm -f "$zipfile"
    if curl -fsSL -A "Mozilla/5.0 (X11; Linux x86_64)" \
            "https://fonts.google.com/download?family=${encoded}" \
            -o "$zipfile" >> "$LOG_FILE" 2>&1 \
            && file "$zipfile" 2>/dev/null | grep -qi "zip"; then
        mkdir -p "$dest"
        unzip -qo "$zipfile" -d "$dest" >> "$LOG_FILE" 2>&1 || true
        rm -f "$zipfile"
        if ls "$dest"/*.ttf &>/dev/null 2>&1 || ls "$dest"/**/*.ttf &>/dev/null 2>&1; then
            ok "${name}"
        else
            warn "${name} — zip contained no .ttf files"
        fi
    else
        rm -f "$zipfile"
        warn "${name} — download failed or returned invalid file (install manually)"
    fi
}

# ── GitHub font release installer ────────────────────────────────────────────
install_github_font() {
    local name="$1" repo="$2" pattern="$3"
    local dest="${FONT_DIR}/mono/${name}"
    if [[ -d "$dest" ]] && ls "$dest"/*.ttf &>/dev/null 2>&1; then
        ok "${name} — already installed"
        return
    fi
    local url
    url=$(curl -sSf "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "$pattern" | head -1 | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        mkdir -p "$dest"
        local tmp="/tmp/font-${name}.zip"
        curl -fsSL "$url" -o "$tmp" >> "$LOG_FILE" 2>&1
        unzip -qo "$tmp" -d "$dest" >> "$LOG_FILE" 2>&1 || true
        rm -f "$tmp"
        find "$dest" -name "*Windows*" -delete 2>/dev/null || true
        ok "${name}"
    else
        warn "${name} — release not found"
    fi
}

# ── 1. Nerd Fonts (monospace, patched with icons) ─────────────────────────────
info "Installing Nerd Fonts (patched monospace)..."
install_nerd_font "JetBrainsMono" "JetBrainsMono"
install_nerd_font "FiraCode"      "FiraCode"
install_nerd_font "CascadiaCode"  "CascadiaCode"
install_nerd_font "Hack"          "Hack"
install_nerd_font "Inconsolata"   "Inconsolata"
install_nerd_font "Meslo"         "Meslo"
install_nerd_font "Iosevka"       "Iosevka"
install_nerd_font "IosevkaTerm"   "IosevkaTerm"
install_nerd_font "SpaceMono"     "SpaceMono"
install_nerd_font "VictorMono"    "VictorMono"
install_nerd_font "IBMPlexMono"   "IBMPlexMono"
install_nerd_font "SourceCodePro" "SourceCodePro"
install_nerd_font "UbuntuMono"    "UbuntuMono"
install_nerd_font "RobotoMono"    "RobotoMono"
install_nerd_font "CommitMono"    "CommitMono"
install_nerd_font "Monaspace"     "Monaspace"
install_nerd_font "GeistMono"     "GeistMono"
install_nerd_font "0xProto"       "0xProto"
install_nerd_font "ZedMono"       "ZedMono"
install_nerd_font "Recursive"     "Recursive"
install_nerd_font "MapleNerdFont" "Maple"
tick "20+ Nerd Fonts (mono, patched with icons)"

# ── 2. APT monospace fonts ───────────────────────────────────────────────────
info "APT mono fonts..."
apt_each fonts-firacode fonts-hack fonts-ubuntu fonts-roboto fonts-noto-mono \
         fonts-jetbrains-mono fonts-cascadia-code
tick "APT monospace fonts"

# ── 3. General / display fonts via Google Fonts ──────────────────────────────
info "Installing general/display fonts..."
install_google_font "Inter"
install_google_font "Nunito"
install_google_font "Poppins"
install_google_font "Raleway"
install_google_font "Montserrat"
install_google_font "Playfair Display"
install_google_font "Merriweather"
install_google_font "Work Sans"
install_google_font "DM Sans"
install_google_font "Outfit"
install_google_font "Geist"
tick "General/display fonts (Google Fonts)"

# ── 4. APT general fonts ─────────────────────────────────────────────────────
info "APT general fonts..."
apt_each fonts-inter fonts-lato fonts-open-sans fonts-urw-base35 \
         fonts-cantarell fonts-noto fonts-liberation fonts-freefont-ttf \
         fonts-noto-color-emoji fonts-font-awesome
tick "APT general fonts"

# ── 5. Rebuild font cache ────────────────────────────────────────────────────
info "Rebuilding font cache..."
fc-cache -f >> "$LOG_FILE" 2>&1 || warn "fc-cache had errors"
FONT_COUNT=$(fc-list 2>/dev/null | wc -l)
tick "Font cache rebuilt — ${FONT_COUNT} fonts total"

# ── 6. GTK Themes ────────────────────────────────────────────────────────────
info "Installing GTK themes..."

# Dracula GTK
DRACULA_DEST="/usr/share/themes/Dracula"
if [[ -d "$DRACULA_DEST" ]]; then
    skip "Dracula GTK theme"
else
    info "Installing Dracula GTK theme..."
    local_tmp=$(mktemp -d)
    if curl -fsSL "https://github.com/dracula/gtk/archive/master.zip" \
            -o "${local_tmp}/dracula-gtk.zip" >> "$LOG_FILE" 2>&1; then
        unzip -qo "${local_tmp}/dracula-gtk.zip" -d "${local_tmp}" >> "$LOG_FILE" 2>&1
        mv "${local_tmp}/gtk-master" "$DRACULA_DEST" 2>/dev/null \
            && ok "Dracula GTK theme" || warn "Dracula GTK theme move failed"
    else
        warn "Dracula GTK theme download failed"
    fi
    rm -rf "$local_tmp"
fi

# Catppuccin Mocha GTK
CATPPUCCIN_DEST="/usr/share/themes/catppuccin-mocha-mauve-standard+default"
if [[ -d "$CATPPUCCIN_DEST" ]] || ls /usr/share/themes/catppuccin-* &>/dev/null 2>&1; then
    skip "Catppuccin GTK theme"
else
    info "Installing Catppuccin Mocha GTK theme..."
    local_tmp=$(mktemp -d)
    CAPP_URL=$(curl -sSf "https://api.github.com/repos/catppuccin/gtk/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "mocha-mauve" | grep "standard+default" | head -1 | cut -d'"' -f4 || echo "")
    if [[ -n "$CAPP_URL" ]]; then
        curl -fsSL "$CAPP_URL" -o "${local_tmp}/catppuccin.zip" >> "$LOG_FILE" 2>&1
        unzip -qo "${local_tmp}/catppuccin.zip" -d /usr/share/themes/ >> "$LOG_FILE" 2>&1 \
            && ok "Catppuccin Mocha GTK theme" || warn "Catppuccin GTK unzip failed"
    else
        warn "Catppuccin GTK — release URL not found"
    fi
    rm -rf "$local_tmp"
fi

# Orchis GTK (clean modern look)
if ls /usr/share/themes/Orchis* &>/dev/null 2>&1; then
    skip "Orchis GTK theme"
else
    info "Installing Orchis GTK theme..."
    local_tmp=$(mktemp -d)
    if git clone --depth=1 https://github.com/vinceliuice/Orchis-theme.git \
            "${local_tmp}/orchis" >> "$LOG_FILE" 2>&1; then
        bash "${local_tmp}/orchis/install.sh" -t purple -c dark >> "$LOG_FILE" 2>&1 \
            && ok "Orchis GTK theme (purple dark)" || warn "Orchis install had errors"
    else
        warn "Orchis clone failed"
    fi
    rm -rf "$local_tmp"
fi
tick "GTK themes (Dracula · Catppuccin Mocha · Orchis)"

# ── 7. Icon themes ───────────────────────────────────────────────────────────
info "Installing icon themes..."

# Papirus
if dpkg -l papirus-icon-theme &>/dev/null 2>&1 || [[ -d /usr/share/icons/Papirus ]]; then
    skip "Papirus icons"
else
    add-apt-repository -y ppa:papirus/papirus >> "$LOG_FILE" 2>&1 || true
    apt_quiet update
    apt_each papirus-icon-theme
fi

# Tela icons
if ls /usr/share/icons/Tela* &>/dev/null 2>&1; then
    skip "Tela icons"
else
    info "Installing Tela icon theme..."
    local_tmp=$(mktemp -d)
    if git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git \
            "${local_tmp}/tela" >> "$LOG_FILE" 2>&1; then
        bash "${local_tmp}/tela/install.sh" -c purple >> "$LOG_FILE" 2>&1 \
            && ok "Tela icon theme" || warn "Tela install had errors"
    else
        warn "Tela clone failed"
    fi
    rm -rf "$local_tmp"
fi
tick "Icon themes (Papirus · Tela)"

# ── 8. Cursor themes ─────────────────────────────────────────────────────────
info "Installing cursor themes..."

# Bibata Modern Classic
if [[ -d /usr/share/icons/Bibata-Modern-Classic ]]; then
    skip "Bibata cursors"
else
    info "Installing Bibata Modern cursor..."
    BIBATA_URL=$(curl -sSf "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "Bibata-Modern-Classic.tar.xz" | head -1 | cut -d'"' -f4 || echo "")
    if [[ -n "$BIBATA_URL" ]]; then
        local_tmp=$(mktemp -d)
        curl -fsSL "$BIBATA_URL" -o "${local_tmp}/bibata.tar.xz" >> "$LOG_FILE" 2>&1
        tar xf "${local_tmp}/bibata.tar.xz" -C /usr/share/icons/ >> "$LOG_FILE" 2>&1 \
            && ok "Bibata Modern Classic cursor" || warn "Bibata extract failed"
        rm -rf "$local_tmp"
    else
        warn "Bibata cursor — release not found"
    fi
fi

# Bibata Modern Ice (light variant)
if [[ -d /usr/share/icons/Bibata-Modern-Ice ]]; then
    skip "Bibata Ice cursors"
else
    BIBATA_ICE_URL=$(curl -sSf "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest" 2>/dev/null \
        | grep browser_download_url | grep "Bibata-Modern-Ice.tar.xz" | head -1 | cut -d'"' -f4 || echo "")
    if [[ -n "$BIBATA_ICE_URL" ]]; then
        local_tmp=$(mktemp -d)
        curl -fsSL "$BIBATA_ICE_URL" -o "${local_tmp}/bibata-ice.tar.xz" >> "$LOG_FILE" 2>&1
        tar xf "${local_tmp}/bibata-ice.tar.xz" -C /usr/share/icons/ >> "$LOG_FILE" 2>&1 \
            && ok "Bibata Modern Ice cursor" || warn "Bibata Ice extract failed"
        rm -rf "$local_tmp"
    fi
fi
tick "Cursor themes (Bibata Modern Classic · Ice)"

ok "Fonts, themes, icons & cursors complete"
