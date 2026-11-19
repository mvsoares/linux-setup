# Linux Workstation Setup

Opinionated, idempotent setup scripts for a full Ubuntu development workstation. One command gets you from a fresh install to a production-ready dev environment with modern CLI tools, cloud SDKs, language runtimes, GPU drivers, a polished GNOME desktop, and sane defaults everywhere.

Safe to re-run at any time — a checkpoint system skips already-completed steps.

## Quick Start

```bash
git clone https://github.com/<you>/linux-setup.git
cd linux-setup
sudo bash setup.sh
```

Reboot when done.

## What's Inside

The setup is split into **10 ordered modules**, each independently skippable and resumable:

| # | Module | Highlights |
|---|--------|------------|
| 1 | **Repos & NVIDIA** | Universe/multiverse, Brave, GitHub CLI, Flatpak/Flathub, NVIDIA drivers + Vulkan + power rules |
| 2 | **System & CLI** | build-essential, git, Podman, fzf, ripgrep, fd, bat, eza, zoxide, git-delta, lazygit, lazydocker, dust, procs, btm, hyperfine, glow, and more |
| 3 | **Shell** | Starship prompt, synth-shell (managed via standalone `synth-shell-theme`), global aliases, fzf integration, zoxide init, history tuning |
| 4 | **Fonts & Themes** | 25+ Nerd Fonts, Inter, Monaspace, Geist; Dracula & Catppuccin GTK themes; Papirus & Tela icons; Bibata cursors |
| 5 | **GNOME** | Dash to Dock, Blur my Shell, Just Perfection, Caffeine, Clipboard Indicator, Vitals, Space Bar; dark mode, workspace shortcuts, Nautilus tree view |
| 6 | **Cloud & K8s** | AWS CLI v2, gcloud, azure-cli, kubectl, helm, k9s, stern, kubectx/kubens, kustomize, eksctl |
| 7 | **Languages** | nvm + Node LTS, pyenv + Python, rustup, Go, SDKMAN (Java), pipx (black, ruff, mypy, poetry, httpie, tldr) |
| 8 | **Editors** | VSCodium (with ~30 extensions), Neovim + kickstart.nvim, WezTerm (config + process-name tab titles) |
| 9 | **Workspace** | Git (delta, libsecret, rerere, rebase), tmux (Ctrl+A, Dracula status), direnv, editorconfig, SSH defaults |
| 10 | **Tweaks** | swappiness=10, TCP tuning, inotify limits, fstrim, preload, UFW firewall, journal cleanup, helper scripts |

## Usage

**Tip (CI / many VMs):** GitHub’s API rate-limits unauthenticated requests. Export `GITHUB_TOKEN` (classic PAT, no scope needed for public repos) before `setup.sh` so GitHub release downloads stay reliable.

```bash
# Run everything (resumes from last checkpoint)
sudo bash setup.sh

# List available modules
sudo bash setup.sh --list

# Run only specific steps
sudo bash setup.sh --only 2,3,8

# Skip NVIDIA (no GPU)
sudo bash setup.sh --skip 1

# Re-run a single step from scratch
sudo bash setup.sh --reset 5

# Full fresh run (clear all checkpoints)
sudo bash setup.sh --reset
```

## Backup & Restore

**Backup** your current configs (shell, git, starship, tmux, editors, GNOME/dconf, package lists, tool versions) into a timestamped `.tar.gz`:

```bash
bash backup.sh                  # saves to ~/workstation-backups/
bash backup.sh /path/to/dest    # custom destination
```

**Restore** from a backup archive:

```bash
bash restore.sh backup.tar.gz              # restore everything
bash restore.sh backup.tar.gz --dry-run    # preview what would change
bash restore.sh backup.tar.gz --only tmux  # restore only tmux config
```

Available restore sections: `shell`, `git`, `starship`, `synth-shell`, `wezterm`, `tmux`, `wireplumber`, `vscode`, `vscodium`, `nvim`, `ssh`, `direnv`, `misc`, `gnome`, `system`, `extensions`.

Existing files are saved as `*.pre-restore` before being overwritten.

## Synth-Shell Theme Studio (`synth-shell-theme`)

The interactive `synth-shell` Prompt Theme Picker (64 themes), Dual Powerline Separator Editor (48 presets + 60+ Nerd Font glyphs), Runtime Speed Optimizer, and Live Web Studio now live in the standalone, zero-dependency Python package **[synth-shell-theme](https://github.com/mvsoares/synth-shell-theme)** ([PyPI](https://pypi.org/project/synth-shell-theme/)):

```bash
# Install via pipx (provides `synth-shell-theme` and `synth-shell-separator` in PATH)
pipx install synth-shell-theme
# (or local editable dev install: pipx install -e ~/projetos/synth-shell-theme --force)

# Apply all 4 runtime speed & compatibility patches to ~/.config/synth-shell
synth-shell-theme init

# Interactive 2-column 256-color terminal picker
synth-shell-theme

# Live browser-based Web Studio (64 themes + dual separator builder + segment layout)
synth-shell-theme web

# Dedicated interactive Dual Separator & 60+ Nerd Font Glyph Editor
synth-shell-separator

# Direct CLI commands
synth-shell-theme --list
synth-shell-theme --apply tokyo-night
synth-shell-theme --dual round arrow
synth-shell-theme doctor
```

## WezTerm Config (settings as data)

`~/.config/wezterm/wezterm.lua` is a fixed loader: every preference lives in JSON next to it, so tools never regex-edit Lua.

| File | Owner | Purpose |
|------|-------|---------|
| `wezterm.lua` | repo (`lib/wezterm.lua`) | Loader. Replaced on install — do not edit. |
| `defaults.json` | repo (`lib/wezterm-defaults.json`) | Default fonts, tabs, colors, keys, mouse… Replaced on install. |
| `settings.json` | you | Machine overrides, deep-merged over the defaults (objects merge, arrays replace). Never overwritten. |
| `user.lua` | you | Optional code run last: `return function(config, wezterm, settings) … end`. |
| `tab_theme.lua` | `wezterm-theme` | Active tab bar theme module. |

Example `settings.json` for a laptop running WezTerm on X11 with a smaller panel DPI:

```json
{ "display": { "use_x11": true, "dpi_by_screen": { "eDP-1": 216 } } }
```

`display.use_x11` also picks the window decorations (GNOME title bar on X11, integrated buttons on Wayland). Set it back to `false` if X11 windows stop appearing — that means XWayland is broken until the next GNOME login. Options with no dedicated setting go under `"extra": { "option_name": value }`. A broken `settings.json` is logged and ignored, so WezTerm falls back to the defaults. `install-wezterm.sh` and module 08 deploy through `lib/wezterm-deploy.sh`, which backs up a hand-written `wezterm.lua` before switching it to the loader.

## WezTerm Studio (`wezterm-theme`)

The interactive WezTerm Tab Bar Theme Picker (60 themes + Symbol Customizer) and Live Font & Appearance Studio now live in the standalone, cross-platform package **[wezterm-studio](https://github.com/mvsoares/wezterm-studio)** ([PyPI](https://pypi.org/project/wezterm-theme/)):

```bash
# Install from PyPI via pipx (provides `wezterm-theme` and `wezterm-tab-theme` in PATH)
pipx install wezterm-theme
# (or local editable dev install: pipx install -e ~/projetos/wezterm-studio --force)

# Interactive terminal TUI (60 themes, symbol builder, font & scheme pickers)
wezterm-theme

# Unified browser studio (live fonts + 60 tab themes + colors + window settings)
wezterm-theme web

# Direct CLI commands
wezterm-theme --list
wezterm-theme --current
wezterm-theme -s 8 -t 15
wezterm-theme --font "VictorMono Nerd Font Mono" --size 14
wezterm-theme doctor
```

## Project Structure

```
├── setup.sh                        # Main entry point — orchestrates all modules
├── backup.sh                       # Backup current workstation configs
├── restore.sh                      # Restore configs from backup archive
├── lib/
│   ├── common.sh                   # Shared functions (logging, progress, apt helpers)
│   ├── wezterm.lua                 # WezTerm loader: reads defaults.json + settings.json
│   ├── wezterm-defaults.json       # WezTerm default settings (fonts, tabs, keys, mouse…)
│   └── wezterm-deploy.sh           # Installs loader + defaults, keeps user settings
└── modules/
    ├── 01-repos-nvidia.sh
    ├── 02-system-cli.sh
    ├── 03-shell.sh
    ├── 04-fonts-themes.sh
    ├── 05-gnome.sh
    ├── 06-cloud-k8s.sh
    ├── 07-languages.sh
    ├── 08-editors.sh
    ├── 09-workspace.sh
    └── 10-tweaks.sh
```

## How It Works

1. **Checkpoint system** — Each module writes a marker to `/var/cache/workstation-setup/` on success. Re-running skips completed steps automatically.
2. **Modular design** — Modules are sourced in order by `setup.sh`. Each is a self-contained bash script that uses shared helpers from `lib/common.sh`.
3. **Progress tracking** — A visual progress bar shows overall and per-module progress in the terminal.
4. **Error resilience** — Non-fatal failures are counted and logged to `/tmp/workstation-setup-*.log` without halting execution.
5. **User detection** — Runs as root via `sudo` but detects the real user for per-user configs (dotfiles, GNOME settings, language managers).

## Requirements

- Ubuntu 22.04+ (tested on 24.04)
- `sudo` access
- Internet connection

---

## Shortcuts & Cheatsheet

All shortcuts, aliases, and keybindings configured by the setup scripts are documented in **[SHORTCUTS.md](SHORTCUTS.md)**.

---

## License

MIT
