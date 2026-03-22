# =============================================================================
# Module 05 — GNOME Extensions & Desktop Configuration
# =============================================================================
init_sub 9

# ── Dependencies ──────────────────────────────────────────────────────────────
apt_each gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager \
         gnome-shell-extension-appindicator dconf-editor
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
tick "GNOME dependencies"

# ── Extension installer ──────────────────────────────────────────────────────
EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
ENABLED_EXTS=()
SHELL_VER=$(gnome-shell --version 2>/dev/null | awk '{print $3}')
SHELL_MAJOR=$(echo "$SHELL_VER" | cut -d. -f1)
if [[ -z "$SHELL_VER" ]]; then
    warn "GNOME Shell not detected — extension installs may fail"
    SHELL_VER="0"; SHELL_MAJOR="0"
fi
info "GNOME Shell version: ${BOLD}${SHELL_VER}${RESET}"

install_extension() {
    local name="$1" uuid="$2" ext_id="$3"
    local dest="${EXTENSIONS_DIR}/${uuid}"
    if [[ -d "$dest" ]]; then
        skip "${name} extension"
        ENABLED_EXTS+=("$uuid")
        return 0
    fi
    info "Fetching ${name} (ext #${ext_id})..."
    local info_json version_tag
    # Try exact version, then major.0, then unversioned (grab latest available)
    for try_ver in "${SHELL_VER}" "${SHELL_MAJOR}.0" ""; do
        local qp="pk=${ext_id}"
        [[ -n "$try_ver" ]] && qp+="&shell_version=${try_ver}"
        info_json=$(curl -fsSL "https://extensions.gnome.org/extension-info/?${qp}" 2>/dev/null)
        [[ -n "$info_json" ]] && echo "$info_json" | python3 -c "import sys,json; json.load(sys.stdin)" &>/dev/null && break
        info_json=""
    done

    version_tag=$(echo "$info_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    vsm = d.get('shell_version_map', {})
    for key in ['${SHELL_VER}', '${SHELL_MAJOR}.0']:
        if key in vsm:
            print(vsm[key].get('version', '')); sys.exit(0)
    if vsm:
        latest = sorted(vsm.keys(), key=lambda v: [int(x) for x in v.split('.')], reverse=True)
        print(vsm[latest[0]].get('version', ''))
except: pass
" 2>/dev/null || echo "")

    if [[ -z "$version_tag" ]]; then
        warn "${name} — no compatible version for GNOME ${SHELL_VER}"
        return 0
    fi
    local zip_url="https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version_tag}"
    local tmp_zip="/tmp/ext-${uuid}-$$.zip"
    if curl -fsSL "$zip_url" -o "$tmp_zip" >> "$LOG_FILE" 2>&1; then
        mkdir -p "$dest"
        if unzip -qo "$tmp_zip" -d "$dest" >> "$LOG_FILE" 2>&1; then
            find "$dest" -type f -exec chmod 644 {} \;
            find "$dest" -type d -exec chmod 755 {} \;
            rm -f "$tmp_zip"
            ok "${name} installed (v${version_tag})"
            ENABLED_EXTS+=("$uuid")
        else
            rm -rf "$dest" "$tmp_zip"
            warn "${name} — extraction failed"
        fi
    else
        rm -f "$tmp_zip"
        warn "${name} — download failed"
    fi
}

# ── Install extensions ────────────────────────────────────────────────────────
install_extension "User Themes"        "user-theme@gnome-shell-extensions.gcampax.github.com"  19
install_extension "Dash to Dock"       "dash-to-dock@micxgx.gmail.com"                         307
install_extension "Blur my Shell"      "blur-my-shell@aunetx"                                  3193
install_extension "Just Perfection"    "just-perfection-desktop@just-perfection"                3843
install_extension "Caffeine"           "caffeine@patapon.info"                                  517
install_extension "Clipboard Indicator" "clipboard-indicator@tudmotu.com"                       779
install_extension "Vitals"             "Vitals@CoreCoding.com"                                  1460
install_extension "Space Bar"          "space-bar@luchrioh"                                     5090

# AppIndicator via apt
if dpkg -s gnome-shell-extension-appindicator &>/dev/null 2>&1; then
    ENABLED_EXTS+=("appindicatorsupport@rgcjonas.gmail.com")
    ok "AppIndicator (via apt)"
else
    install_extension "AppIndicator" "appindicatorsupport@rgcjonas.gmail.com" 615
fi
tick "GNOME Shell extensions (9)"

# Enable extensions
if [[ ${#ENABLED_EXTS[@]} -gt 0 ]]; then
    _ext_list="["
    for u in "${ENABLED_EXTS[@]}"; do _ext_list+="'${u}',"; done
    _ext_list="${_ext_list%,}]"
    as_user "gsettings set org.gnome.shell enabled-extensions \"${_ext_list}\"" \
        && ok "Extensions enabled" || warn "Could not set enabled-extensions"
fi
tick "Extensions enabled"

# ── Appearance ────────────────────────────────────────────────────────────────
info "Setting appearance..."
gset org.gnome.desktop.interface color-scheme       "'prefer-dark'"
# accent-color is only available in GNOME 47+
if [[ "${SHELL_MAJOR:-0}" -ge 47 ]]; then
    gset org.gnome.desktop.interface accent-color    "'purple'"
fi
gset org.gnome.desktop.interface gtk-theme           "'Dracula'"
gset org.gnome.desktop.interface icon-theme          "'Papirus-Dark'"
gset org.gnome.desktop.interface cursor-theme        "'Bibata-Modern-Classic'"
gset org.gnome.desktop.interface cursor-size         "24"
as_user "gsettings set org.gnome.shell.extensions.user-theme name 'Dracula'" 2>/dev/null || true
tick "Appearance: Dracula + Papirus-Dark + Bibata"

# ── Fonts ─────────────────────────────────────────────────────────────────────
gset org.gnome.desktop.interface font-name            "'Inter 11'"
gset org.gnome.desktop.interface document-font-name   "'Inter 11'"
gset org.gnome.desktop.interface monospace-font-name  "'JetBrainsMono Nerd Font 12'"
gset org.gnome.desktop.wm.preferences titlebar-font   "'Inter Bold 11'"
gset org.gnome.desktop.interface font-antialiasing    "'rgba'"
gset org.gnome.desktop.interface font-hinting         "'slight'"
gset org.gnome.desktop.interface text-scaling-factor  "1.0"
tick "Fonts: Inter 11 / JetBrainsMono 12 / rgba"

# ── Dash-to-Dock ─────────────────────────────────────────────────────────────
DTD="org.gnome.shell.extensions.dash-to-dock"
as_user "gsettings set ${DTD} dock-position           'BOTTOM'"     2>/dev/null || true
as_user "gsettings set ${DTD} extend-height           'false'"       2>/dev/null || true
as_user "gsettings set ${DTD} dock-fixed              'false'"       2>/dev/null || true
as_user "gsettings set ${DTD} autohide                'true'"        2>/dev/null || true
as_user "gsettings set ${DTD} intellihide             'true'"        2>/dev/null || true
as_user "gsettings set ${DTD} autohide-in-fullscreen  'true'"        2>/dev/null || true
as_user "gsettings set ${DTD} transparency-mode       'FIXED'"       2>/dev/null || true
as_user "gsettings set ${DTD} background-opacity      '0.8'"         2>/dev/null || true
as_user "gsettings set ${DTD} show-trash              'true'"        2>/dev/null || true
as_user "gsettings set ${DTD} show-mounts             'true'"        2>/dev/null || true
as_user "gsettings set ${DTD} dash-max-icon-size      '44'"          2>/dev/null || true
as_user "gsettings set ${DTD} click-action            'minimize-or-previews'" 2>/dev/null || true
as_user "gsettings set ${DTD} scroll-action           'cycle-windows'" 2>/dev/null || true
tick "Dash-to-Dock (bottom, auto-hide, 44px)"

# ── Blur my Shell ─────────────────────────────────────────────────────────────
BMS="org.gnome.shell.extensions.blur-my-shell"
if as_user "gsettings list-keys ${BMS}.panel" &>/dev/null; then
    as_user "gsettings set ${BMS}.panel blur            'true'"  2>/dev/null || true
    as_user "gsettings set ${BMS}.panel sigma           '30'"    2>/dev/null || true
    as_user "gsettings set ${BMS}.panel brightness      '0.6'"   2>/dev/null || true
    as_user "gsettings set ${BMS}.overview blur         'true'"  2>/dev/null || true
    as_user "gsettings set ${BMS}.dash-to-dock blur     'true'"  2>/dev/null || true
    as_user "gsettings set ${BMS}.dash-to-dock sigma    '30'"    2>/dev/null || true
    ok "Blur my Shell configured"
else
    info "Blur my Shell schemas not available yet (apply after GNOME Shell restart)"
fi

# ── Just Perfection ──────────────────────────────────────────────────────────
JP="org.gnome.shell.extensions.just-perfection"
if as_user "gsettings list-keys ${JP}" &>/dev/null; then
    as_user "gsettings set ${JP} animation              '3'"     2>/dev/null || true
    as_user "gsettings set ${JP} activities-button      'false'" 2>/dev/null || true
    as_user "gsettings set ${JP} panel-button-padding-size '4'"  2>/dev/null || true
    as_user "gsettings set ${JP} window-demands-attention-focus 'true'" 2>/dev/null || true
    ok "Just Perfection configured"
else
    info "Just Perfection schemas not available yet (apply after GNOME Shell restart)"
fi

# ── Window & Workspace ───────────────────────────────────────────────────────
gset org.gnome.desktop.wm.preferences button-layout        "'appmenu:minimize,maximize,close'"
gset org.gnome.desktop.wm.preferences focus-mode           "'click'"
gset org.gnome.desktop.wm.preferences action-double-click-titlebar "'toggle-maximize'"
gset org.gnome.desktop.wm.preferences action-middle-click-titlebar "'minimize'"
gset org.gnome.mutter center-new-windows                    "true"
gset org.gnome.mutter edge-tiling                           "true"
gset org.gnome.mutter dynamic-workspaces                    "true"
gset org.gnome.desktop.interface enable-animations          "true"

# Workspace keyboard shortcuts
gset org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>4']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-1   "['<Super><Shift>1']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-2   "['<Super><Shift>2']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-3   "['<Super><Shift>3']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-4   "['<Super><Shift>4']"
gset org.gnome.desktop.wm.keybindings show-desktop          "['<Super>d']"
gset org.gnome.shell.keybindings toggle-overview            "['<Super>s']"
tick "Windows + workspaces + keybindings"

# ── Nautilus ──────────────────────────────────────────────────────────────────
gset org.gnome.nautilus.preferences default-folder-viewer   "'list-view'"
as_user "gsettings set org.gnome.nautilus.preferences sort-directories-first true" 2>/dev/null || true
gset org.gnome.nautilus.list-view default-zoom-level        "'small'"
gset org.gnome.nautilus.list-view use-tree-view             "true"
gset org.gnome.nautilus.preferences recursive-search        "'local-only'"

# ── Input devices ─────────────────────────────────────────────────────────────
gset org.gnome.desktop.peripherals.touchpad tap-to-click         "true"
gset org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled "true"
gset org.gnome.desktop.peripherals.touchpad natural-scroll        "true"
gset org.gnome.desktop.peripherals.touchpad disable-while-typing  "true"
gset org.gnome.desktop.peripherals.touchpad speed                 "0.2"
gset org.gnome.desktop.peripherals.mouse accel-profile  "'flat'"
gset org.gnome.desktop.peripherals.mouse speed          "0.0"
gset org.gnome.desktop.peripherals.keyboard delay  "250"
gset org.gnome.desktop.peripherals.keyboard repeat-interval "30"

# ── Power & Night Light ──────────────────────────────────────────────────────
gset org.gnome.desktop.session idle-delay "300"
gset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type         "'nothing'"
gset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout "900"
gset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type    "'suspend'"
gset org.gnome.settings-daemon.plugins.color night-light-enabled             "true"
gset org.gnome.settings-daemon.plugins.color night-light-schedule-automatic  "true"
gset org.gnome.settings-daemon.plugins.color night-light-temperature         "4000"
tick "Power + night light (auto, 4000K)"

# ── Privacy & misc ───────────────────────────────────────────────────────────
gset org.gnome.desktop.privacy remember-recent-files    "true"
gset org.gnome.desktop.privacy recent-files-max-age     "30"
gset org.gnome.desktop.privacy remove-old-temp-files    "true"
gset org.gnome.desktop.privacy remove-old-trash-files   "true"
gset org.gnome.desktop.privacy old-files-age            "30"
gset org.gnome.desktop.privacy send-software-usage-stats "false"
gset org.gnome.desktop.privacy report-technical-problems "false"
gset org.gnome.desktop.interface clock-show-weekday  "true"
gset org.gnome.desktop.interface clock-format        "'24h'"
gset org.gnome.desktop.interface show-battery-percentage "true"
gset org.gnome.desktop.calendar show-weekdate        "true"
gset org.gnome.desktop.interface enable-hot-corners  "false"
gset org.gnome.desktop.screensaver lock-enabled      "true"
gset org.gnome.desktop.screensaver lock-delay        "30"
tick "Privacy + clock + lock settings"

ok "GNOME desktop configuration complete"
