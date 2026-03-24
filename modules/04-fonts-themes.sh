# =============================================================================
# Module 04 — Developer Fonts · GTK Themes · Icon Packs · Cursors
# =============================================================================
init_sub 5

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
    if [[ -d "$dest" ]] && find "$dest" -maxdepth 2 \( -name '*.ttf' -o -name '*.otf' \) -print -quit 2>/dev/null | grep -q .; then
        ok "${name} — already installed"
        return
    fi
    local encoded="${name// /+}"
    local manifest
    manifest=$(curl -fsSL "https://fonts.google.com/download/list?family=${encoded}" 2>/dev/null | tail -n +2)
    if [[ -z "$manifest" ]]; then
        warn "${name} — manifest fetch failed"
        return
    fi
    mkdir -p "$dest"
    local count=0
    while IFS=$'\t' read -r filename url; do
        local fpath="${dest}/${filename}"
        mkdir -p "$(dirname "$fpath")"
        curl -fsSL "$url" -o "$fpath" >> "$LOG_FILE" 2>&1 && count=$((count + 1))
    done < <(echo "$manifest" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for ref in data.get('manifest', {}).get('fileRefs', []):
    fn = ref.get('filename', '')
    if fn.endswith(('.ttf', '.otf')):
        print(fn + '\t' + ref.get('url', ''))
" 2>/dev/null)
    if [[ $count -gt 0 ]]; then
        ok "${name} (${count} files)"
    else
        warn "${name} — no font files downloaded"
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

# ── 1. Nerd Fonts (monospace, patched with icons) ────────────────────────────
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
tick "20+ Nerd Fonts (mono, patched with icons)"

# ── 2. Package manager monospace fonts ───────────────────────────────────────
info "Package manager mono fonts..."
if is_fedora; then
    # Fedora ships Hack as source-foundry-hack-fonts (not hack-fonts)
    dnf_each fira-code-fonts source-foundry-hack-fonts google-roboto-mono-fonts \
             google-noto-mono-fonts jetbrains-mono-fonts cascadia-code-fonts
else
    apt_each fonts-firacode fonts-hack fonts-ubuntu fonts-roboto fonts-noto-mono \
             fonts-jetbrains-mono fonts-cascadia-code
fi
tick "Package manager monospace fonts"

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

# ── 4. Package manager general fonts ─────────────────────────────────────────
info "Package manager general fonts..."
if is_fedora; then
    dnf_each lato-fonts open-sans-fonts urw-base35-fonts \
             abattis-cantarell-fonts google-noto-fonts-common liberation-fonts \
             google-noto-color-emoji-fonts fontawesome-fonts
else
    apt_each fonts-inter fonts-lato fonts-open-sans fonts-urw-base35 \
             fonts-cantarell fonts-noto fonts-liberation fonts-freefont-ttf \
             fonts-noto-color-emoji fonts-font-awesome
fi
tick "Package manager general fonts"

# ── 5. Rebuild font cache ────────────────────────────────────────────────────
info "Rebuilding font cache..."
fc-cache -f >> "$LOG_FILE" 2>&1 || warn "fc-cache had errors"
FONT_COUNT=$(fc-list 2>/dev/null | wc -l)
tick "Font cache rebuilt — ${FONT_COUNT} fonts total"

# ── GTK themes / icons / cursors ─────────────────────────────────────────────
info "GTK themes, icons & cursors skipped in main install."
info "  Run:  sudo bash scripts/install-themes.sh"

ok "Fonts complete — run scripts/install-themes.sh for GTK themes & icons"
