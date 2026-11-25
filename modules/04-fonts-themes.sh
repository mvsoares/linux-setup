# =============================================================================
# Module 04 — Developer Fonts · GTK Themes · Icon Packs · Cursors
# =============================================================================
init_sub 5

FONT_DIR="/usr/local/share/fonts/custom"
mkdir -p "${FONT_DIR}/mono" "${FONT_DIR}/general"

# ── Nerd Font installer ──────────────────────────────────────────────────────
NERD_FONT_VER=$(_github_latest_tag "ryanoasis/nerd-fonts")
[[ -z "$NERD_FONT_VER" ]] && NERD_FONT_VER="v3.4.0"

install_nerd_font() {
    local name="$1" slug="$2"
    local dest="${FONT_DIR}/mono/${name}"
    if [[ -d "$dest" ]] && find "$dest" -maxdepth 2 \( -name '*.ttf' -o -name '*.otf' \) -print -quit 2>/dev/null | grep -q .; then
        ok "${name} Nerd Font — already installed"
        return 0
    fi
    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VER}/${slug}.zip"
    local tmp_zip="/tmp/nf-${slug}-$$.zip"
    if curl -fsSL --retry 2 --retry-delay 2 "${CURL_TIMEOUT_OPTS[@]}" "$url" -o "$tmp_zip" >> "$LOG_FILE" 2>&1; then
        mkdir -p "$dest"
        unzip -qo "$tmp_zip" -d "$dest" >> "$LOG_FILE" 2>&1 || true
        rm -f "$tmp_zip"
        find "$dest" -name "*Windows*" -delete 2>/dev/null || true
        ok "${name} Nerd Font"
    else
        rm -f "$tmp_zip"
        warn "${name} download failed"
    fi
}

# ── Google Font installer ────────────────────────────────────────────────────
install_google_font() {
    local name="$1"
    local dest="${FONT_DIR}/general/${name}"
    if [[ -d "$dest" ]] && find "$dest" -maxdepth 2 \( -name '*.ttf' -o -name '*.otf' \) -print -quit 2>/dev/null | grep -q .; then
        ok "${name} — already installed"
        return 0
    fi
    local encoded="${name// /+}"
    local manifest
    manifest=$(curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://fonts.google.com/download/list?family=${encoded}" 2>/dev/null | tail -n +2)
    if [[ -z "$manifest" ]]; then
        warn "${name} — manifest fetch failed"
        return 0
    fi
    mkdir -p "$dest"
    local count=0
    while IFS=$'\t' read -r filename url; do
        local fpath="${dest}/${filename}"
        mkdir -p "$(dirname "$fpath")"
        curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "$url" -o "$fpath" >> "$LOG_FILE" 2>&1 && count=$((count + 1))
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

# ── 1. Nerd Fonts (parallel download, max 4 jobs at a time) ──────────────────
info "Installing Nerd Fonts ${NERD_FONT_VER} (parallel, up to 4 concurrent)..."
NERD_FONTS=(
    "NerdFontsSymbolsOnly:NerdFontsSymbolsOnly"
    "JetBrainsMono:JetBrainsMono"
    "FiraCode:FiraCode"
    "CascadiaCode:CascadiaCode"
    "Hack:Hack"
    "Inconsolata:Inconsolata"
    "Meslo:Meslo"
    "Iosevka:Iosevka"
    "IosevkaTerm:IosevkaTerm"
    "SpaceMono:SpaceMono"
    "VictorMono:VictorMono"
    "IBMPlexMono:IBMPlexMono"
    "SourceCodePro:SourceCodePro"
    "UbuntuMono:UbuntuMono"
    "RobotoMono:RobotoMono"
    "CommitMono:CommitMono"
    "Monaspace:Monaspace"
    "GeistMono:GeistMono"
    "0xProto:0xProto"
    "ZedMono:ZedMono"
    "Recursive:Recursive"
)

# Run in an isolated subshell so `wait` / `wait -n` never waits on setup.sh's SUDO_KEEPER_PID
(
    _nf_jobs=0
    for entry in "${NERD_FONTS[@]}"; do
        install_nerd_font "${entry%%:*}" "${entry#*:}" &
        _nf_jobs=$((_nf_jobs + 1))
        if [[ $_nf_jobs -ge 4 ]]; then
            wait -n 2>/dev/null || wait
            _nf_jobs=$((_nf_jobs - 1))
        fi
    done
    wait
)
tick "21 Nerd Fonts + Symbols fallback (mono, patched with icons)"

# ── 2. Package manager monospace fallback fonts (non-duplicating) ────────────
info "Package manager monospace fallback fonts..."
if is_fedora; then
    dnf_each google-noto-mono-fonts
else
    apt_each fonts-noto-mono fonts-ubuntu
fi
tick "Package manager monospace fallback fonts"

# ── 3. General / display fonts via Google Fonts ──────────────────────────────
info "Installing general/display fonts..."
GOOGLE_FONTS=(
    "Inter"
    "Nunito"
    "Poppins"
    "Raleway"
    "Montserrat"
    "Playfair Display"
    "Merriweather"
    "Work Sans"
    "DM Sans"
    "Outfit"
    "Geist"
)
(
    _gf_jobs=0
    for gfont in "${GOOGLE_FONTS[@]}"; do
        install_google_font "$gfont" &
        _gf_jobs=$((_gf_jobs + 1))
        if [[ $_gf_jobs -ge 4 ]]; then
            wait -n 2>/dev/null || wait
            _gf_jobs=$((_gf_jobs - 1))
        fi
    done
    wait
)
tick "General/display fonts (Google Fonts)"

# ── 4. Package manager general & emoji fonts (no duplicates with Google) ─────
info "Package manager general & emoji fonts..."
if is_fedora; then
    dnf_each lato-fonts open-sans-fonts urw-base35-fonts \
             abattis-cantarell-fonts google-noto-fonts-common liberation-fonts \
             google-noto-color-emoji-fonts
    for _fa in fontawesome-fonts fontawesome-fonts-all; do
        if dnf -q info "$_fa" &>/dev/null; then
            dnf_each "$_fa"
            break
        fi
    done
else
    apt_each fonts-lato fonts-open-sans fonts-urw-base35 \
             fonts-cantarell fonts-noto fonts-liberation fonts-freefont-ttf \
             fonts-noto-color-emoji fonts-font-awesome
fi
tick "Package manager general & emoji fonts"

# ── 5. Rebuild font cache ────────────────────────────────────────────────────
info "Rebuilding font cache..."
fc-cache -f >> "$LOG_FILE" 2>&1 || warn "fc-cache had errors"
FONT_COUNT=$(fc-list 2>/dev/null | wc -l)
tick "Font cache rebuilt — ${FONT_COUNT} fonts total"

# ── GTK themes / icons / cursors ─────────────────────────────────────────────
info "GTK themes, icons & cursors skipped in main install."
info "  Run:  sudo bash scripts/install-themes.sh"

ok "Fonts complete — run scripts/install-themes.sh for GTK themes & icons"
