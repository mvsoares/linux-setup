#!/usr/bin/env python3
"""
Font Picker — serves the preview page and applies fonts/sizes to WezTerm config.
Lists all installed monospace fonts (Fontconfig) plus any Nerd Font families that
might not be tagged as mono. Usage: python3 font-picker.py — then open http://localhost:7777
"""
import http.server
import json
import re
import socketserver
import subprocess
import tempfile
import urllib.parse
from pathlib import Path

PORT = 7777
WEZTERM_CFG = Path.home() / ".config/wezterm/wezterm.lua"
HTML_FILE   = Path(__file__).parent / "nerd-fonts-preview.html"

# Known Nerd Font metadata: family → (short author tag, preview description)
# Keys match the actual fc-list family names (which differ from install slugs).
_FONT_META = {
    "0xProto Nerd Font":          ("0xType",            "Designed specifically for terminals and code. Every character optimised for distinction. Strong x-height, zero ambiguity guaranteed."),
    "BlexMono Nerd Font":         ("IBM",               "Engineered precision from IBM Design (IBM Plex Mono). Humanist mono with strong technical character. Excellent for code and docs."),
    "CaskaydiaCove Nerd Font":    ("Microsoft",         "Microsoft's modern mono (Cascadia Code) built for Windows Terminal. Cursive italic variant. Crisp at small sizes, rich ligature set."),
    "CommitMono Nerd Font":       ("Eigil Nikolajsen",  "Modern neutral coding font built for focus. Smart spacing, optical adjustments, no distracting personality. Pure utility."),
    "FiraCode Nerd Font":         ("Mozilla",           "Pioneered programming ligatures. Transforms != -> => into elegant symbols. Clean strokes, wide adoption across editors worldwide."),
    "GeistMono Nerd Font":        ("Vercel",            "Vercel's sleek mono companion to Geist. Minimal and modern, designed for developer interfaces. Clean zero, clear punctuation."),
    "Hack Nerd Font":             ("Source Forge",      "Workhorse coding font with no frills. Optimised for source code at 8–14px. High contrast, open apertures, zero confusion."),
    "Inconsolata Nerd Font":      ("Raph Levien",       "Humanist mono inspired by Consolas. Elegant curves, tight spacing. One of the most readable fonts at small point sizes."),
    "Iosevka Nerd Font":          ("Belleve Invis",     "Ultra-condensed, infinitely customisable. Fits more code on screen than almost any alternative. Minimal and precise."),
    "IosevkaTerm Nerd Font":      ("Belleve Invis",     "Terminal-optimised variant of Iosevka. Fixed cell widths for perfect glyph alignment. Compact and extremely fast to scan."),
    "JetBrainsMono Nerd Font":    ("JetBrains",         "Sharp, geometric mono by JetBrains. Excellent readability, 139 ligatures, zero-ambiguity glyphs. Perfect for long coding sessions."),
    "JetBrainsMonoNL Nerd Font":  ("JetBrains",         "JetBrains Mono without ligatures. Same exceptional clarity and spacing, with every operator rendered as distinct characters."),
    "MesloLGS Nerd Font":         ("André Berg",        "Small Meslo — tighter line-height for dense terminal layouts. The go-to for Powerlevel10k setups."),
    "MesloLGM Nerd Font":         ("André Berg",        "Medium Meslo — customised Apple Monaco derivative. Generous line height, clear punctuation, iconic for terminals."),
    "MesloLGL Nerd Font":         ("André Berg",        "Large Meslo — extra-generous line-height. Great readability on high-DPI displays."),
    "MesloLGSDZ Nerd Font":       ("André Berg",        "Meslo Small with dotted zero variant. Clearer zero/O distinction for security-conscious developers."),
    "MesloLGMDZ Nerd Font":       ("André Berg",        "Meslo Medium with dotted zero variant. Combines generous spacing with unambiguous zero glyph."),
    "MesloLGLDZ Nerd Font":       ("André Berg",        "Meslo Large with dotted zero variant. Maximum line-height with the clearest zero glyph."),
    "MonaspiceNe Nerd Font":      ("GitHub",            "Monaspace Neon: the flagship neo-grotesque variant. Texture healing keeps columns aligned regardless of glyph width."),
    "MonaspiceAr Nerd Font":      ("GitHub",            "Monaspace Argon: humanist fixed-width variant. Warmer personality while retaining precise code alignment."),
    "MonaspiceKr Nerd Font":      ("GitHub",            "Monaspace Krypton: mechanical slab-serif flavour. Distinctive serifs add personality without hurting readability."),
    "MonaspiceRn Nerd Font":      ("GitHub",            "Monaspace Radon: handwriting-influenced cursive variant. Beautiful italics that make keyword highlighting expressive."),
    "MonaspiceXe Nerd Font":      ("GitHub",            "Monaspace Xenon: transitional serif style. Bridges the gap between classic editorial type and modern coding fonts."),
    "RecMonoCasual Nerd Font":    ("Arrow Type",        "Recursive Casual — variable font leaning into a handwritten feel. Expressive italics and a relaxed baseline rhythm."),
    "RecMonoLinear Nerd Font":    ("Arrow Type",        "Recursive Linear — the neutral, no-personality variant. All axes zeroed for pure readability without distraction."),
    "RecMonoDuotone Nerd Font":   ("Arrow Type",        "Recursive Duotone — optimised for syntax themes that separate keywords visually. Contrast-first design."),
    "RecMonoSmCasual Nerd Font":  ("Arrow Type",        "Recursive Semi-Casual — midpoint between Linear and Casual. Subtle personality with professional restraint."),
    "RobotoMono Nerd Font":       ("Google",            "Google's geometric mono, sibling to Roboto. Mechanical feel with friendly curves. Consistent rendering across all platforms."),
    "SauceCodePro Nerd Font":     ("Adobe",             "Adobe Source Code Pro. Neutral, professional and exceptionally legible at all sizes. Part of the open-source Source family."),
    "SpaceMono Nerd Font":        ("Colophon",          "Quirky, wide-spaced typeface designed for editorial use. Distinctive personality that makes code feel like crafted writing."),
    "UbuntuMono Nerd Font":       ("Canonical",         "Canonical's official mono, warm and humanist. Wider than most, trades density for personality. Great on HiDPI displays."),
    "VictorMono Nerd Font":       ("Rune Bjørnerås",   "Semi-condensed with gorgeous cursive italics for keywords. Ligatures feel natural. One of the most beautiful coding fonts."),
    "ZedMono Nerd Font":          ("Zed Industries",    "Built for the Zed editor. Clean and neutral, optimised for dense code display. Pairs beautifully with Zed's minimal UI."),
}

_GENERIC_NERD = (
    "Nerd Font",
    "A Nerd Font patched with icons, ligatures and developer glyphs for terminal and editor use.",
)
_GENERIC_MONO = (
    "Monospace",
    "A monospace font — suitable for code, terminals and aligned columns.",
)


def _fc_list_families(args):
    """Run fc-list and yield first family name per line (comma = locale/weight variants)."""
    try:
        raw = subprocess.check_output(
            ["fc-list", *args, "--format=%{family}\\n"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return
    for line in raw.splitlines():
        family = line.split(",")[0].strip()
        if family:
            yield family


def _skip_nerd_width_dup(family):
    """Omit Nerd Font Mono/Propo rows when the base '… Nerd Font' face is listed separately."""
    return family.endswith((" Nerd Font Mono", " Nerd Font Propo"))


def _meta_for_family(family):
    if family in _FONT_META:
        return _FONT_META[family]
    if "Nerd Font" in family:
        return _GENERIC_NERD
    return _GENERIC_MONO


def get_installed_fonts():
    """All monospace fonts (fc :spacing=mono) plus any Nerd Font families not tagged mono."""
    seen = set()
    order = []

    def add(family):
        if _skip_nerd_width_dup(family):
            return
        if family in seen:
            return
        seen.add(family)
        order.append(family)

    # 1) Fontconfig monospace — catches JetBrains Mono, Liberation Mono, Nerd faces, etc.
    for family in _fc_list_families([":spacing=mono"]):
        add(family)

    # 2) Supplement: families whose name contains "Nerd Font" (some installs mis-report spacing)
    for family in _fc_list_families([]):
        if "Nerd Font" not in family:
            continue
        add(family)

    fonts = []
    for family in order:
        desc, text = _meta_for_family(family)
        fonts.append({"name": family, "family": family, "desc": desc, "text": text})

    return sorted(fonts, key=lambda f: f["name"].casefold())


def read_cfg():
    return WEZTERM_CFG.read_text() if WEZTERM_CFG.exists() else ""

def write_cfg(src):
    WEZTERM_CFG.write_text(src)


def _get_scalar(src, key):
    """Read a one-line `config.key = value` assignment (commented or not).

    Returns (raw_value_str, is_commented) or (None, None) if the key isn't present.
    """
    m = re.search(r"^[ \t]*(--\s*)?config\.%s\s*=\s*(.+?)[ \t]*$" % re.escape(key), src, re.MULTILINE)
    if not m:
        return None, None
    return m.group(2), bool(m.group(1))

def _scalar_or_default(src, key, default, cast=str):
    raw, commented = _get_scalar(src, key)
    if raw is None or commented:
        return default
    try:
        if cast is bool:
            return raw.strip() == "true"
        if cast is float:
            return float(raw.strip().strip("'\""))
        if cast is int:
            return int(float(raw.strip().strip("'\"")))
        return raw.strip().strip("'\"")
    except Exception:
        return default

def _set_scalar(src, key, value_literal):
    """Set (or insert) a one-line `config.key = value` assignment, uncommenting if needed."""
    pattern = re.compile(r"^([ \t]*)(?:--\s*)?config\.%s\s*=\s*.+?[ \t]*$" % re.escape(key), re.MULTILINE)
    def repl(m):
        return f"{m.group(1)}config.{key} = {value_literal}"
    new_src, n = pattern.subn(repl, src, count=1)
    if n == 0:
        new_src = src.replace(
            "local config = wezterm.config_builder()",
            f"local config = wezterm.config_builder()\nconfig.{key} = {value_literal}",
            1,
        )
    return new_src

def _apply_and_save(key, value_literal, label):
    write_cfg(_set_scalar(read_cfg(), key, value_literal))
    return label

def _get_padding(src):
    m = re.search(r"config\.window_padding\s*=\s*\{([^}]*)\}", src)
    if not m:
        return ""
    nums = re.findall(r"[\d.]+", m.group(1))
    return nums[0] if nums else ""

def apply_padding(value):
    src = read_cfg()
    n = int(float(value))
    padding_literal = f"{{ left = {n}, right = {n}, top = {n}, bottom = {n} }}"
    pattern = re.compile(r"^([ \t]*)(?:--\s*)?config\.window_padding\s*=\s*\{[^}]*\}", re.MULTILINE)
    def repl(m):
        return f"{m.group(1)}config.window_padding = {padding_literal}"
    new_src, count = pattern.subn(repl, src, count=1)
    if count == 0:
        new_src = src.replace(
            "local config = wezterm.config_builder()",
            f"local config = wezterm.config_builder()\nconfig.window_padding = {padding_literal}",
            1,
        )
    write_cfg(new_src)
    return f"Padding → {n}px"

def apply_color_scheme(name):
    src = read_cfg()
    if not name or name == "Default":
        pattern = re.compile(r"^([ \t]*)(--\s*)?(config\.color_scheme\s*=\s*.+?)[ \t]*$", re.MULTILINE)
        def repl(m):
            return f"{m.group(1)}-- {m.group(3)}"
        new_src, n = pattern.subn(repl, src, count=1)
        write_cfg(new_src if n else src)
        return "Color scheme → Default"
    write_cfg(_set_scalar(src, "color_scheme", f"'{name}'"))
    return f"Color scheme → {name}"


_SCHEME_CACHE = None
_SCHEME_LUA_TEMPLATE = """
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local names = {}
for name, _ in pairs(wezterm.color.get_builtin_schemes()) do
  table.insert(names, name)
end
table.sort(names)
local f = io.open('__JSON_PATH__', 'w')
f:write(wezterm.json_encode(names))
f:close()
return config
"""

def get_color_schemes():
    """List WezTerm's built-in color scheme names (cached — the wezterm subprocess call takes ~5s)."""
    global _SCHEME_CACHE
    if _SCHEME_CACHE is not None:
        return _SCHEME_CACHE
    schemes = []
    try:
        with tempfile.TemporaryDirectory() as d:
            lua_path = Path(d) / "dump_schemes.lua"
            json_path = Path(d) / "schemes.json"
            lua_path.write_text(_SCHEME_LUA_TEMPLATE.replace("__JSON_PATH__", json_path.as_posix()))
            subprocess.run(
                ["wezterm", "--config-file", str(lua_path), "ls-fonts", "--list-system"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=15,
                check=True,
            )
            schemes = json.loads(json_path.read_text())
    except Exception:
        schemes = []
    _SCHEME_CACHE = schemes
    return schemes


def apply_font(family, weight="Regular"):
    src = read_cfg()
    weight_str = f", {{ weight = '{weight}' }}" if weight else ""
    src = re.sub(
        r"config\.font\s*=\s*wezterm\.font\([^)]+\)",
        f"config.font = wezterm.font('{family}'{weight_str})",
        src,
    )
    write_cfg(src)
    return f"Editor font → {family} ({weight})"

def apply_tab_font(family, weight="Regular"):
    src = read_cfg()
    weight_str = f", {{ weight = '{weight}' }}" if weight else ""
    # Match font inside window_frame block
    src = re.sub(
        r"(config\.window_frame\s*=\s*\{[^}]*font\s*=\s*wezterm\.font\()[^)]+(\))",
        rf"\g<1>'{family}'{weight_str}\g<2>",
        src,
        flags=re.DOTALL,
    )
    write_cfg(src)
    return f"Tab font → {family} ({weight})"

def apply_size(size):
    src = read_cfg()
    src = re.sub(
        r"(config\.font_size\s*=\s*)[\d.]+",
        rf"\g<1>{size}",
        src,
    )
    write_cfg(src)
    return f"Editor size → {size}"

def apply_tab_size(size):
    src = read_cfg()
    # Match font_size inside window_frame block
    src = re.sub(
        r"(config\.window_frame\s*=\s*\{[^}]*font_size\s*=\s*)[\d.]+",
        rf"\g<1>{size}",
        src,
        flags=re.DOTALL,
    )
    write_cfg(src)
    return f"Tab size → {size}"

def apply_opacity(value):
    v = float(value)
    return _apply_and_save("window_background_opacity", v, f"Opacity → {v}")

def apply_decorations(value):
    return _apply_and_save("window_decorations", f"'{value}'", f"Decorations → {value}")

def apply_cursor_style(value):
    return _apply_and_save("default_cursor_style", f"'{value}'", f"Cursor style → {value}")

def apply_cursor_blink(value):
    v = int(float(value))
    return _apply_and_save("cursor_blink_rate", v, f"Cursor blink → {v}ms")

def apply_bell(enabled):
    on = enabled in ("1", "true", "True")
    return _apply_and_save("audible_bell", "'SystemBeep'" if on else "'Disabled'",
                            f"Bell → {'Enabled' if on else 'Disabled'}")

_TAB_TOGGLE_KEYS = {"hide_tab_bar_if_only_one_tab", "use_fancy_tab_bar", "tab_bar_at_bottom"}

def apply_tab_toggle(key, value):
    if key not in _TAB_TOGGLE_KEYS:
        raise ValueError(f"Unknown tab toggle: {key}")
    on = value in ("1", "true", "True")
    return _apply_and_save(key, "true" if on else "false", f"{key} → {on}")

def apply_tab_max_width(value):
    v = int(float(value))
    return _apply_and_save("tab_max_width", v, f"Tab max width → {v}")

def apply_scrollback(value):
    v = int(float(value))
    return _apply_and_save("scrollback_lines", v, f"Scrollback → {v} lines")

def apply_line_height(value):
    v = float(value)
    return _apply_and_save("line_height", v, f"Line height → {v}")

def get_current():
    src = read_cfg()
    font = tab_font = ""
    size = tab_size = ""
    weight = tab_weight = "Regular"

    m = re.search(r"config\.font\s*=\s*wezterm\.font\('([^']+)'(?:,\s*\{\s*weight\s*=\s*'([^']+)'\s*\})?", src)
    if m:
        font = m.group(1)
        if m.group(2): weight = m.group(2)

    m = re.search(r"config\.font_size\s*=\s*([\d.]+)", src)
    if m: size = m.group(1)

    frame = re.search(r"config\.window_frame\s*=\s*\{([^}]+)\}", src, re.DOTALL)
    if frame:
        block = frame.group(1)
        m = re.search(r"font\s*=\s*wezterm\.font\('([^']+)'(?:,\s*\{\s*weight\s*=\s*'([^']+)'\s*\})?", block)
        if m:
            tab_font = m.group(1)
            if m.group(2): tab_weight = m.group(2)
        m = re.search(r"font_size\s*=\s*([\d.]+)", block)
        if m: tab_size = m.group(1)

    scheme_raw, scheme_commented = _get_scalar(src, "color_scheme")
    color_scheme = "" if (scheme_raw is None or scheme_commented) else scheme_raw.strip().strip("'\"")

    return {
        "font": font, "size": size, "weight": weight,
        "tabFont": tab_font, "tabSize": tab_size, "tabWeight": tab_weight,
        "opacity":     _scalar_or_default(src, "window_background_opacity", 1.0, float),
        "decorations": _scalar_or_default(src, "window_decorations", "TITLE | RESIZE", str),
        "padding":     _get_padding(src),
        "cursorStyle": _scalar_or_default(src, "default_cursor_style", "SteadyBlock", str),
        "cursorBlink": _scalar_or_default(src, "cursor_blink_rate", 500, int),
        "bell":        _scalar_or_default(src, "audible_bell", "SystemBeep", str),
        "hideTabBarIfOnlyOneTab": _scalar_or_default(src, "hide_tab_bar_if_only_one_tab", False, bool),
        "useFancyTabBar":         _scalar_or_default(src, "use_fancy_tab_bar", True, bool),
        "tabBarAtBottom":         _scalar_or_default(src, "tab_bar_at_bottom", False, bool),
        "tabMaxWidth": _scalar_or_default(src, "tab_max_width", 16, int),
        "scrollback":  _scalar_or_default(src, "scrollback_lines", 3500, int),
        "lineHeight":  _scalar_or_default(src, "line_height", 1.0, float),
        "colorScheme": color_scheme,
    }


DISPATCH = {
    "/apply":              lambda p: apply_font(p.get("font", [""])[0], p.get("weight", ["Regular"])[0]),
    "/apply-tab":          lambda p: apply_tab_font(p.get("font", [""])[0], p.get("weight", ["Regular"])[0]),
    "/apply-size":         lambda p: apply_size(p.get("size", ["14"])[0]),
    "/apply-tab-size":     lambda p: apply_tab_size(p.get("size", ["12.5"])[0]),
    "/apply-opacity":      lambda p: apply_opacity(p.get("value", ["1"])[0]),
    "/apply-decorations":  lambda p: apply_decorations(p.get("value", ["TITLE | RESIZE"])[0]),
    "/apply-padding":      lambda p: apply_padding(p.get("value", ["10"])[0]),
    "/apply-cursor-style": lambda p: apply_cursor_style(p.get("value", ["SteadyBlock"])[0]),
    "/apply-cursor-blink": lambda p: apply_cursor_blink(p.get("value", ["500"])[0]),
    "/apply-bell":         lambda p: apply_bell(p.get("enabled", ["1"])[0]),
    "/apply-tab-toggle":   lambda p: apply_tab_toggle(p.get("key", [""])[0], p.get("value", ["0"])[0]),
    "/apply-tab-max-width":lambda p: apply_tab_max_width(p.get("value", ["16"])[0]),
    "/apply-scrollback":   lambda p: apply_scrollback(p.get("value", ["3500"])[0]),
    "/apply-line-height":  lambda p: apply_line_height(p.get("value", ["1.0"])[0]),
    "/apply-scheme":       lambda p: apply_color_scheme(p.get("name", [""])[0]),
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if parsed.path in ("/", "/index.html"):
            content = HTML_FILE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        elif parsed.path in DISPATCH:
            try:
                msg = DISPATCH[parsed.path](params)
                body = json.dumps({"ok": True, "msg": msg}).encode()
            except Exception as e:
                body = json.dumps({"ok": False, "msg": str(e)}).encode()
            self._json(body)

        elif parsed.path == "/fonts":
            self._json(json.dumps(get_installed_fonts()).encode())

        elif parsed.path == "/schemes":
            self._json(json.dumps(get_color_schemes()).encode())

        elif parsed.path == "/current":
            self._json(json.dumps(get_current()).encode())

        else:
            self.send_response(404)
            self.end_headers()

    def _json(self, body):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Font Picker running → http://localhost:{PORT}")
        print(f"WezTerm config      → {WEZTERM_CFG}")
        print("Press Ctrl+C to stop.")
        httpd.serve_forever()
