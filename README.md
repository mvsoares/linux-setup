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
| 3 | **Shell** | Starship prompt, synth-shell (30 prompt themes + interactive picker), global aliases, fzf integration, zoxide init, history tuning |
| 4 | **Fonts & Themes** | 25+ Nerd Fonts, Inter, Monaspace, Geist; Dracula & Catppuccin GTK themes; Papirus & Tela icons; Bibata cursors |
| 5 | **GNOME** | Dash to Dock, Blur my Shell, Just Perfection, Caffeine, Clipboard Indicator, Vitals, Space Bar; dark mode, workspace shortcuts, Nautilus tree view |
| 6 | **Cloud & K8s** | AWS CLI v2, gcloud, azure-cli, kubectl, helm, k9s, stern, kubectx/kubens, kustomize, eksctl |
| 7 | **Languages** | nvm + Node LTS, pyenv + Python, rustup, Go, SDKMAN (Java), pipx (black, ruff, mypy, poetry, httpie, tldr) |
| 8 | **Editors** | Cursor IDE, VSCodium (with ~30 extensions), Neovim + kickstart.nvim, WezTerm (config + process-name tab titles) |
| 9 | **Workspace** | Git (delta, libsecret, rerere, rebase), tmux (Ctrl+A, Dracula status), direnv, editorconfig, SSH defaults |
| 10 | **Tweaks** | swappiness=10, TCP tuning, inotify limits, fstrim, preload, UFW firewall, journal cleanup, helper scripts |

## Usage

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

Available restore sections: `shell`, `git`, `starship`, `synth-shell`, `wezterm`, `tmux`, `cursor`, `vscode`, `vscodium`, `nvim`, `ssh`, `direnv`, `misc`, `gnome`, `system`, `extensions`.

Existing files are saved as `*.pre-restore` before being overwritten.

## Synth-Shell Theme Picker

An interactive terminal tool to preview and apply synth-shell prompt color themes — 30 themes with live 256-color powerline previews rendered side-by-side.

```bash
python3 synth-shell-theme-picker.py
```

**What it does:**

- Shows all 30 themes in a 2-column grid with real colored powerline segments
- Auto-detects your current active theme (marked `← active`)
- Backs up your config to `~/.config/synth-shell/backups/` before applying
- Merges only color values — preserves your git symbols, padding, and other settings

**Navigation:** `[n]ext` / `[p]rev` pages, `[1-30]` to apply, `[q]uit`.

**Included themes:** Screenshot Match, Current Live, Dracula Punch, Nord Ice, Matrix Green, Amber Heat, Cloud Ops, Catppuccin Mauve, Solarized Night, Gruvbox Dark, Monokai Neon, Tokyo Night, Synthwave Pink, Forest Mint, Ruby Steel, Ice Gold, Aqua Slate, Cyber Lime, Lavender Sunset, Minimal Mono, Rosé Pine, Kanagawa, Everforest, One Dark, Ayu Dark, Nightfox, Palenight, Cyberdream, Moonlight, Poimandres.

You can also browse all themes visually by opening `synth-shell-color-preview.html` in a browser.

## Project Structure

```
├── setup.sh                        # Main entry point — orchestrates all modules
├── backup.sh                       # Backup current workstation configs
├── restore.sh                      # Restore configs from backup archive
├── synth-shell-theme-picker.py     # Interactive terminal theme picker (30 themes)
├── synth-shell-color-preview.html  # Browser-based theme gallery
├── lib/
│   ├── common.sh                   # Shared functions (logging, progress, apt helpers)
│   ├── wezterm.lua                 # WezTerm terminal config (deployed by module 08)
│   ├── synth-shell-theme-picker.sh # Shell helper for theme selection during setup
│   └── synth-shell-themes/         # 30 prompt color theme .conf files
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
