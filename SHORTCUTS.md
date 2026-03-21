# 🚀 Workstation CLI Cheat Sheet & Reference

Your environment has been upgraded with modern Rust-based tools and ergonomic aliases. Use this guide to navigate your new "superpowers."

---

## 🛠️ Modern Tool Overrides (The "New Standards")
We've replaced several classic GNU utilities with faster, more visual alternatives.

| Classic Command | **Modern Upgrade** | Description |
| :--- | : :--- | :--- |
| `ls` | **`ls`** (eza) | Colorized output with icons. |
| `ls -lah` | **`ll`** | Detailed list with Git status and icons. |
| `tree` | **`lt`** | 3-level deep directory tree with icons. |
| `cat` | **`cat`** (bat) | Syntax highlighting and Git integration. |
| `cd` | **`z`** (zoxide) | "Smart" jumping. Use `z project` to go to a deep folder. |
| `top` | **`top`** (btm) | Visual, interactive system monitor (Bottom). |
| `ps` | **`pss`** (procs) | Modern process search with color coding. |
| `du` | **`du`** (dust) | Visual directory size analyzer. |
| `df` | **`df`** (duf) | User-friendly disk usage summary. |

---

## 🪄 The "Magic" Helpers
Custom functions and environment managers built into your shell.

*   **`direnv`** : Just create a `.envrc` file in a project. The shell will **auto-load** variables, virtualenvs, or `nvm` versions when you `cd` into the folder.
*   **`extract <file>`** : One command to rule them all. Extracts `.zip`, `.tar.gz`, `.rar`, `.7z`, etc.
*   **`mkcd <dir>`** : Create a directory and enter it immediately.
*   **`nvrun <cmd>`** : Run a heavy app (like a game or Blender) using your **NVIDIA GPU** (Offload mode).
*   **`update`** : One command to update APT, Snaps, and Flatpaks at once.
*   **`pbcopy` / `pbpaste`** : Copy/Paste terminal output to your system clipboard.
*   **`sysreport`** : Generates a summary of your OS, Kernel, and Dev Runtimes.

---

## 🔍 Terminal Navigation & Search

### fzf (Fuzzy Finder)
| Shortcut     | Action                                    |
|--------------|-------------------------------------------|
| `Ctrl+R`     | Fuzzy search command history              |
| `Ctrl+T`     | Fuzzy find files/dirs and paste to prompt |
| `Alt+C`      | Fuzzy cd into subdirectory                |
| `**<Tab>`    | Trigger fzf completion (e.g. `cd **<Tab>`) |

### zoxide (Smart CD)
| Command        | Action                               |
|----------------|--------------------------------------|
| `z foo`        | Jump to best-matching dir "foo"      |
| `z foo bar`    | Jump to dir matching "foo" and "bar" |
| `zi foo`       | Interactive pick from matches (fzf)  |
| `z -`          | Go to previous directory             |

---

## 🪟 Terminal Multiplexing (tmux)
Prefix key: **Ctrl+A** (not the default Ctrl+B)

| Shortcut            | Action                          |
|---------------------|---------------------------------|
| `Ctrl+A \|`         | Split pane horizontally         |
| `Ctrl+A -`          | Split pane vertically           |
| `Alt+Arrow`         | Navigate panes (no prefix)      |
| `Ctrl+A H/J/K/L`    | Resize pane Left/Down/Up/Right  |
| `Ctrl+A c`          | New window (inherits path)      |
| `Ctrl+A n / p`      | Next / previous window          |
| `Ctrl+A d`          | Detach session                  |
| `Ctrl+A r`          | Reload tmux config              |
| `Ctrl+A [`          | Enter scroll/copy mode          |

---

## 🌿 Git Productivity

| Alias  | Command                              |
|--------|--------------------------------------|
| `lg`   | **LazyGit** (TUI for Git)            |
| `gs`   | `git status`                         |
| `gl`   | `git log --oneline --graph`          |
| `gd`   | `git diff` (uses **delta** for side-by-side) |

*Inside **LazyGit** (`lg`):* `Space` to stage, `c` to commit, `P` to push.

---

## ☁️ Cloud & Kubernetes

| Alias/Func    | Action                              |
|---------------|-------------------------------------|
| `awsp`        | Switch AWS profile (fzf)            |
| `gcpp`        | Switch GCP project (fzf)            |
| `k`           | `kubectl`                           |
| `kx` / `kn`   | Switch Cluster / Namespace          |
| `klo`         | Tail logs (`kubectl logs -f`)       |

---

## 🖥️ Desktop & Editors

### GNOME Shortcuts
| Shortcut               | Action                          |
|------------------------|---------------------------------|
| `Super+1-4`            | Switch Workspace                |
| `Ctrl+Alt+T`           | Open Terminal                   |
| `Super+Arrow`          | Snap/Tile window                |

### Cursor / VSCode
| Shortcut             | Action                           |
|----------------------|----------------------------------|
| `Ctrl+Shift+P`       | Command palette                  |
| `Ctrl+P`             | Quick file open                  |
| `Ctrl+`` `            | Toggle terminal                  |

---

## 💡 Pro-Tip for New Devs
> **Don't remember the full path?** Just type `z` followed by a part of the folder name. For example, if you frequently visit `/home/user/projects/my-awesome-app`, just type **`z awesome`** from anywhere. The system "learns" your habits!
