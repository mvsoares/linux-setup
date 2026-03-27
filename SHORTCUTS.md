# Workstation Cheat Sheet

Quick reference for everything configured by the setup scripts.

---

## Modern CLI Replacements

Classic commands are aliased to modern alternatives when available.

| Classic | Replacement | Alias / Command | What changes |
|---------|-------------|-----------------|--------------|
| `ls` | eza | `ls` | Colorized output with icons |
| `ls -lah` | eza | `ll` | Detailed list with Git status |
| `tree` | eza | `lt` | Directory tree (3 levels deep) |
| `cat` | bat | `cat` | Syntax highlighting, no pager |
| `cat` (full) | bat | `catp` | With line numbers + pager |
| `cd` | zoxide | `z` | Frecency-based smart jump |
| `top` | bottom | `top` / `btm` | Visual system monitor |
| `du` | dust | `du` | Visual directory size |
| `df` | duf | `df` | Readable disk usage |
| `ps` | procs | `pss` | Modern process viewer |
| `find` | fd | `fd` | Fast, user-friendly find |
| `grep` | ripgrep | `rg` | Fast recursive search |

---

## Shell Aliases

### Git

| Alias | Command |
|-------|---------|
| `g` | `git` |
| `gs` | `git status` |
| `ga` | `git add` |
| `gc` | `git commit` |
| `gp` | `git push` |
| `gpl` | `git pull` |
| `gco` | `git checkout` |
| `gsw` | `git switch` |
| `gb` | `git branch` |
| `gst` | `git stash` |
| `gd` | `git diff` (uses **delta** side-by-side) |
| `gl` | `git log --oneline --graph --decorate -20` |
| `lg` | **lazygit** — full Git TUI |
| `lzd` | **lazydocker** — Docker TUI |

### Docker & System

| Alias | Command |
|-------|---------|
| `dk` | `docker` |
| `dkc` | `docker compose` |
| `py` | `python3` |
| `ports` | `ss -tulpn` |
| `myip` | `curl -s ifconfig.me` |
| `please` | `sudo` |
| `update` | Update APT + Snap + Flatpak |
| `pbcopy` | Copy stdin to clipboard |
| `pbpaste` | Paste clipboard to stdout |
| `sysinfo` | System info via inxi / fastfetch |
| `weather` | Weather in terminal |
| `fonts-list` | List all installed fonts |
| `fonts-mono` | List monospace fonts |

### Navigation

| Alias | Command |
|-------|---------|
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `....` | `cd ../../..` |

### Cloud

| Alias | Command |
|-------|---------|
| `awswho` | `aws sts get-caller-identity` |
| `awsp` | Switch AWS profile (fzf picker) |
| `gcpwho` | `gcloud auth list` |
| `gcpp` | Switch GCP project (fzf picker) |
| `azwho` | `az account show` |
| `azp` | Switch Azure subscription (fzf picker) |

### Kubernetes

| Alias | Command |
|-------|---------|
| `k` | `kubectl` |
| `kx` | `kubectx` — switch cluster |
| `kn` | `kubens` — switch namespace |
| `kgp` | `kubectl get pods` |
| `kgs` | `kubectl get svc` |
| `kga` | `kubectl get all` |
| `kdp` | `kubectl describe pod` |
| `klo` | `kubectl logs -f` |
| `kex` | `kubectl exec -it` |

### NVIDIA GPU

| Alias | Command |
|-------|---------|
| `gpu-status` | `nvidia-smi` |
| `gpu-mode` | `prime-select query` |
| `gpu-watch` | `watch -n 1 nvidia-smi` |
| `nvrun <cmd>` | Run command on discrete GPU (offload) |

---

## Shell Functions

| Function | Description |
|----------|-------------|
| `extract <file>` | Auto-extract any archive (zip, tar.gz, rar, 7z, etc.) |
| `mkcd <dir>` | Create directory and `cd` into it |
| `dirsize [path]` | Show total size of a directory |

---

## Keyboard Shortcuts

### fzf (Fuzzy Finder)

| Shortcut | Action |
|----------|--------|
| `Ctrl+R` | Fuzzy search command history |
| `Ctrl+T` | Fuzzy find files and paste path |
| `Alt+C` | Fuzzy `cd` into subdirectory |
| `**<Tab>` | Trigger fzf completion (e.g. `cd **<Tab>`) |

### zoxide (Smart cd)

| Command | Action |
|---------|--------|
| `z foo` | Jump to best match for "foo" |
| `z foo bar` | Jump to dir matching both words |
| `zi foo` | Interactive pick from matches |
| `z -` | Go to previous directory |

### tmux

Prefix: **`Ctrl+A`**

| Shortcut | Action |
|----------|--------|
| `Ctrl+A \|` | Split pane horizontally |
| `Ctrl+A -` | Split pane vertically |
| `Alt+Arrow` | Navigate panes (no prefix needed) |
| `Ctrl+A H/J/K/L` | Resize pane left/down/up/right |
| `Ctrl+A c` | New window (inherits path) |
| `Ctrl+A n` / `p` | Next / previous window |
| `Ctrl+A 1-9` | Switch to window by number |
| `Ctrl+A d` | Detach session |
| `Ctrl+A r` | Reload config |
| `Ctrl+A [` | Enter scroll / copy mode |
| `Ctrl+A ]` | Paste from tmux buffer |

### WezTerm

| Shortcut | Action |
|----------|--------|
| `Super+D` | Split horizontal |
| `Super+Shift+D` | Split vertical |
| `Super+Ctrl+H/J/K/L` | Navigate panes |
| `Super+T` | New tab |
| `Super+[` / `]` | Previous / next tab |
| `Super+W` | Close pane |
| `Super++` / `-` / `0` | Zoom in / out / reset |
| `Super+Ctrl+F` | Toggle fullscreen |
| `Super+F` | Search |

### GNOME Desktop

| Shortcut | Action |
|----------|--------|
| `Super+1` to `Super+4` | Switch to workspace 1–4 |
| `Super+Shift+1` to `4` | Move window to workspace 1–4 |
| `Super+D` | Show desktop |
| `Super+S` | Toggle Activities overview |
| `Super+A` | App launcher |
| `Super+L` | Lock screen |
| `Super+Arrow` | Tile window |
| `Ctrl+Alt+T` | Open terminal |
| `Alt+Tab` | Switch windows |

### VSCode / VSCodium

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+P` | Quick file open |
| `Ctrl+Shift+F` | Search across files |
| `` Ctrl+` `` | Toggle terminal |
| `Ctrl+B` | Toggle sidebar |
| `Ctrl+\` | Split editor |
| `F2` | Rename symbol |
| `Ctrl+.` | Quick fix / code action |
| `Ctrl+Space` | IntelliSense |
| `Alt+Up/Down` | Move line up/down |
| `Ctrl+/` | Toggle line comment |

### Neovim (kickstart.nvim)

Leader key: **`Space`**

| Shortcut | Action |
|----------|--------|
| `Space sf` | Search files |
| `Space sg` | Search by grep |
| `Space sh` | Search help |
| `Space sd` | Search diagnostics |
| `gd` | Go to definition |
| `gr` | Go to references |
| `K` | Hover docs |
| `Space rn` | Rename symbol |
| `Space ca` | Code action |
| `[d` / `]d` | Prev / next diagnostic |

### lazygit

| Key | Action |
|-----|--------|
| `Space` | Stage / unstage file |
| `c` | Commit |
| `P` | Push |
| `p` | Pull |
| `?` | Show all keybindings |

### git-delta

Active automatically in `git diff`, `git log -p`, `git show`.

| Key | Action |
|-----|--------|
| `n` / `N` | Next / previous file |
| `/pattern` | Search |
| `q` | Quit |

---

## AI Coding Agents (CLI)

| Agent | Command | Provider |
|-------|---------|----------|
| Claude Code | `claude` | Anthropic |
| Gemini CLI | `gemini` | Google |
| Codex CLI | `codex` | OpenAI |

---

## Version Managers

| Tool | Common Commands |
|------|-----------------|
| **nvm** | `nvm install --lts`, `nvm use 20`, `nvm list` |
| **pyenv** | `pyenv install 3.12`, `pyenv local 3.12`, `pyenv versions` |
| **rustup** | `rustup update`, `rustup default stable` |
| **sdkman** | `sdk install java`, `sdk use java 21-tem`, `sdk list java` |
| **pipx** | `pipx install black`, `pipx list`, `pipx upgrade-all` |

---

## Helper Scripts

| Command | Description |
|---------|-------------|
| `sysreport` | Full system report (OS, kernel, GPU, language versions) |
| `display-setup info` | Show connected displays and GPU |
| `display-setup gamma 1.1` | Adjust gamma (X11 only) |
| `display-setup brightness 0.9` | Adjust brightness |
| `display-setup reset` | Reset display to defaults |

---

## Environment Tools

- **direnv** — auto-load `.envrc` files when entering a directory (env vars, virtualenvs, nvm)
- **editorconfig** — global `.editorconfig` ensures consistent formatting across editors
- **pre-commit** — Git hooks for linting/formatting before each commit
- **Starship** — cross-shell prompt with Git, language, and cloud context

---

## Quick Tips

> **Smart navigation**: type `z` + part of any folder name. Visit `/home/user/projects/my-app` once, then just `z app` from anywhere.

> **Fuzzy everything**: use `**<Tab>` after any command for fuzzy completion — `cd **<Tab>`, `vim **<Tab>`, `ssh **<Tab>`.

> **One-command updates**: run `update` to refresh APT, Snap, and Flatpak packages in one go.

> **Archive extraction**: `extract file.tar.gz` — works with zip, rar, 7z, tar.*, bz2, gz, and more.
