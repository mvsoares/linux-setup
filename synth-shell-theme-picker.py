#!/usr/bin/env python3
"""Interactive synth-shell theme picker with live terminal preview (side-by-side)."""

import argparse
import random
import re
import shutil
import sys
import unicodedata
import webbrowser
from datetime import datetime
from pathlib import Path

THEMES_DIR = Path(__file__).parent / "lib" / "synth-shell-themes"
CONFIG_PATH = Path.home() / ".config" / "synth-shell" / "synth-shell-prompt.config"
BACKUP_DIR = Path.home() / ".config" / "synth-shell" / "backups"
HTML_PATH = Path(__file__).parent / "synth-shell-color-preview.html"
SEPARATOR_STYLES = {
    "arrow":   ("\ue0b0", "\\uE0B0", "Classic Triangle Arrow"),
    "round":   ("\ue0b4", "\\uE0B4", "Rounded Bubble / Capsule"),
    "slant":   ("\ue0bc", "\\uE0BC", "Angled Slant (Forward)"),
    "flame":   ("\ue0c0", "\\uE0C0", "Flame / Fire Spikes"),
    "pixel":   ("\ue0c4", "\\uE0C4", "8-Bit Pixel / Lego"),
    "wave":    ("\ue0ca", "\\uE0CA", "Sine Wave / S-Curve"),
    "hex":     ("\ue0cc", "\\uE0CC", "Hexagon / Honeycomb"),
    "ice":     ("\ue0c8", "\\uE0C8", "Ice / Trapezoid Notch"),
    "slash":   ("\u2571", "\\u2571", "Diagonal Line Slash"),
    "chevron": ("\u00bb", "\\u00BB", "Double Chevron Arrow"),
}


def detect_current_separator() -> str:
    """Return the separator character currently configured in CONFIG_PATH."""
    if not CONFIG_PATH.exists():
        return "\ue0b0"
    for line in CONFIG_PATH.read_text().splitlines():
        m = re.match(r"^separator_char\s*=\s*['\"]?(.*?)['\"]?\s*$", line)
        if m:
            val = m.group(1).strip()
            if re.match(r"^\\u[0-9a-fA-F]{4}$", val):
                try:
                    return chr(int(val[2:], 16))
                except ValueError:
                    pass
            if val:
                return val
    return "\ue0b0"


def get_separator_key(glyph: str) -> str:
    for key, (g, _, _) in SEPARATOR_STYLES.items():
        if g == glyph:
            return key
    return "custom"


def find_separator(query: str | int) -> tuple[str, str, str, str] | None:
    """Find separator by 1-based index or key name. Returns (key, glyph, code_str, desc)."""
    items = list(SEPARATOR_STYLES.items())
    q = str(query).strip().lower()
    if q.isdigit():
        idx = int(q)
        if 1 <= idx <= len(items):
            key, (glyph, code, desc) = items[idx - 1]
            return key, glyph, code, desc
        return None
    for key, (glyph, code, desc) in items:
        if q in (key, key.replace("-", ""), glyph, desc.lower()):
            return key, glyph, code, desc
    for key, (glyph, code, desc) in items:
        if q in key or q in desc.lower():
            return key, glyph, code, desc
    return None


SEPARATOR = detect_current_separator()

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

def is_color_key(k: str) -> bool:
    """True if key is a color setting (avoids clobbering format, padding, separators)."""
    return (k.startswith("font_color_") or k.startswith("background_")) and not k.startswith("_")


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


def render_separator(prev_bg: int | None, next_bg: int | None, sep: str | None = None) -> str:
    parts = []
    if prev_bg is not None:
        parts.append(ansi_fg(prev_bg))
    if next_bg is not None:
        parts.append(ansi_bg(next_bg))
    else:
        parts.append(RESET)
        if prev_bg is not None:
            parts.append(ansi_fg(prev_bg))
    parts.append(sep if sep is not None else SEPARATOR)
    return "".join(parts)


def render_prompt_line(theme: dict, segments: list[tuple[str, str]], command: str, sep: str | None = None) -> str:
    out = []
    sep_char = sep if sep is not None else SEPARATOR
    for i, (key, text) in enumerate(segments):
        fg = color_index(theme.get(f"font_color_{key}", "white"))
        bg = color_index(theme.get(f"background_{key}", "0"))
        out.append(render_segment(text, fg, bg))
        next_bg = None
        if i + 1 < len(segments):
            next_key = segments[i + 1][0]
            next_bg = color_index(theme.get(f"background_{next_key}", "0"))
        out.append(render_separator(bg, next_bg, sep=sep_char))
    input_fg = color_index(theme.get("font_color_input", "white"))
    out.append(RESET)
    if input_fg is not None:
        out.append(ansi_fg(input_fg))
    out.append(BOLD)
    out.append(f" {command}")
    out.append(RESET)
    return "".join(out)


def build_card_lines(theme: dict, index: int, total: int, current_name: str | None, sep: str | None = None) -> list[str]:
    """Return the lines for a single theme card (no printing)."""
    name = theme.get("_name", "Unknown")
    tag = ""
    if current_name and name == current_name:
        tag = f"  \033[33;1m← active{RESET}"

    h_bg = color_index(theme.get("background_host", "0"))
    p_bg = color_index(theme.get("background_pwd", "0"))
    g_bg = color_index(theme.get("background_git", "0"))
    swatch = f" {ansi_bg(h_bg)}  {ansi_bg(p_bg)}  {ansi_bg(g_bg)}  {RESET}"

    num_label = f"{BOLD}{DIM}#{index:02d}{RESET}"
    lines = [
        f"{num_label} {BOLD}{name}{RESET}{swatch}{tag}",
        render_prompt_line(
            theme,
            [("host", "mvsoares"), ("pwd", "~/proj/setup"), ("git", "main")],
            "git status",
            sep=sep,
        ),
        render_prompt_line(
            theme,
            [("host", "mvsoares"), ("pwd", "~/api"), ("git", "feat ◔"), ("pyenv", "venv"), ("tf", "prod"), ("kube", "gke")],
            "kubectl get pods",
            sep=sep,
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
    """Applies theme to CONFIG_PATH, strictly updating color keys and preserving custom settings."""
    if not CONFIG_PATH.exists():
        print(f"  Config not found at {CONFIG_PATH} — writing fresh from theme file.")
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(theme["_path"], CONFIG_PATH)
        return

    # Strictly filter to color keys to preserve format, padding, separators, etc.
    theme_keys = {k for k in theme if is_color_key(k)}
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


def apply_and_report(theme: dict, index: int | None = None) -> None:
    """Apply selected theme with backup and clear session reload guidance."""
    name = theme.get("_name", "Unknown")
    idx_str = f" (#{index})" if index else ""
    print()
    print(f"  Selected: {BOLD}{name}{RESET}{idx_str}")
    bak = backup_config()
    if bak:
        print(f"  Backup:   {bak}")
    apply_theme(theme)
    print(f"  Applied:  {CONFIG_PATH}")
    print()
    print(f"  {BOLD}Theme applied successfully!{RESET}")
    print(f"  To reload prompt in your current terminal session:")
    print(f"    {BOLD}source ~/.config/synth-shell/synth-shell-prompt.sh{RESET}")
    print(f"  (or open a new terminal tab)")
    print()


# --- search & selection helpers ---

def find_theme(query: str | int, themes: list[dict]) -> tuple[dict | None, int | None]:
    """Find theme by 1-based index, slug, or name. Returns (theme, 1-based index)."""
    if isinstance(query, int) or (isinstance(query, str) and query.strip().isdigit()):
        idx = int(query)
        if 1 <= idx <= len(themes):
            return themes[idx - 1], idx
        return None, None

    q = str(query).strip().lower().replace("-", " ").replace("_", " ")
    if not q:
        return None, None

    # 1. Exact match on name
    for i, t in enumerate(themes, 1):
        t_name = t.get("_name", "").lower().replace("-", " ").replace("_", " ")
        if t_name == q:
            return t, i

    # 2. Match on filename stem (e.g. 12-tokyo-night -> tokyo night)
    for i, t in enumerate(themes, 1):
        stem = t["_path"].stem.lower().replace("-", " ").replace("_", " ")
        clean_stem = re.sub(r"^\d+\s*", "", stem)
        if clean_stem == q or stem == q:
            return t, i

    # 3. Substring match
    matches = []
    for i, t in enumerate(themes, 1):
        t_name = t.get("_name", "").lower()
        stem = t["_path"].stem.lower()
        if q in t_name or q in stem:
            matches.append((t, i))
    if len(matches) == 1:
        return matches[0]

    return None, None


def filter_themes(query: str, themes: list[dict]) -> list[tuple[int, dict]]:
    """Return list of (1-based-index, theme) matching query."""
    q = query.strip().lower()
    if not q:
        return [(i, t) for i, t in enumerate(themes, 1)]
    results = []
    for i, t in enumerate(themes, 1):
        name = t.get("_name", "").lower()
        stem = t["_path"].stem.lower()
        if q in name or q in stem:
            results.append((i, t))
    return results


def print_theme_list(themes: list[dict], current_name: str | None) -> None:
    """Print clean list of all themes with color swatches and active marker."""
    print()
    print(f"{BOLD}  Synth-Shell Themes Gallery ({len(themes)} themes){RESET}")
    print(f"  {DIM}Host · PWD · Git swatches (256-color){RESET}")
    print()
    for i, t in enumerate(themes, 1):
        name = t.get("_name", "Unknown")
        h_bg = color_index(t.get("background_host", "0"))
        p_bg = color_index(t.get("background_pwd", "0"))
        g_bg = color_index(t.get("background_git", "0"))
        swatch = f"{ansi_bg(h_bg)}  {ansi_bg(p_bg)}  {ansi_bg(g_bg)}  {RESET}"
        active = f"  \033[33;1m← active{RESET}" if current_name and name == current_name else ""
        print(f"  {BOLD}#{i:02d}{RESET}  {swatch}  {name}{active}")
    print()


def apply_separator(key: str, glyph: str, code_str: str) -> None:
    """Save selected separator to CONFIG_PATH and update global SEPARATOR."""
    global SEPARATOR
    SEPARATOR = glyph
    if not CONFIG_PATH.exists():
        return
    lines = CONFIG_PATH.read_text().splitlines()
    new_lines = []
    found = False
    for line in lines:
        if re.match(r"^separator_char\s*=", line):
            new_lines.append(f'separator_char="{code_str}"')
            found = True
        else:
            new_lines.append(line)
    if not found:
        new_lines.append(f'separator_char="{code_str}"')
    CONFIG_PATH.write_text("\n".join(new_lines) + "\n")


def print_separator_list(themes: list[dict], current_sep: str) -> None:
    """Print showcase of all 10 separator styles rendered with live sample prompts."""
    demo_theme = next((t for t in themes if "Tokyo Night" in t.get("_name", "")), themes[0])
    theme_name = demo_theme.get("_name", "Default")

    print()
    print(f"{BOLD}  Synth-Shell Powerline Separator Styles (10 styles){RESET}")
    print(f"  {DIM}Rendered with '{theme_name}' color scheme:{RESET}")
    print()
    for idx, (key, (glyph, code, desc)) in enumerate(SEPARATOR_STYLES.items(), 1):
        active = f"  \033[33;1m← active{RESET}" if glyph == current_sep else ""
        sample = render_prompt_line(demo_theme, [("host", "mvsoares"), ("pwd", "~/proj/setup"), ("git", "main")], "git status", sep=glyph)
        print(f"  {BOLD}#{idx:02d}{RESET}  {glyph}  {BOLD}{key:<8}{RESET}  ({code})  {desc}{active}")
        print(f"       {sample}")
        print()


def interactive_separator_menu(themes: list[dict]) -> tuple[str, str, str, str] | None:
    """Display interactive submenu to preview and select a Powerline separator style."""
    cur_sep = detect_current_separator()
    demo_theme = next((t for t in themes if "Tokyo Night" in t.get("_name", "")), themes[0])

    if sys.stdout.isatty():
        sys.stdout.write("\033[H\033[2J")
        sys.stdout.flush()
    else:
        print()

    print(f"{BOLD}  Synth-Shell Powerline Separators (10 styles){RESET}")
    print(f"  {DIM}Pick a separator glyph for your prompt segments:{RESET}")
    print()

    items = list(SEPARATOR_STYLES.items())
    for idx, (key, (glyph, code, desc)) in enumerate(items, 1):
        active = f"  \033[33;1m← active{RESET}" if glyph == cur_sep else ""
        sample = render_prompt_line(demo_theme, [("host", "mvsoares"), ("pwd", "~/proj/setup"), ("git", "main")], "git status", sep=glyph)
        print(f"  {BOLD}#{idx:02d}{RESET}  {glyph}  {BOLD}{key:<8}{RESET}  ({code})  {desc}{active}")
        print(f"       {sample}")
        print()

    try:
        choice = input(f"  Pick separator [1-{len(items)} or name] (Enter to keep): ").strip()
    except (EOFError, KeyboardInterrupt):
        return None

    if not choice:
        return None

    sep = find_separator(choice)
    return sep


# --- interactive picker ---

def interactive_picker(themes: list[dict], clear_screen_enabled: bool = True, initial_filter: str = "") -> None:
    current_name = detect_current_theme(themes)
    filter_query = initial_filter
    total_all = len(themes)
    page = 0
    status_msg = ""

    while True:
        # Determine items based on filter
        filtered_items = filter_themes(filter_query, themes) if filter_query else [(i, t) for i, t in enumerate(themes, 1)]
        total = len(filtered_items)

        term_cols = shutil.get_terminal_size((120, 24)).columns
        col_width = 72
        num_cols = 2 if term_cols >= col_width * 2 + len(GUTTER) else 1
        if num_cols == 1:
            col_width = term_cols - 2

        per_page = num_cols * 5
        total_pages = max(1, (total + per_page - 1) // per_page)
        if page >= total_pages:
            page = total_pages - 1

        if clear_screen_enabled and sys.stdout.isatty():
            sys.stdout.write("\033[H\033[2J")
            sys.stdout.flush()
        else:
            print()

        # Header
        filter_badge = f"  |  Filter: \033[36;1m'{filter_query}'\033[0m ({total} matches)" if filter_query else ""
        cur_sep_key = get_separator_key(SEPARATOR)
        sep_badge = f"  |  Sep: \033[36;1m{SEPARATOR} {cur_sep_key}\033[0m"
        print(f"{BOLD}  Synth-Shell Theme Picker{RESET}  —  {total_all} themes{filter_badge}{sep_badge}  |  {num_cols}-column layout")
        if current_name:
            print(f"  Current theme: \033[33;1m{current_name}\033[0m")
        print(f"  Config: {CONFIG_PATH}")
        print()

        if total == 0:
            print(f"  No themes matching '{filter_query}'. Type [c]lear to reset filter.")
            print()
        else:
            start = page * per_page
            end = min(start + per_page, total)
            cards = []
            for orig_idx, t in filtered_items[start:end]:
                cards.append(build_card_lines(t, orig_idx, total_all, current_name, sep=SEPARATOR))
            print_side_by_side(cards, num_cols, col_width)

        if status_msg:
            print(f"  {status_msg}")
            print()
            status_msg = ""

        # Navigation bar
        nav = []
        if filter_query:
            nav.append("[c]lear")
        if page > 0:
            nav.append("[p]rev")
        if (page + 1) < total_pages:
            nav.append("[n]ext")
        nav.append("[1-60|name] apply")
        nav.append("[t]separator")
        nav.append("[/]search")
        nav.append("[r]andom")
        nav.append("[q]uit")

        page_info = f"  Page {page + 1}/{total_pages}" if total_pages > 1 else " "
        try:
            choice = input(f"{page_info}  {' | '.join(nav)}: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n  Cancelled.")
            return

        cmd = choice.lower()
        if not cmd:
            continue

        if cmd in ("q", "quit", "exit"):
            print("  Bye.")
            return
        elif cmd in ("n", "next"):
            if (page + 1) < total_pages:
                page += 1
            else:
                status_msg = "\033[33mAlready at last page.\033[0m"
        elif cmd in ("p", "prev", "b", "back"):
            if page > 0:
                page -= 1
            else:
                status_msg = "\033[33mAlready at first page.\033[0m"
        elif cmd.startswith("g ") or cmd.startswith("page ") or (cmd.startswith("p") and cmd[1:].isdigit()):
            part = cmd.split()[-1].lstrip("p")
            if part.isdigit():
                target_page = int(part) - 1
                if 0 <= target_page < total_pages:
                    page = target_page
                else:
                    status_msg = f"\033[31mPage must be between 1 and {total_pages}.\033[0m"
        elif cmd in ("c", "clear", "all", "/clear"):
            filter_query = ""
            page = 0
        elif cmd.startswith("/") or cmd.startswith("s ") or cmd.startswith("f ") or cmd == "search":
            if cmd == "/" or cmd == "search":
                try:
                    term = input("  Search query: ").strip()
                except (EOFError, KeyboardInterrupt):
                    continue
            elif cmd.startswith("/"):
                term = choice[1:].strip()
            else:
                term = choice.split(None, 1)[1].strip()
            if term:
                filter_query = term
                page = 0
            else:
                filter_query = ""
                page = 0
        elif cmd in ("t", "sep", "separator") or cmd.startswith("t ") or cmd.startswith("sep "):
            parts = choice.split(None, 1)
            if len(parts) > 1:
                target_sep = find_separator(parts[1])
                if target_sep:
                    k, g, c, d = target_sep
                    apply_separator(k, g, c)
                    status_msg = f"\033[32mSeparator set to '{k}' ({g}) — {d}\033[0m"
                else:
                    status_msg = f"\033[31mUnknown separator: '{parts[1]}'. Type [t] to view list.\033[0m"
            else:
                chosen = interactive_separator_menu(themes)
                if chosen:
                    k, g, c, d = chosen
                    apply_separator(k, g, c)
                    status_msg = f"\033[32mSeparator set to '{k}' ({g}) — {d}\033[0m"
        elif cmd in ("r", "random"):
            pick_t = random.choice(themes)
            orig_idx = themes.index(pick_t) + 1
            apply_and_report(pick_t, orig_idx)
            return
        elif cmd in ("w", "web"):
            if HTML_PATH.exists():
                print(f"  Opening {HTML_PATH.name} in browser...")
                webbrowser.open(HTML_PATH.as_uri())
            else:
                status_msg = "\033[31msynth-shell-color-preview.html not found.\033[0m"
        elif cmd in ("?", "help"):
            status_msg = f"{BOLD}Commands:{RESET} [n]ext, [p]rev, [g 3] page, [t]separator, [/term] search, [c]lear, [r]andom, [w]eb, [1-60] apply, [q]uit"
        else:
            # Check if matching theme by number or name
            target_theme, orig_idx = find_theme(choice, themes)
            if target_theme:
                apply_and_report(target_theme, orig_idx)
                return
            else:
                status_msg = f"\033[31mTheme not found: '{choice}'. Type a number (1-{total_all}), name, or /search.\033[0m"


def main():
    parser = argparse.ArgumentParser(
        description="Interactive synth-shell theme picker with live terminal preview."
    )
    parser.add_argument("-l", "--list", action="store_true", help="List all themes with color swatches and exit")
    parser.add_argument("-c", "--current", action="store_true", help="Print currently active theme and exit")
    parser.add_argument("-a", "--apply", metavar="THEME", help="Apply theme by number (1-60) or name/slug and exit")
    parser.add_argument("-S", "--separators", action="store_true", help="Showcase all 10 Powerline separator styles and exit")
    parser.add_argument("-t", "--separator", metavar="STYLE", help="Set Powerline separator style (arrow, round, slant, flame, pixel, wave, hex, ice, slash, chevron) and exit")
    parser.add_argument("-r", "--random", action="store_true", help="Apply a random theme and exit")
    parser.add_argument("-s", "--search", metavar="TERM", help="Search themes by name or slug and exit")
    parser.add_argument("-w", "--web", action="store_true", help="Open synth-shell-color-preview.html in web browser")
    parser.add_argument("--no-clear", action="store_true", help="Do not clear terminal screen between pages")

    args = parser.parse_args()
    themes = load_themes()
    current_name = detect_current_theme(themes)

    if args.current:
        if current_name:
            idx = next((i for i, t in enumerate(themes, 1) if t.get("_name") == current_name), None)
            idx_str = f" (#{idx})" if idx else ""
            print(f"Current theme: {BOLD}{current_name}{RESET}{idx_str}")
        else:
            print("Current theme: none detected")
        return

    if args.separators:
        print_separator_list(themes, detect_current_separator())
        return

    if args.separator:
        sep = find_separator(args.separator)
        if not sep:
            print(f"Error: Unknown separator style '{args.separator}'.")
            print("Available styles: " + ", ".join(SEPARATOR_STYLES.keys()))
            sys.exit(1)
        key, glyph, code, desc = sep
        apply_separator(key, glyph, code)
        print()
        print(f"  {BOLD}Separator applied successfully!{RESET}")
        print(f"  Style:     {BOLD}{key}{RESET} ({glyph}) — {desc}")
        print(f"  Code:      {code}")
        print(f"  Config:    {CONFIG_PATH}")
        print()
        print(f"  To reload prompt in your current terminal session:")
        print(f"    {BOLD}source ~/.bashrc{RESET}")
        print()
        return

    if args.list:
        print_theme_list(themes, current_name)
        return

    if args.web:
        if HTML_PATH.exists():
            print(f"Opening {HTML_PATH.name} in browser...")
            webbrowser.open(HTML_PATH.as_uri())
        else:
            print(f"Error: {HTML_PATH} not found.")
            sys.exit(1)
        return

    if args.random:
        pick_t = random.choice(themes)
        orig_idx = themes.index(pick_t) + 1
        apply_and_report(pick_t, orig_idx)
        return

    if args.apply:
        theme, idx = find_theme(args.apply, themes)
        if not theme:
            print(f"Error: Theme '{args.apply}' not found. Run with --list to view all available themes.")
            sys.exit(1)
        apply_and_report(theme, idx)
        return

    if args.search:
        matches = filter_themes(args.search, themes)
        if not matches:
            print(f"No themes matching '{args.search}'.")
            return
        print()
        print(f"{BOLD}  Themes matching '{args.search}' ({len(matches)} matches):{RESET}")
        print()
        col_width = 72
        cards = [build_card_lines(t, orig_idx, len(themes), current_name) for orig_idx, t in matches]
        print_side_by_side(cards, 1, col_width)
        return

    # Default: interactive picker
    interactive_picker(themes, clear_screen_enabled=not args.no_clear)


if __name__ == "__main__":
    main()
