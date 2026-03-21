# Keyboard Shortcuts & Cheatsheet

Everything configured by the workstation setup scripts.

---

## Terminal — fzf

| Shortcut     | Action                                    |
|--------------|-------------------------------------------|
| `Ctrl+R`     | Fuzzy search command history              |
| `Ctrl+T`     | Fuzzy find files/dirs and paste to prompt |
| `Alt+C`      | Fuzzy cd into subdirectory                |
| `**<Tab>`    | Trigger fzf completion (e.g. `cd **<Tab>`) |

## Terminal — zoxide (cd replacement)

| Command        | Action                               |
|----------------|--------------------------------------|
| `z foo`        | Jump to best-matching dir "foo"      |
| `z foo bar`    | Jump to dir matching "foo" and "bar" |
| `zi foo`       | Interactive pick from matches (fzf)  |
| `z -`          | Go to previous directory             |

## Terminal — tmux

Prefix key: **Ctrl+A** (not the default Ctrl+B)

| Shortcut            | Action                          |
|---------------------|---------------------------------|
| `Ctrl+A \|`         | Split pane horizontally         |
| `Ctrl+A -`          | Split pane vertically           |
| `Alt+Arrow`         | Navigate panes (no prefix)      |
| `Ctrl+A H/J/K/L`   | Resize pane Left/Down/Up/Right  |
| `Ctrl+A c`          | New window (inherits path)      |
| `Ctrl+A n / p`      | Next / previous window          |
| `Ctrl+A 1-9`        | Switch to window by number      |
| `Ctrl+A d`          | Detach session                  |
| `Ctrl+A r`          | Reload tmux config              |
| `Ctrl+A [`          | Enter scroll/copy mode          |
| `Ctrl+A ]`          | Paste from tmux buffer          |

## Terminal — bat / cat

| Command            | Action                          |
|--------------------|---------------------------------|
| `cat file`         | View with syntax highlighting (plain, no pager) |
| `catp file`        | Full bat with line numbers + pager |
| `bat -l json file` | Force a specific language        |

## Terminal — lazygit / lazydocker

| Command | Action                    |
|---------|---------------------------|
| `lg`    | Launch lazygit            |
| `lzd`   | Launch lazydocker         |

Inside lazygit:

| Key       | Action                    |
|-----------|---------------------------|
| `Space`   | Stage/unstage file        |
| `c`       | Commit                    |
| `P`       | Push                      |
| `p`       | Pull                      |
| `?`       | Show all keybindings      |

## Terminal — git-delta

Active automatically in `git diff`, `git log -p`, `git show`.

| Shortcut     | Action (inside delta pager)         |
|--------------|-------------------------------------|
| `n`          | Jump to next file                   |
| `N`          | Jump to previous file               |
| `q`          | Quit                                |
| `/pattern`   | Search                              |

## Shell Aliases — Git

| Alias  | Command                              |
|--------|--------------------------------------|
| `g`    | `git`                                |
| `gs`   | `git status`                         |
| `ga`   | `git add`                            |
| `gc`   | `git commit`                         |
| `gp`   | `git push`                           |
| `gpl`  | `git pull`                           |
| `gco`  | `git checkout`                       |
| `gsw`  | `git switch`                         |
| `gb`   | `git branch`                         |
| `gst`  | `git stash`                          |
| `gd`   | `git diff`                           |
| `gl`   | `git log --oneline --graph`          |

## Shell Aliases — Modern Replacements

| Alias    | Replaces | Tool      |
|----------|----------|-----------|
| `cat`    | cat      | bat       |
| `ls`     | ls       | eza       |
| `ll`     | ls -lah  | eza       |
| `lt`     | tree     | eza       |
| `cd`     | cd       | zoxide    |
| `du`     | du       | dust      |
| `df`     | df       | duf       |
| `grep`   | grep     | ripgrep   |
| `fd`     | find     | fd-find   |
| `pss`    | ps       | procs     |
| `top`    | top      | bottom    |

## Shell Aliases — Docker & System

| Alias      | Command                        |
|------------|--------------------------------|
| `dk`       | `docker`                       |
| `dkc`      | `docker compose`               |
| `py`       | `python3`                      |
| `ports`    | `ss -tulpn`                    |
| `myip`     | `curl -s ifconfig.me`          |
| `please`   | `sudo`                         |
| `update`   | apt update + upgrade + snap + flatpak |
| `pbcopy`   | Copy to clipboard              |
| `pbpaste`  | Paste from clipboard           |
| `sysinfo`  | System info (inxi/fastfetch)   |
| `weather`  | Weather in terminal            |

## Shell Aliases — Cloud

| Alias/Func    | Action                              |
|---------------|-------------------------------------|
| `awswho`      | `aws sts get-caller-identity`       |
| `awsp`        | Switch AWS profile (fzf)            |
| `gcpwho`      | `gcloud auth list`                  |
| `gcpp`        | Switch GCP project (fzf)            |
| `azwho`       | `az account show`                   |
| `azp`         | Switch Azure subscription (fzf)     |

## Shell Aliases — Kubernetes

| Alias  | Command                        |
|--------|--------------------------------|
| `k`    | `kubectl`                      |
| `kx`   | `kubectx` (switch cluster)     |
| `kn`   | `kubens` (switch namespace)    |
| `kgp`  | `kubectl get pods`             |
| `kgs`  | `kubectl get svc`              |
| `kga`  | `kubectl get all`              |
| `kdp`  | `kubectl describe pod`         |
| `klo`  | `kubectl logs -f`              |
| `kex`  | `kubectl exec -it`             |

## Shell Aliases — NVIDIA GPU

| Alias        | Action                          |
|--------------|---------------------------------|
| `gpu-status` | `nvidia-smi`                    |
| `gpu-mode`   | `prime-select query`            |
| `gpu-watch`  | `watch -n 1 nvidia-smi`        |
| `nvrun cmd`  | Run command on discrete GPU     |

## Shell Functions

| Function          | Action                                 |
|-------------------|----------------------------------------|
| `extract file`    | Auto-extract any archive format        |
| `mkcd dirname`    | Create directory and cd into it        |
| `dirsize [path]`  | Show directory size                    |

## Helper Scripts

| Command          | Action                                  |
|------------------|-----------------------------------------|
| `sysreport`      | Full system report (OS, GPU, langs)     |
| `display-setup`  | Display gamma/brightness control        |
| `display-setup info`      | Show connected displays        |
| `display-setup gamma 1.1` | Adjust gamma                   |
| `display-setup brightness 0.9` | Adjust brightness          |
| `display-setup reset`     | Reset to defaults              |

---

## GNOME Desktop

| Shortcut               | Action                          |
|------------------------|---------------------------------|
| `Super+1` to `Super+4` | Switch to workspace 1-4        |
| `Super+Shift+1-4`      | Move window to workspace 1-4   |
| `Super+D`              | Show desktop                    |
| `Super+S`              | Toggle Activities overview      |
| `Super+A`              | App launcher                    |
| `Super+L`              | Lock screen                     |
| `Super+Tab`            | Switch applications             |
| `Alt+Tab`              | Switch windows                  |
| `Alt+F2`               | Run dialog                      |
| `Ctrl+Alt+T`           | Open terminal                   |
| `Super+Arrow`          | Tile window (edge tiling)       |
| `Double-click titlebar`| Toggle maximize                 |
| `Middle-click titlebar`| Minimize                        |

## Cursor / VSCode / VSCodium

| Shortcut             | Action                           |
|----------------------|----------------------------------|
| `Ctrl+Shift+P`      | Command palette                  |
| `Ctrl+P`            | Quick file open                  |
| `Ctrl+Shift+F`      | Search across files              |
| `Ctrl+`` `           | Toggle terminal                  |
| `Ctrl+B`            | Toggle sidebar                   |
| `Ctrl+\`            | Split editor                     |
| `Ctrl+Shift+E`      | File explorer                    |
| `Ctrl+Shift+G`      | Source control (Git)             |
| `Ctrl+Shift+X`      | Extensions                       |
| `Ctrl+K Ctrl+S`     | Keyboard shortcuts               |
| `F2`                | Rename symbol                     |
| `Ctrl+.`            | Quick fix / code action           |
| `Ctrl+Space`        | Trigger IntelliSense              |
| `Alt+Up/Down`       | Move line up/down                 |
| `Ctrl+Shift+K`      | Delete line                       |
| `Ctrl+/`            | Toggle line comment               |
| `Ctrl+Shift+A`      | Toggle block comment              |

## Neovim (kickstart.nvim)

| Shortcut         | Action                            |
|------------------|-----------------------------------|
| `Space`          | Leader key                        |
| `Space sf`       | Search files                      |
| `Space sg`       | Search by grep                    |
| `Space sh`       | Search help                       |
| `Space sd`       | Search diagnostics                |
| `gd`             | Go to definition                  |
| `gr`             | Go to references                  |
| `K`              | Hover documentation               |
| `Space rn`       | Rename symbol                     |
| `Space ca`       | Code action                       |
| `[d` / `]d`      | Previous / next diagnostic       |

---

## Version Managers — Quick Reference

| Tool     | Common Commands                                    |
|----------|----------------------------------------------------|
| **nvm**  | `nvm install --lts`, `nvm use 20`, `nvm list`     |
| **pyenv**| `pyenv install 3.12`, `pyenv local 3.12`          |
| **rustup**| `rustup update`, `rustup default stable`          |
| **sdkman**| `sdk install java`, `sdk use java 21-tem`         |
| **pipx** | `pipx install black`, `pipx list`                 |
