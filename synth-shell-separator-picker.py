#!/usr/bin/env python3
"""Interactive synth-shell Powerline separator editor and selector."""

import argparse
import random
import re
import shutil
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

THEMES_DIR = Path(__file__).parent / "lib" / "synth-shell-themes"
CONFIG_PATH = Path.home() / ".config" / "synth-shell" / "synth-shell-prompt.config"
PROMPT_SCRIPT_PATH = Path.home() / ".config" / "synth-shell" / "synth-shell-prompt.sh"
BACKUP_DIR = Path.home() / ".config" / "synth-shell" / "backups"

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"

# --- 31 Curated Separator Presets across 5 Categories ---

CATEGORIES: dict[str, list[tuple[str, str, str, str]]] = {
    "Powerline Solid (Hard Dividers)": [
        ("arrow", "\ue0b0", "\\uE0B0", "Classic Triangle Arrow (Powerline iconic)"),
        ("round", "\ue0b4", "\\uE0B4", "Rounded Bubble / Capsule (Modern macOS/iOS)"),
        ("slant", "\ue0bc", "\\uE0BC", "Angled Slant Lower (Cyberpunk racing cut)"),
        ("slant-up", "\ue0be", "\\uE0BE", "Angled Slant Upper (Reverse diagonal cut)"),
        ("flame", "\ue0c0", "\\uE0C0", "Flame / Fire Spikes (Aggressive energetic)"),
        ("pixel", "\ue0c4", "\\uE0C4", "8-Bit Stepped Pixel / Lego (Retro arcade)"),
        ("wave", "\ue0ca", "\\uE0CA", "Sine Wave / S-Curve (Fluid organic flow)"),
        ("hex", "\ue0cc", "\\uE0CC", "Hexagon / Honeycomb (Sci-fi cyber HUD)"),
        ("ice", "\ue0c8", "\\uE0C8", "Ice / Trapezoid Notch (Crystalline diamond cut)"),
        ("sharp-slant", "\ue0d4", "\\uE0D4", "Sharp Slant Right (Crisp angular blade)"),
        ("trapezoid", "\ue0d2", "\\uE0D2", "Big Trapezoid Right (Bold wedge cut)"),
    ],
    "Powerline Thin (Soft Dividers)": [
        ("thin-arrow", "\ue0b1", "\\uE0B1", "Thin Outline Triangle (Minimalist soft divider)"),
        ("thin-round", "\ue0b5", "\\uE0B5", "Thin Outline Bubble (Subtle rounded pill)"),
        ("thin-flame", "\ue0c1", "\\uE0C1", "Thin Outline Flame (Delicate spike wireframe)"),
        ("thin-hex", "\ue0cd", "\\uE0CD", "Thin Outline Hexagon (Wireframe cyber mesh)"),
    ],
    "Geometric & Minimalist": [
        ("slash", "\u2571", "\\u2571", "Diagonal Line Slash (Architectural clean cut)"),
        ("backslash", "\u2572", "\\u2572", "Backslash Line Slash (Reverse angle cut)"),
        ("bar", "\u2502", "\\u2502", "Light Vertical Bar / Pipe (Nordic subtle separator)"),
        ("heavy-bar", "\u2503", "\\u2503", "Heavy Vertical Bar (Bold column divider)"),
        ("half-block", "\u258c", "\\u258C", "Left Half Solid Block (Staccato block divider)"),
        ("diamond", "\u25c6", "\\u25C6", "Solid Diamond (Precious geometric accent)"),
        ("bullet", "\u25cf", "\\u25CF", "Solid Bullet Circle (Centered dot spacer)"),
    ],
    "Chevrons & Terminal Arrows": [
        ("chevron", "\u00bb", "\\u00BB", "Double Angle Chevron (Fast-forward prompt)"),
        ("single-chevron", "\u203a", "\\u203A", "Single Angle Chevron (Compact breadcrumb)"),
        ("arrow-right", "\u2192", "\\u2192", "Clean Thin Right Arrow (Modern minimal pointer)"),
        ("heavy-arrow", "\u27a4", "\\u27A4", "Black Rightwards Arrowhead (Bold navigation dart)"),
        ("octicon-chevron", "\uf460", "\\uF460", "Octicon Chevron Right (GitHub Octicon glyph)"),
        ("fa-angle", "\uf105", "\\uF105", "FontAwesome Angle Right (UI breadcrumb angle)"),
    ],
    "Nerd Font Glyphs & Emblems": [
        ("star", "\u2605", "\\u2605", "Solid Star (Clean celestial emblem)"),
        ("rocket", "\uf135", "\\uF135", "FontAwesome Rocket (Fast launch speed)"),
        ("lock", "\uf023", "\\uF023", "FontAwesome Lock (Security / safe environment)"),
        ("git", "\ue725", "\\uE725", "Git Branch Icon"),
        ("terminal", "\ue271", "\\uE271", "Terminal Command Icon"),
    ],
    "Electricity, Sparks & High Voltage": [
        ("zap", "⚡", "\\u26A1", "Classic Zap Bolt (High voltage electric energy)"),
        ("lightning", "\uf0e7", "\\uF0E7", "FontAwesome Solid Lightning Bolt"),
        ("thunder", "\u21af", "\\u21AF", "Zigzag Downward Thunder Discharge"),
        ("flash", "\U000f140b", "\\U000F140B", "Material Modern Sharp Lightning"),
        ("flash-wire", "\U000f140c", "\\U000F140C", "Material Wireframe Lightning"),
        ("sparkle", "\u2726", "\\u2726", "Four-Point Diamond Energy Sparkle"),
        ("starburst", "\u2727", "\\u2727", "Four-Point Hollow Starburst Flare"),
        ("burst", "\u2739", "\\u2739", "Twelve-Point Starburst Plasma Flare"),
        ("flare", "\u2738", "\\u2738", "Eight-Point Flare Explosion"),
        ("sparkles", "\u2728", "\\u2728", "Magic Twinkling Energy Sparks"),
        ("octo-flame", "\uf490", "\\uF490", "GitHub Octicon Energetic Fire Flame"),
        ("plasma-fire", "\U000f0238", "\\U000F0238", "Curved Hot Plasma Flame"),
        ("overdrive", "\U000f04c5", "\\U000F04C5", "Tachometer Needle in Red / Overdrive"),
        ("wave-pulse", "\u219d", "\\u219D", "Waveform Oscillator Energy Arrow"),
        ("squiggle", "\u21dd", "\\u21DD", "Pulse Wave Kinetic Squiggle Arrow"),
    ],
}

ALL_PRESETS: list[tuple[str, str, str, str]] = [item for items in CATEGORIES.values() for item in items]

# --- 60+ Visual Character Palette Matrix for Custom Mode ---

CHARACTER_PALETTE: dict[str, list[tuple[str, str, str]]] = {
    "Powerline & Dividers": [
        ("\ue0b0", "E0B0", "Triangle"),   ("\ue0b1", "E0B1", "Thin Tri"),
        ("\ue0b4", "E0B4", "Bubble"),     ("\ue0b5", "E0B5", "Thin Bub"),
        ("\ue0bc", "E0BC", "Slant Lo"),   ("\ue0be", "E0BE", "Slant Up"),
        ("\ue0c0", "E0C0", "Flame"),      ("\ue0c1", "E0C1", "Thin Flam"),
        ("\ue0c4", "E0C4", "Pixel"),      ("\ue0c6", "E0C6", "Sm Pixel"),
        ("\ue0ca", "E0CA", "Wave"),       ("\ue0cc", "E0CC", "Hexagon"),
        ("\ue0c8", "E0C8", "Ice Notch"),  ("\ue0cd", "E0CD", "Thin Hex"),
        ("\ue0d4", "E0D4", "Sharp Slnt"), ("\ue0d2", "E0D2", "Trapezoid"),
    ],
    "Chevrons, Pointers & Arrows": [
        ("»", "00BB", "Dbl Chevr"), ("›", "203A", "Sgl Chevr"),
        ("→", "2192", "Thin Arrow"),("➜", "279C", "Hvy Arrow"),
        ("➤", "27A4", "Arrowhead"), ("▶", "25B6", "Play Tri"),
        ("▸", "25B8", "Sm Tri"),    ("►", "25BA", "Point Tri"),
        ("", "F105", "FA Angle"),  ("", "F054", "FA Chevr"),
        ("", "F061", "FA Arrow"),  ("", "F0DA", "FA Caret"),
        ("", "F460", "Oct Chevr"), ("", "F432", "Oct Tri"),
        ("«", "00AB", "Left Chevr"),("◀", "25C0", "Left Tri"),
    ],
    "Geometric & Block Dividers": [
        ("╱", "2571", "Diag Slash"),("╲", "2572", "Backslash"),
        ("│", "2502", "Vert Bar"),  ("┃", "2503", "Heavy Bar"),
        ("▌", "258C", "Half Block"),("▐", "2590", "R HalfBlk"),
        ("█", "2588", "Full Block"),("░", "2591", "Light Shade"),
        ("◆", "25C6", "Diamond"),   ("◇", "25C7", "White Diam"),
        ("●", "25CF", "Circle"),    ("○", "25CB", "White Circ"),
    ],
    "⚡ Electricity, Sparks & Kinetic Energy": [
        ("⚡", "26A1", "Zap Bolt"),      ("", "F0E7", "FA Bolt"),
        ("↯", "21AF", "Thunder"),       ("󱐋", "F140B", "MDI Flash"),
        ("󱐌", "F140C", "Wire Flash"),   ("✦", "2726", "Sparkle"),
        ("✧", "2727", "Hollow Spark"),  ("✨", "2728", "Sparkles"),
        ("✹", "2739", "12-Pt Burst"),   ("✸", "2738", "8-Pt Flare"),
        ("✵", "2735", "Pinwheel"),      ("", "F490", "Octo Flame"),
        ("󰈸", "F0238", "Plasma Fire"),  ("󰓅", "F04C5", "Overdrive"),
        ("↝", "219D", "Wave Zap"),      ("⇝", "21DD", "Squiggle"),
    ],
    "Nerd Font Emblems & Icons": [
        ("★", "2605", "Star"),          ("", "F135", "Rocket"),
        ("", "F023", "Lock"),          ("", "E725", "Git Branch"),
        ("", "F418", "Oct Branch"),     ("", "F308", "Docker"),
        ("󱃾", "F00FE", "Kubernetes"),   ("󱁢", "F0062", "Terraform"),
        ("", "E271", "Terminal"),      ("󰓅", "F04C5", "Speed"),
        ("♥", "2665", "Heart"),         ("✔", "2714", "Checkmark"),
    ],
}


def find_palette_char(query: str) -> tuple[str, str, str] | None:
    """Find character in visual palette by hex code, name, or literal glyph."""
    q = query.strip().lower()
    for group, items in CHARACTER_PALETTE.items():
        for glyph, hex_code, desc in items:
            if q in (glyph, hex_code.lower(), desc.lower(), desc.lower().replace(" ", "")):
                return glyph, f"\\u{hex_code}", desc
            if q in (f"\\u{hex_code.lower()}", f"u+{hex_code.lower()}", f"0x{hex_code.lower()}", hex_code.lower()):
                return glyph, f"\\u{hex_code}", desc
    return None

NAMED_COLORS = {
    "black": 0, "red": 1, "green": 2, "yellow": 3,
    "blue": 4, "purple": 5, "cyan": 6, "light-gray": 7,
    "dark-gray": 8, "light-red": 9, "light-green": 10, "light-yellow": 11,
    "light-blue": 12, "light-purple": 13, "light-cyan": 14, "white": 15,
}


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


_ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def visible_len(s: str) -> int:
    plain = _ANSI_RE.sub("", s)
    w = 0
    for ch in plain:
        cat = unicodedata.east_asian_width(ch)
        w += 2 if cat in ("W", "F") else 1
    return w


def pad_to(s: str, width: int) -> str:
    diff = width - visible_len(s)
    return s + " " * max(diff, 0)


# --- Theme & Prompt Rendering ---

def load_active_or_default_theme() -> dict:
    """Load active theme colors from CONFIG_PATH or default to Tokyo Night."""
    theme = {
        "_name": "Active Theme",
        "background_host": "60", "font_color_host": "white",
        "background_pwd": "153", "font_color_pwd": "black",
        "background_git": "114", "font_color_git": "black",
        "background_input": "none", "font_color_input": "111",
    }
    if CONFIG_PATH.exists():
        for line in CONFIG_PATH.read_text().splitlines():
            m = re.match(r'^(font_color_\w+|background_\w+)\s*=\s*["\']?([^"\']*)["\']?', line)
            if m:
                theme[m.group(1)] = m.group(2).strip()
    return theme


def render_separator(prev_bg: int | None, next_bg: int | None, sep: str) -> str:
    parts = []
    if prev_bg is not None:
        parts.append(ansi_fg(prev_bg))
    if next_bg is not None:
        parts.append(ansi_bg(next_bg))
    else:
        parts.append(RESET)
        if prev_bg is not None:
            parts.append(ansi_fg(prev_bg))
    parts.append(sep)
    return "".join(parts)


def render_prompt_sample(internal_sep: str, theme: dict, end_sep: str | None = None) -> str:
    """Render a sample 3-segment prompt using chosen internal and optional ending separator."""
    if end_sep is None:
        end_sep = internal_sep
    segments = [("host", "mvsoares"), ("pwd", "~/proj/setup"), ("git", "main")]
    command = "git status"
    out = []
    for i, (key, text) in enumerate(segments):
        fg = color_index(theme.get(f"font_color_{key}", "white"))
        bg = color_index(theme.get(f"background_{key}", "0"))
        parts = []
        if bg is not None:
            parts.append(ansi_bg(bg))
        if fg is not None:
            parts.append(ansi_fg(fg))
        parts.append(BOLD)
        parts.append(f" {text} ")
        out.append("".join(parts))
        next_bg = None
        if i + 1 < len(segments):
            next_key = segments[i + 1][0]
            next_bg = color_index(theme.get(f"background_{next_key}", "0"))
            sep_to_use = internal_sep
        else:
            sep_to_use = end_sep
        out.append(render_separator(bg, next_bg, sep_to_use))
    input_fg = color_index(theme.get("font_color_input", "white"))
    out.append(RESET)
    if input_fg is not None:
        out.append(ansi_fg(input_fg))
    out.append(BOLD)
    out.append(f" {command}")
    out.append(RESET)
    return "".join(out)


# --- Config & Detection Helpers ---

def detect_current_separators() -> tuple[tuple[str, str], tuple[str, str] | None]:
    """Return ((internal_glyph, internal_code), (end_glyph, end_code) | None) from CONFIG_PATH."""
    internal_res = ("\ue0b0", "\\uE0B0")
    end_res = None
    if not CONFIG_PATH.exists():
        return internal_res, end_res

    for line in CONFIG_PATH.read_text().splitlines():
        m_main = re.match(r"^separator_char\s*=\s*['\"]?(.*?)['\"]?\s*$", line)
        if m_main:
            val = m_main.group(1).strip()
            m_hex = re.match(r"^\\([uU])([0-9a-fA-F]{4,8})$", val)
            if m_hex:
                try:
                    internal_res = (chr(int(m_hex.group(2), 16)), val)
                except ValueError:
                    pass
            elif val:
                internal_res = (val, val)

        m_end = re.match(r"^separator_char_end\s*=\s*['\"]?(.*?)['\"]?\s*$", line)
        if m_end:
            val = m_end.group(1).strip()
            m_hex = re.match(r"^\\([uU])([0-9a-fA-F]{4,8})$", val)
            if m_hex:
                try:
                    end_res = (chr(int(m_hex.group(2), 16)), val)
                except ValueError:
                    pass
            elif val:
                end_res = (val, val)

    return internal_res, end_res


def detect_current_separator() -> tuple[str, str]:
    """Return (glyph, code_str) of the main/internal separator currently in CONFIG_PATH."""
    return detect_current_separators()[0]


def parse_custom_char(input_str: str) -> tuple[str, str]:
    """Parse user input into (literal_glyph, escaped_code_str)."""
    s = input_str.strip().strip('"').strip("'")
    hex_match = re.match(r"^(?:\\u|\\U|u\+|0x)?([0-9a-fA-F]{4,8})$", s, re.IGNORECASE)
    if hex_match:
        codepoint = int(hex_match.group(1), 16)
        glyph = chr(codepoint)
        code_str = f"\\U{codepoint:08X}" if codepoint > 0xFFFF else f"\\u{codepoint:04X}"
        return glyph, code_str
    if len(s) == 1:
        codepoint = ord(s)
        if codepoint > 0xFFFF:
            code_str = f"\\U{codepoint:08X}"
        elif codepoint > 127:
            code_str = f"\\u{codepoint:04X}"
        else:
            code_str = s
        return s, code_str
    return s, s


def find_preset(query: str | int) -> tuple[str, str, str, str] | None:
    """Find preset separator by 1-based index or key name."""
    q = str(query).strip().lower()
    if q.isdigit():
        idx = int(q)
        if 1 <= idx <= len(ALL_PRESETS):
            return ALL_PRESETS[idx - 1]
        return None
    for key, glyph, code, desc in ALL_PRESETS:
        if q in (key, key.replace("-", ""), glyph, desc.lower()):
            return key, glyph, code, desc
    for key, glyph, code, desc in ALL_PRESETS:
        if q in key or q in desc.lower():
            return key, glyph, code, desc
    return None


def resolve_separator_input(user_input: str) -> tuple[str, str, str]:
    """Resolve any input (preset name, index, hex code, or glyph) to (glyph, code_str, label)."""
    p = find_preset(user_input)
    if p:
        return p[1], p[2], f"{p[0]} ({p[3]})"
    pal = find_palette_char(user_input)
    if pal:
        return pal[0], pal[1], pal[2]
    glyph, code = parse_custom_char(user_input)
    return glyph, code, "Custom"


def backup_config() -> Path | None:
    if not CONFIG_PATH.exists():
        return None
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    dest = BACKUP_DIR / f"synth-shell-prompt.config.{stamp}.bak"
    shutil.copy2(CONFIG_PATH, dest)
    return dest


def ensure_dual_separator_support() -> bool:
    """Ensure synth-shell-prompt.sh supports separator_char_end for custom last character."""
    if not PROMPT_SCRIPT_PATH.exists():
        return False
    content = PROMPT_SCRIPT_PATH.read_text()
    if 'local sep_char="${6:-$separator_char}"' in content and 'separator_char_end' in content:
        return True

    modified = False

    # 1. Update printSegment to accept 6th arg ($sep_char)
    old_print_segment = (
        'printSegment()\n{\n\t## GET PARAMETERS\n\tlocal text=$1\n\tlocal font_color=$2\n'
        '\tlocal background_color=$3\n\tlocal next_background_color=$4 # needed for the separator, it participates in this and the next text segment\n'
        '\tlocal font_effect=$5'
    )
    new_print_segment = (
        'printSegment()\n{\n\t## GET PARAMETERS\n\tlocal text=$1\n\tlocal font_color=$2\n'
        '\tlocal background_color=$3\n\tlocal next_background_color=$4 # needed for the separator, it participates in this and the next text segment\n'
        '\tlocal font_effect=$5\n\tlocal sep_char="${6:-$separator_char}"'
    )
    if old_print_segment in content:
        content = content.replace(old_print_segment, new_print_segment)
        content = content.replace(
            '${separator_format}${separator_char}${separator_padding_right}',
            '${separator_format}${sep_char}${separator_padding_right}',
        )
        modified = True

    # 2. Update combine_elements to pass $separator_char_end when second == "INPUT"
    old_combine = (
        '\tlocal text_effect=${colors_first[2]}\n'
        '\tprintSegment "$text" "$text_color" "$bg_color" "$next_bg_color" "$text_effect"\n}'
    )
    new_combine = (
        '\tlocal text_effect=${colors_first[2]}\n'
        '\tlocal sep_char="$separator_char"\n'
        '\tif [ "$second" = "INPUT" ] && [ -n "${separator_char_end:-}" ]; then\n'
        '\t\tsep_char="$separator_char_end"\n'
        '\tfi\n'
        '\tprintSegment "$text" "$text_color" "$bg_color" "$next_bg_color" "$text_effect" "$sep_char"\n}'
    )
    if old_combine in content:
        content = content.replace(old_combine, new_combine)
        modified = True

    if modified:
        PROMPT_SCRIPT_PATH.write_text(content)
        return True
    return False


def apply_separators(
    internal: tuple[str, str] | None = None,
    end: tuple[str, str] | None = None,
    label: str = "",
) -> None:
    """Write internal and/or end separator to CONFIG_PATH safely."""
    ensure_dual_separator_support()
    if not CONFIG_PATH.exists():
        print(f"  Error: {CONFIG_PATH} not found.")
        return
    bak = backup_config()
    lines = CONFIG_PATH.read_text().splitlines()
    new_lines = []
    found_main = False
    found_end = False

    for line in lines:
        if re.match(r"^separator_char\s*=", line):
            if internal is not None:
                new_lines.append(f'separator_char="{internal[1]}"')
            else:
                new_lines.append(line)
            found_main = True
        elif re.match(r"^separator_char_end\s*=", line):
            if end is not None:
                new_lines.append(f'separator_char_end="{end[1]}"')
            else:
                new_lines.append(line)
            found_end = True
        else:
            new_lines.append(line)

    if not found_main and internal is not None:
        new_lines.append(f'separator_char="{internal[1]}"')
    if not found_end and end is not None:
        new_lines.append(f'separator_char_end="{end[1]}"')

    CONFIG_PATH.write_text("\n".join(new_lines) + "\n")
    print()
    print(f"  {BOLD}Separators applied successfully!{RESET}")
    if label:
        print(f"  Preset:    {BOLD}{label}{RESET}")
    if internal is not None:
        print(f"  Internal:  {BOLD}{internal[0]}{RESET}  ({internal[1]})")
    if end is not None:
        print(f"  Ending:    {BOLD}{end[0]}{RESET}  ({end[1]})")
    if bak:
        print(f"  Backup:    {bak}")
    print(f"  Config:    {CONFIG_PATH}")
    print()
    print(f"  To reload prompt in your current terminal session:")
    print(f"    {BOLD}source ~/.bashrc{RESET}")
    print()


def apply_separator(glyph: str, code_str: str, label: str = "") -> None:
    """Write selected separator for both internal and ending positions."""
    apply_separators(internal=(glyph, code_str), end=(glyph, code_str), label=label)


def print_character_palette_table() -> None:
    """Print multi-column visual cheat-sheet of 60+ popular Nerd Font & Unicode characters."""
    print()
    print(f"  {BOLD}╔═════════════════════════════════════════════════════════════════════════════════════════╗{RESET}")
    print(f"  {BOLD}║              Nerd Font & Unicode Character Palette (60+ Glyphs)                         ║{RESET}")
    print(f"  {BOLD}╚═════════════════════════════════════════════════════════════════════════════════════════╝{RESET}")
    print()

    for title, items in CHARACTER_PALETTE.items():
        bar = "─" * max(4, 75 - len(title))
        print(f"  {BOLD}\033[36m── {title} ({len(items)} glyphs) {bar}{RESET}")
        for i in range(0, len(items), 4):
            row = items[i : i + 4]
            cells = []
            for ch, hex_code, desc in row:
                cells.append(f" {BOLD}{ch}{RESET}  \033[33m\\u{hex_code:<5}\033[0m {DIM}{desc:<11}{RESET}")
            print("  " + "  ".join(cells))
        print()

    print(f"  {DIM}Pick any character by typing its {BOLD}Hex Code{RESET}{DIM} (e.g. E0B4, F0E7), its {BOLD}Name{RESET}{DIM} (e.g. bubble, lightning),{RESET}")
    print(f"  {DIM}or {BOLD}paste any custom symbol{RESET}{DIM} directly.{RESET}")
    print()


# --- Display & Showcase ---

def print_separator_showcase(theme: dict, current_glyph: str) -> None:
    """Print categorized showcase with live colored prompt previews."""
    print()
    print(f"{BOLD}  Synth-Shell Powerline Separator Gallery ({len(ALL_PRESETS)} presets){RESET}")
    print(f"  {DIM}Live sample previews rendered with your prompt colors:{RESET}")
    print()

    counter = 1
    for cat_name, items in CATEGORIES.items():
        print(f"  {BOLD}\033[36m── {cat_name} ──────────────────────────────────────{RESET}")
        print()
        for key, glyph, code, desc in items:
            active = f"  \033[33;1m← active{RESET}" if glyph == current_glyph else ""
            sample = render_prompt_sample(glyph, theme)
            print(f"    {BOLD}#{counter:02d}{RESET}  {glyph}  {BOLD}{key:<16}{RESET}  ({code})  {desc}{active}")
            print(f"         {sample}")
            print()
            counter += 1


# --- Interactive Editor ---

def interactive_menu(theme: dict, clear_screen: bool = True) -> None:
    status_msg = ""

    while True:
        (cur_int_glyph, cur_int_code), end_tuple = detect_current_separators()
        cur_end_glyph = end_tuple[0] if end_tuple else cur_int_glyph
        cur_end_code = end_tuple[1] if end_tuple else cur_int_code
        end_note = f" ({cur_end_code})" if end_tuple else " (same as internal)"

        if clear_screen and sys.stdout.isatty():
            sys.stdout.write("\033[H\033[2J")
            sys.stdout.flush()
        else:
            print()

        print(f"{BOLD}  Synth-Shell Powerline Separator Editor{RESET}  —  {len(ALL_PRESETS)} presets + dual separators")
        print(f"  Internal separator: \033[36;1m{cur_int_glyph}\033[0m ({cur_int_code})  [first & middle segments]")
        print(f"  Ending separator:   \033[33;1m{cur_end_glyph}\033[0m{end_note}  [last segment before command]")
        print(f"  Live prompt:        {render_prompt_sample(cur_int_glyph, theme, cur_end_glyph)}")
        print(f"  Config:             {CONFIG_PATH}")
        print()

        # Print categorized items
        counter = 1
        for cat_name, items in CATEGORIES.items():
            print(f"  \033[36m── {cat_name} ──{RESET}")
            for key, glyph, code, desc in items:
                active = f"  \033[33;1m← active{RESET}" if glyph == cur_int_glyph else ""
                sample = render_prompt_sample(glyph, theme)
                print(f"  {BOLD}#{counter:02d}{RESET}  {glyph}  {BOLD}{key:<16}{RESET}  {desc}{active}")
                print(f"       {sample}")
                counter += 1
            print()

        if status_msg:
            print(f"  {status_msg}")
            print()
            status_msg = ""

        # Navigation
        nav = [
            f"[1-{len(ALL_PRESETS)}|name] apply both",
            "[m]ix dual (first & last)",
            "[i]nternal sep",
            "[e]nding sep",
            "[c]ustom palette",
            "[p]review <char>",
            "[r]andom",
            "[q]uit",
        ]
        try:
            choice = input(f"  {' | '.join(nav)}: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n  Cancelled.")
            return

        if not choice:
            continue

        cmd = choice.lower()
        if cmd in ("q", "quit", "exit"):
            print("  Bye.")
            return
        elif cmd in ("r", "random"):
            pick = random.choice(ALL_PRESETS)
            key, glyph, code, desc = pick
            apply_separator(glyph, code, label=f"{key} ({desc})")
            return
        elif cmd in ("m", "mix", "dual"):
            print()
            print(f"  {BOLD}Step 1: First / Internal Separator{RESET} (used between Host, PWD, Git segments)")
            try:
                raw_int = input(f"  Pick FIRST/INTERNAL [name, hex, glyph] (Enter for current '{cur_int_glyph}'): ").strip()
            except (EOFError, KeyboardInterrupt):
                continue
            if not raw_int:
                int_glyph, int_code, int_label = cur_int_glyph, cur_int_code, "Current"
            else:
                int_glyph, int_code, int_label = resolve_separator_input(raw_int)

            print()
            print(f"  {BOLD}Step 2: Last / Ending Separator{RESET} (used at the end of the prompt before your command)")
            try:
                raw_end = input("  Pick LAST/ENDING [e.g. zap, lightning, bolt, rocket, chevron]: ").strip()
            except (EOFError, KeyboardInterrupt):
                continue
            if not raw_end:
                end_glyph, end_code, end_label = cur_end_glyph, cur_end_code, "Current"
            else:
                end_glyph, end_code, end_label = resolve_separator_input(raw_end)

            sample = render_prompt_sample(int_glyph, theme, end_glyph)
            print()
            print(f"  Selected Dual Combination:")
            print(f"    First / Internal: {BOLD}{int_glyph}{RESET} ({int_code}) — {int_label}")
            print(f"    Last / Ending:    {BOLD}{end_glyph}{RESET} ({end_code}) — {end_label}")
            print(f"  Live Prompt:        {sample}")
            print()
            try:
                confirm = input("  Apply this dual separator combination? [Y/n]: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                continue
            if confirm in ("", "y", "yes"):
                apply_separators(internal=(int_glyph, int_code), end=(end_glyph, end_code), label=f"{int_label} + {end_label}")
                return
            else:
                status_msg = "\033[33mDual separator combination cancelled.\033[0m"

        elif cmd in ("i", "internal") or cmd.startswith("i ") or cmd.startswith("internal "):
            parts = choice.split(None, 1)
            raw = parts[1].strip() if len(parts) > 1 else ""
            if not raw:
                try:
                    raw = input("  Pick FIRST/INTERNAL separator [name, hex, glyph]: ").strip()
                except (EOFError, KeyboardInterrupt):
                    continue
            if raw:
                g, c, l = resolve_separator_input(raw)
                apply_separators(internal=(g, c), label=f"Internal: {l}")
                return

        elif cmd in ("e", "end", "last") or cmd.startswith("e ") or cmd.startswith("end ") or cmd.startswith("last "):
            parts = choice.split(None, 1)
            raw = parts[1].strip() if len(parts) > 1 else ""
            if not raw:
                try:
                    raw = input("  Pick LAST/ENDING separator [e.g. zap, lightning, bolt, rocket]: ").strip()
                except (EOFError, KeyboardInterrupt):
                    continue
            if raw:
                g, c, l = resolve_separator_input(raw)
                apply_separators(end=(g, c), label=f"Ending: {l}")
                return

        elif cmd in ("c", "custom", "table", "palette"):
            if clear_screen and sys.stdout.isatty():
                sys.stdout.write("\033[H\033[2J")
                sys.stdout.flush()
            print_character_palette_table()
            try:
                raw_char = input("  Pick character [name, hex, or glyph] (Enter to cancel): ").strip()
            except (EOFError, KeyboardInterrupt):
                continue
            if not raw_char:
                continue

            glyph, code, label = resolve_separator_input(raw_char)
            sample = render_prompt_sample(glyph, theme)
            print()
            print(f"  Selected Character: {BOLD}{glyph}{RESET}  (Code: {code}, Label: {label})")
            print(f"  Live Prompt Preview: {sample}")
            print()
            try:
                confirm = input("  Apply this separator? [Y/n]: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                continue
            if confirm in ("", "y", "yes"):
                apply_separator(glyph, code, label=label)
                return
            else:
                status_msg = "\033[33mCustom separator cancelled.\033[0m"

        elif cmd.startswith("p ") or cmd.startswith("preview "):
            raw_parts = choice.split()[1:]
            if len(raw_parts) >= 2:
                g1, c1, _ = resolve_separator_input(raw_parts[0])
                g2, c2, _ = resolve_separator_input(raw_parts[1])
                sample = render_prompt_sample(g1, theme, g2)
                status_msg = f"Dual Preview ({g1} + {g2}): {sample}"
            elif raw_parts:
                g, c, _ = resolve_separator_input(raw_parts[0])
                sample = render_prompt_sample(g, theme)
                status_msg = f"Preview for \033[1m{g}\033[0m ({c}): {sample}"

        else:
            g, c, l = resolve_separator_input(choice)
            if g and g != choice:
                apply_separator(g, c, label=l)
                return
            preset = find_preset(choice)
            if preset:
                key, glyph, code, desc = preset
                apply_separator(glyph, code, label=f"{key} ({desc})")
                return
            status_msg = f"\033[31mUnknown choice: '{choice}'. Type 1-{len(ALL_PRESETS)}, preset name, [m]ix dual, [c]ustom, or [q]uit.\033[0m"


def main():
    parser = argparse.ArgumentParser(
        description="Interactive synth-shell Powerline separator editor and selector."
    )
    parser.add_argument("-l", "--list", action="store_true", help="List all preset separators with prompt previews and exit")
    parser.add_argument("-c", "--current", action="store_true", help="Print currently active separators and exit")
    parser.add_argument("-T", "--palette", action="store_true", help="Display visual cheat-sheet table of 60+ Nerd Font characters and exit")
    parser.add_argument("-a", "--apply", metavar="SEPARATOR", help=f"Apply separator everywhere (1-{len(ALL_PRESETS)} or name) and exit")
    parser.add_argument("-d", "--dual", nargs=2, metavar=("FIRST", "LAST"), help="Set dual separators: FIRST for internal segments, LAST for ending (e.g. --dual arrow zap)")
    parser.add_argument("-i", "--internal", metavar="SEPARATOR", help="Set first/internal separator character only")
    parser.add_argument("-e", "--end", metavar="SEPARATOR", help="Set last/ending separator character only")
    parser.add_argument("-u", "--custom", metavar="CHAR_OR_HEX", help="Apply custom character or Unicode hex (e.g. \\uE0B4, U+E0B4, or glyph) and exit")
    parser.add_argument("-p", "--preview", metavar="CHAR_OR_HEX", help="Preview prompt with given separator and exit")
    parser.add_argument("--preview-dual", nargs=2, metavar=("FIRST", "LAST"), help="Preview prompt with dual separators and exit")
    parser.add_argument("-r", "--random", action="store_true", help="Apply a random preset separator and exit")
    parser.add_argument("--no-clear", action="store_true", help="Do not clear screen in interactive mode")

    args = parser.parse_args()
    theme = load_active_or_default_theme()
    (cur_int_glyph, cur_int_code), end_tuple = detect_current_separators()
    cur_end_glyph = end_tuple[0] if end_tuple else cur_int_glyph
    cur_end_code = end_tuple[1] if end_tuple else cur_int_code

    if args.current:
        end_desc = f" ({cur_end_code})" if end_tuple else " (same as internal)"
        print(f"Internal separator: {BOLD}{cur_int_glyph}{RESET} ({cur_int_code})")
        print(f"Ending separator:   {BOLD}{cur_end_glyph}{RESET}{end_desc}")
        print(f"Sample: {render_prompt_sample(cur_int_glyph, theme, cur_end_glyph)}")
        return

    if args.palette:
        print_character_palette_table()
        return

    if args.list:
        print_separator_showcase(theme, cur_int_glyph)
        return

    if args.preview_dual:
        g1, c1, l1 = resolve_separator_input(args.preview_dual[0])
        g2, c2, l2 = resolve_separator_input(args.preview_dual[1])
        sample = render_prompt_sample(g1, theme, g2)
        print()
        print(f"  Dual Preview:")
        print(f"    First / Internal: {BOLD}{g1}{RESET} ({c1}) — {l1}")
        print(f"    Last / Ending:    {BOLD}{g2}{RESET} ({c2}) — {l2}")
        print(f"  Prompt:             {sample}")
        print()
        return

    if args.preview:
        g, c, l = resolve_separator_input(args.preview)
        sample = render_prompt_sample(g, theme)
        print()
        print(f"  Preview for: {BOLD}{g}{RESET}  (Code: {c}, Label: {l})")
        print(f"  Prompt:      {sample}")
        print()
        return

    if args.dual:
        g1, c1, l1 = resolve_separator_input(args.dual[0])
        g2, c2, l2 = resolve_separator_input(args.dual[1])
        apply_separators(internal=(g1, c1), end=(g2, c2), label=f"{l1} + {l2}")
        return

    if args.internal:
        g, c, l = resolve_separator_input(args.internal)
        apply_separators(internal=(g, c), label=f"Internal: {l}")
        return

    if args.end:
        g, c, l = resolve_separator_input(args.end)
        apply_separators(end=(g, c), label=f"Ending: {l}")
        return

    if args.random:
        pick = random.choice(ALL_PRESETS)
        key, glyph, code, desc = pick
        apply_separator(glyph, code, label=f"{key} ({desc})")
        return

    if args.custom:
        g, c, l = resolve_separator_input(args.custom)
        apply_separator(g, c, label=l)
        return

    if args.apply:
        g, c, l = resolve_separator_input(args.apply)
        apply_separator(g, c, label=l)
        return

    # Default: interactive editor
    interactive_menu(theme, clear_screen=not args.no_clear)


if __name__ == "__main__":
    main()

