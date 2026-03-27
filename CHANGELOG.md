# Changelog

All notable changes to this project are documented in this file.

---

## [Unreleased] — 2026-03-24

### Added

#### Font Picker (`font-picker.py` + `nerd-fonts-preview.html`)
- New Python HTTP server (port 7777) for live WezTerm font switching
- `/fonts` endpoint dynamically queries `fc-list` for all installed Nerd Fonts — no hardcoded list
- Metadata map covers 33 known Nerd Font families with correct `fc-list` family names (`BlexMono`, `CaskaydiaCove`, `MonaspiceNe`, etc.)
- `/apply`, `/apply-tab`, `/apply-size`, `/apply-tab-size`, `/current` endpoints write directly to `~/.config/wezterm/wezterm.lua`
- HTML preview page: clickable font cards, Editor / Tabs buttons, size spinners (`−`/`+` at 0.5pt steps)
- Card grid built dynamically on load from `/fonts`; shows count badge ("33 Nerd Fonts found")
- Graceful fallback message when no Nerd Fonts are detected

#### GTK Themes installer (`scripts/install-themes.sh`)
- Standalone optional script decoupled from the main install
- Installs: Dracula GTK, Catppuccin Mocha (mauve), Arc, Materia, Numix, Greybird, Yaru
- Icons: Papirus-Dark, Tela (purple)
- Cursors: Bibata Modern Classic + Ice
- nwg-look (GTK theme manager for Wayland/Hyprland)

#### End-of-install GTK prompt (`setup.sh`)
- After main install completes, prompts user to install GTK themes immediately
- 30-second read timeout — defaults to No if unanswered
- Prints `sudo bash scripts/install-themes.sh` hint when skipped

#### JDK 21 + Maven (`modules/07-languages.sh`)
- JDK 21 Temurin installed via SDKMAN (`21.0.x-tem`)
- Maven latest stable installed via SDKMAN
- `JAVA_HOME`, `MAVEN_HOME`, `M2_HOME` and their `bin/` paths appended to `~/.bashrc` (idempotent, uses SDKMAN `current` symlink)

### Fixed

#### GNOME Extensions 404 (`modules/05-gnome.sh`)
- **Root cause**: `shell_version_map[gnome_ver]['version']` is the extension's own version number; the download URL requires `shell_version_map[gnome_ver]['pk']` (the database row ID)
- Fixed Python extraction to use `.get('pk')` instead of `.get('version')`
- Added `SHELL_MAJOR` (e.g. `"46"`) to the key lookup list — the API stores integer keys, not `"46.0"`
- All 7 extensions now download successfully on GNOME 46 (Ubuntu 24.04) and GNOME 50 beta (Ubuntu 26.04)

#### `tar` pipe decompression failure (`lib/common.sh`, `modules/06-cloud-k8s.sh`)
- **Root cause**: `curl … | tar -xf -` fails on Ubuntu 26 — GNU tar cannot auto-detect gzip compression from a stdin pipe
- Fixed `install_github_tar()`: downloads to a temp file first, then `tar -xf <file>` (auto-detection works from file)
- Fixed three direct pipe calls in module 06: eksctl, kubectx, kubens
- Resolves `binary not found in archive` for lazygit, lazydocker, dust, just, k9s, stern

#### JDK 21 SDKMAN ID parsing (`modules/07-languages.sh`)
- Old regex `^\s*(21\.[0-9.]+)\s.*tem` expected lines starting with whitespace+version; SDKMAN table rows start with `|` pipe characters
- Replaced with `grep -oE '[0-9]+\.[0-9.]+-tem' | grep '^21\.'` — extracts the identifier token directly from anywhere in the line

#### GTK themes removed from main install (`modules/04-fonts-themes.sh`)
- Moved Dracula, Catppuccin, Arc, Materia, Papirus, Tela, Bibata, nwg-look to `scripts/install-themes.sh`
- Eliminates install-time throttling/timeouts on slow connections
- `init_sub` count corrected (9 → 5 ticks)

#### MapleNerdFont removed (`modules/04-fonts-themes.sh`)
- Font slug does not exist in Nerd Fonts GitHub releases; removed to eliminate repeated 404 warnings

#### `tokei` removed (`modules/02-system-cli.sh`)
- Consistently failed to resolve release URL; removed from CLI tools list

#### curl pre-check (`modules/01-repos-nvidia.sh`)
- Fresh Ubuntu 24.04 minimal images ship without `curl`; module 01 now installs it before any network operations

#### GNOME extension schema warnings
- `No such schema "org.gnome.shell.extensions.blur-my-shell.panel"` and `just-perfection` warnings are expected — schemas register only after a GNOME Shell restart; configuration is applied on next login

---

## [1.0.0] — 2026-03-23

### Added
- Full idempotent workstation setup with checkpoint-based resume (`setup.sh`)
- 10 modules: repos/NVIDIA, system CLI, shell, fonts, GNOME, cloud/k8s, languages, editors, workspace, tweaks
- WezTerm config: Monokai Remastered theme, JetBrainsMono Nerd Font, tab titles with running process name + OSC 7 cwd
- WezTerm bash hook (`~/.bashrc`): `DEBUG` trap for process names, `PROMPT_COMMAND` for cwd + reset
- Starship prompt with full developer segment (git, node, python, rust, go, java, docker, k8s, aws)
- synth-shell prompt + better-ls + aliases
- SDKMAN, nvm, pyenv, rustup, Go installer
- AWS CLI v2, eksctl, Session Manager plugin, kubectl, helm, k9s, stern, kubectx, kubens, kustomize
- Google Cloud SDK, Azure CLI, Brave browser, Google Chrome (stable + beta)
- VSCodium with 20+ extensions mirrored from VS Code settings
- Neovim with kickstart.nvim config
- AI CLI tools: Claude Code, Gemini CLI, Codex CLI
- 20+ Nerd Fonts, Google Fonts (Inter, Nunito, Poppins, etc.), APT font packages
- GNOME extensions: Dash to Dock, Blur my Shell, Just Perfection, Caffeine, Clipboard Indicator, Vitals, Space Bar, User Themes, AppIndicator
- GNOME settings: Dracula theme, Papirus-Dark icons, Bibata cursor, workspaces, keybindings, night light, privacy
- Backup/restore scripts with dotfile archiving
- Per-step `--reset`, `--only`, `--skip` flags
- Ubuntu 24.04 and Ubuntu 26.04 (GNOME 50 beta) compatibility

---

## Legend

| Symbol | Meaning |
|--------|---------|
| **Added** | New features or files |
| **Fixed** | Bug fixes and corrections |
| **Changed** | Behaviour or implementation changes |
| **Removed** | Deleted features or tools |
