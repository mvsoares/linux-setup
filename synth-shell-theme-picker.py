#!/usr/bin/env python3
"""Interactive synth-shell theme picker with live terminal preview (side-by-side)."""

import re
import shutil
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

THEMES_DIR = Path(__file__).parent / "lib" / "synth-shell-themes"
CONFIG_PATH = Path.home() / ".config" / "synth-shell" / "synth-shell-prompt.config"
BACKUP_DIR = Path.home() / ".config" / "synth-shell" / "backups"
SEPARATOR = "\ue0b0"  # Powerline triangle

NAMED_COLORS = {
    "black": 0, "red": 1, "green": 2, "yellow": 3,
    "blue": 4, "purple": 5, "cyan": 6, "light-gray": 7,
    "dark-gray": 8, "light-red": 9, "light-green": 10, "light-yellow": 11,
    "light-blue": 12, "light-purple": 13, "light-cyan": 14, "white": 15,
}

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"


def color_index(token: str) -> int | None:
    token = token.strip().strip('"').strip("'").lower()
    if token in ("none", "transparent", ""):
        return None
    if token in NAMED_COLORS:
        return NAMED_COLORS[token]
    try:
        n = int(token)
        if 0 <= n <= 255:
            return n
    except ValueError:
        pass
    return None


def ansi_fg(idx: int | None) -> str:
    return f"\033[38;5;{idx}m" if idx is not None else ""


def ansi_bg(idx: int | None) -> str:
    return f"\033[48;5;{idx}m" if idx is not None else ""


# --- visible width helpers ---

_ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def visible_len(s: str) -> int:
    """Length of string as displayed (strip ANSI, handle wide chars)."""
    plain = _ANSI_RE.sub("", s)
    w = 0
    for ch in plain:
        cat = unicodedata.east_asian_width(ch)
        w += 2 if cat in ("W", "F") else 1
    return w


def pad_to(s: str, width: int) -> str:
    """Pad string with spaces to reach target visible width."""
    diff = width - visible_len(s)
    return s + " " * max(diff, 0)


# --- theme parsing ---

def parse_theme(path: Path) -> dict:
    data = {"_name": "", "_path": path}
    for line in path.read_text().splitlines():
        m = re.match(r"^#\s*Theme\s+\d+:\s*(.+)", line)
        if m:
            data["_name"] = m.group(1).strip()
            continue
        if line.startswith("#") or not line.strip():
            continue
        m = re.match(r'^(\w+)\s*=\s*["\']?([^"\']*)["\']?\s*$', line)
        if m:
            data[m.group(1)] = m.group(2)
    return data


def load_themes() -> list[dict]:
    if not THEMES_DIR.is_dir():
        print(f"Error: themes directory not found: {THEMES_DIR}")
        sys.exit(1)
    files = sorted(THEMES_DIR.glob("*.conf"))
    if not files:
        print(f"Error: no .conf files in {THEMES_DIR}")
        sys.exit(1)
    return [parse_theme(f) for f in files]


# --- rendering ---

def render_segment(text: str, fg: int | None, bg: int | None) -> str:
    parts = []
    if bg is not None:
        parts.append(ansi_bg(bg))
    if fg is not None:
        parts.append(ansi_fg(fg))
    parts.append(BOLD)
    parts.append(f" {text} ")
    return "".join(parts)


def render_separator(prev_bg: int | None, next_bg: int | None) -> str:
    parts = []
    if prev_bg is not None:
        parts.append(ansi_fg(prev_bg))
    if next_bg is not None:
        parts.append(ansi_bg(next_bg))
    else:
        parts.append(RESET)
        if prev_bg is not None:
            parts.append(ansi_fg(prev_bg))
    parts.append(SEPARATOR)
    return "".join(parts)


def render_prompt_line(theme: dict, segments: list[tuple[str, str]], command: str) -> str:
    out = []
    for i, (key, text) in enumerate(segments):
        fg = color_index(theme.get(f"font_color_{key}", "white"))
        bg = color_index(theme.get(f"background_{key}", "0"))
        out.append(render_segment(text, fg, bg))
        next_bg = None
        if i + 1 < len(segments):
            next_key = segments[i + 1][0]
            next_bg = color_index(theme.get(f"background_{next_key}", "0"))
        out.append(render_separator(bg, next_bg))
    input_fg = color_index(theme.get("font_color_input", "white"))
    out.append(RESET)
    if input_fg is not None:
        out.append(ansi_fg(input_fg))
    out.append(BOLD)
    out.append(f" {command}")
    out.append(RESET)
    return "".join(out)


def build_card_lines(theme: dict, index: int, total: int, current_name: str | None) -> list[str]:
    """Return the lines for a single theme card (no printing)."""
    name = theme.get("_name", "Unknown")
    tag = ""
    if current_name and name == current_name:
        tag = f"  \033[33;1m← active{RESET}"

    num_label = f"{BOLD}{DIM}#{index:<2}{RESET}"
    lines = [
        f"{num_label} {BOLD}{name}{RESET}{tag}",
        render_prompt_line(
            theme,
            [("host", "mvsoares"), ("pwd", "~/proj/setup"), ("git", "main")],
            "git status",
        ),
        render_prompt_line(
            theme,
            [("host", "mvsoares"), ("pwd", "~/api"), ("git", "feat ◔"), ("pyenv", "venv"), ("tf", "prod"), ("kube", "gke")],
            "kubectl get pods",
        ),
    ]
    return lines


# --- side-by-side layout ---

GUTTER = "   "  # space between columns


def print_side_by_side(cards: list[list[str]], cols: int, col_width: int) -> None:
    """Print cards arranged in a grid of `cols` columns."""
    # Process cards in rows of `cols`
    for row_start in range(0, len(cards), cols):
        row_cards = cards[row_start : row_start + cols]
        max_lines = max(len(c) for c in row_cards)
        # Pad all cards to same number of lines
        for c in row_cards:
            while len(c) < max_lines:
                c.append("")
        # Print line by line
        for line_idx in range(max_lines):
            parts = []
            for card_idx, card in enumerate(row_cards):
                cell = pad_to(card[line_idx], col_width)
                parts.append(cell)
            print(GUTTER.join(parts))
        print()  # blank line between rows


def detect_current_theme(themes: list[dict]) -> str | None:
    if not CONFIG_PATH.exists():
        return None
    current = {}
    for line in CONFIG_PATH.read_text().splitlines():
        m = re.match(r'^(font_color_\w+|background_\w+)\s*=\s*["\']?([^"\']*)["\']?', line)
        if m:
            current[m.group(1)] = m.group(2).strip()
    if not current:
        return None

    color_keys = [
        "font_color_host", "background_host",
        "font_color_pwd", "background_pwd",
        "font_color_git", "background_git",
        "font_color_input", "background_input",
    ]
    best_score = 0
    best_name = None
    for theme in themes:
        score = sum(1 for k in color_keys if theme.get(k, "").lower() == current.get(k, "").lower())
        if score > best_score:
            best_score = score
            best_name = theme["_name"]
    return best_name if best_score >= 6 else None


def backup_config() -> Path | None:
    if not CONFIG_PATH.exists():
        return None
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    dest = BACKUP_DIR / f"synth-shell-prompt.config.{stamp}.bak"
    shutil.copy2(CONFIG_PATH, dest)
    return dest


def apply_theme(theme: dict) -> None:
    if not CONFIG_PATH.exists():
        print(f"  Config not found at {CONFIG_PATH} — writing fresh from theme file.")
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(theme["_path"], CONFIG_PATH)
        return

    theme_keys = {k for k in theme if not k.startswith("_")}
    lines = CONFIG_PATH.read_text().splitlines()
    new_lines = []
    updated = set()
    for line in lines:
        m = re.match(r'^(\w+)\s*=', line)
        if m and m.group(1) in theme_keys:
            key = m.group(1)
            val = theme[key]
            if "'" in line and '"' not in line:
                new_lines.append(f"{key}='{val}'")
            else:
                new_lines.append(f'{key}="{val}"')
            updated.add(key)
        else:
            new_lines.append(line)

    missing = theme_keys - updated
    if missing:
        new_lines.append("")
        for key in sorted(missing):
            new_lines.append(f'{key}="{theme[key]}"')

    CONFIG_PATH.write_text("\n".join(new_lines) + "\n")


def main():
    themes = load_themes()
    total = len(themes)
    current_name = detect_current_theme(themes)

    term_cols = shutil.get_terminal_size((120, 24)).columns

    # 2-column layout, 5 rows per column = 10 per page
    col_width = 72
    num_cols = 2 if term_cols >= col_width * 2 + len(GUTTER) else 1
    if num_cols == 1:
        col_width = term_cols - 2

    per_page = num_cols * 5  # 5 rows × 2 columns = 10 per page
    total_pages = (total + per_page - 1) // per_page
    page = 0

    print()
    print(f"{BOLD}  Synth-Shell Theme Picker{RESET}  —  {total} themes  |  {num_cols}-column layout")
    if current_name:
        print(f"  Current theme: \033[33;1m{current_name}\033[0m")
    print(f"  Config: {CONFIG_PATH}")
    print()

    while True:
        # Build cards for current page
        start = page * per_page
        end = min(start + per_page, total)
        cards = []
        for i in range(start, end):
            cards.append(build_card_lines(themes[i], i + 1, total, current_name))

        print_side_by_side(cards, num_cols, col_width)

        # Navigation
        nav = []
        if page > 0:
            nav.append("[p]rev")
        if (page + 1) < total_pages:
            nav.append("[n]ext")
        nav.append(f"[1-{total}] apply")
        nav.append("[q]uit")

        page_info = f"  Page {page + 1}/{total_pages}" if total_pages > 1 else " "
        try:
            choice = input(f"{page_info}  {' | '.join(nav)}: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print("\n  Cancelled.")
            return

        if choice in ("q", "quit", "exit"):
            print("  Bye.")
            return
        elif choice in ("n", "next"):
            if (page + 1) < total_pages:
                page += 1
                print()
        elif choice in ("p", "prev", "b", "back"):
            if page > 0:
                page -= 1
                print()
        elif choice.isdigit():
            num = int(choice)
            if 1 <= num <= total:
                selected = themes[num - 1]
                name = selected.get("_name", "Unknown")
                print()
                print(f"  Selected: {BOLD}{name}{RESET}")
                bak = backup_config()
                if bak:
                    print(f"  Backup:   {bak}")
                apply_theme(selected)
                print(f"  Applied:  {CONFIG_PATH}")
                print()
                print(f"  {BOLD}Open a new terminal tab to see the change.{RESET}")
                print()
                return
            else:
                print(f"  Pick 1-{total}.")
        else:
            print(f"  Unknown: {choice}")
        print()


if __name__ == "__main__":
    main()
